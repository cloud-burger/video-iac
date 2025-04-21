data "aws_iam_policy_document" "video_converter" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions   = ["SNS:Publish"]
    resources = ["arn:aws:sns:*:*:${var.project}-s3-${var.environment}"]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.video_files.arn]
    }
  }
}

resource "aws_sns_topic" "video_converter" {
  name   = "${var.project}-s3-${var.environment}"
  policy = data.aws_iam_policy_document.video_converter.json
}

resource "aws_s3_bucket" "video_files" {
  bucket = "${var.project}-files-${var.environment}"

  tags = {
    Name        = "${var.project}-files-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_notification" "video_converter_notification" {
  bucket = aws_s3_bucket.video_files.id

  topic {
    topic_arn     = aws_sns_topic.video_converter.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".mp4"
  }
}

locals {
  lambdas = {
    list-videos          = "src/app/handlers/list-videos/index.handler"
    get-video-url        = "src/app/handlers/get-video-url/index.handler"
    process-video        = "src/app/handlers/process-video/index.handler"
    get-video-frames-url = "src/app/handlers/get-video-frames-url/index.handler"
  }
}

module "lambda_converter" {
  source   = "../../modules/lambda"
  for_each = local.lambdas

  name               = "${var.project}-${each.key}-${var.environment}"
  lambda_role        = aws_iam_role.lambda_role.arn
  handler            = each.value
  source_bucket      = "cloud-burger-artifacts"
  source_key         = "${each.key}.zip"
  project            = var.project
  source_code_hash   = base64encode(sha256("${var.commit_hash}"))
  subnet_ids         = data.terraform_remote_state.iac_state.outputs.private_subnets
  memory_size        = 10000
  security_group_ids = [aws_security_group.converter.id]
  environment_variables = {
    DATABASE_USERNAME           = resource.aws_ssm_parameter.database_username.value
    DATABASE_NAME               = resource.aws_ssm_parameter.database_name.value
    DATABASE_PASSWORD           = resource.aws_ssm_parameter.database_password.value
    DATABASE_PORT               = resource.aws_ssm_parameter.database_port.value
    DATABASE_HOST               = trim(resource.aws_ssm_parameter.database_host.value, ":5432")
    BUCKET_NAME                 = "${var.project}-${var.environment}"
    VIDEO_QUEUE_URL             = "https://sqs.${var.region}.amazonaws.com/${data.aws_caller_identity.current.account_id}/video-notification-${var.environment}"
    DATABASE_CONNECTION_TIMEOUT = 120000
  }
}

resource "aws_cloudwatch_log_group" "lambda_converter" {
  for_each          = local.lambdas
  name              = "/aws/lambda/${var.project}-${each.key}-${var.environment}"
  retention_in_days = 5
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = [
        "lambda.amazonaws.com",
        "apigateway.amazonaws.com"
      ]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "${var.project}-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_security_group" "converter" {
  name   = "converter"
  vpc_id = data.terraform_remote_state.iac_state.outputs.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "lambda_to_rds" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_public_sg.id
  source_security_group_id = aws_security_group.converter.id
}

resource "aws_db_parameter_group" "converter" {
  name   = "converter"
  family = "postgres16"

  parameter {
    name  = "rds.force_ssl"
    value = "0"
  }
}

resource "aws_db_instance" "converter" {
  allocated_storage    = 20
  storage_type         = "gp3"
  engine               = "postgres"
  engine_version       = "16.7"
  instance_class       = var.database_instance_class
  identifier           = var.project
  db_name              = var.database_name
  username             = var.database_username
  password             = var.database_password
  parameter_group_name = aws_db_parameter_group.converter.name
  publicly_accessible  = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds_public_sg.id]
  skip_final_snapshot    = true

  tags = {
    "Name" : "${var.project}"
    "Project" : "${var.project}"
  }
}

resource "aws_db_subnet_group" "main" {
  name       = var.project
  subnet_ids = data.terraform_remote_state.iac_state.outputs.public_subnets
}

resource "aws_security_group" "rds_public_sg" {
  name        = var.project
  description = "Allow postgres inbound traffic"
  vpc_id      = data.terraform_remote_state.iac_state.outputs.vpc_id
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ssm_parameter" "database_host" {
  name  = "/prod/${var.project}/database-host"
  value = aws_db_instance.converter.endpoint
  type  = "String"
}

resource "aws_ssm_parameter" "database_port" {
  name  = "/prod/${var.project}/database-port"
  value = aws_db_instance.converter.port
  type  = "String"
}

resource "aws_ssm_parameter" "database_name" {
  name  = "/prod/${var.project}/database-name"
  value = var.database_name
  type  = "String"
}

resource "aws_ssm_parameter" "database_username" {
  name  = "/prod/${var.project}/database-username"
  value = var.database_username
  type  = "String"
}

resource "aws_ssm_parameter" "database_password" {
  name  = "/prod/${var.project}/database-password"
  value = var.database_password
  type  = "SecureString"
}

resource "aws_s3_bucket" "converter" {
  bucket = "${var.project}-${var.environment}"

  tags = {
    Name        = "${var.project}-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_notification" "process_notification" {
  bucket = aws_s3_bucket.converter.id

  lambda_function {
    lambda_function_arn = "arn:aws:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:video-converter-process-video-${var.environment}"
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "videos/"
    filter_suffix       = ".mp4"
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket1"
  action        = "lambda:InvokeFunction"
  function_name = "arn:aws:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:video-converter-process-video-${var.environment}"
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.converter.arn
}