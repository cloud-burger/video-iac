locals {
  aws_vpc_id          = "vpc-095ec31f03c4cf8b4"
  aws_public_subnets  = [
    "subnet-0ed0eba4ca6e2c360",
    "subnet-094bdc0191613ff5e",
    "subnet-018ee66d66f2401ae"
  ]
}

resource "aws_sqs_queue" "video_converter_files_dlq" {
  content_based_deduplication       = false
  delay_seconds                     = 0
  fifo_queue                        = false
  kms_data_key_reuse_period_seconds = 300
  max_message_size                  = 262144
  message_retention_seconds         = 345600
  name                              = "${var.project}-files-dlq-${var.environment}"
  receive_wait_time_seconds         = 0
  sqs_managed_sse_enabled           = true
  visibility_timeout_seconds        = 30
}

resource "aws_sqs_queue" "video_converter_files" {
  content_based_deduplication       = false
  delay_seconds                     = 0
  fifo_queue                        = false
  kms_data_key_reuse_period_seconds = 300
  max_message_size                  = 262144
  message_retention_seconds         = 345600
  name                              = "${var.project}-files-${var.environment}"
  receive_wait_time_seconds         = 0
  sqs_managed_sse_enabled           = true
  visibility_timeout_seconds        = 30
  redrive_policy = jsonencode(
    {
      deadLetterTargetArn = aws_sqs_queue.video_converter_files_dlq.arn
      maxReceiveCount     = 5
    }
  )
}

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


module "lambda_converter" {
  source             = "../../modules/lambda"
  name               = "${var.project}-${var.environment}"
  lambda_role        = aws_iam_role.lambda_role.arn
  handler            = "src/api/handlers/converter.handler"
  source_bucket      = "cloud-burger-artifacts"
  source_key         = "converter.zip"
  project            = var.project
  source_code_hash   = base64encode(sha256("${var.commit_hash}"))
  subnet_ids         = local.aws_public_subnets
  security_group_ids = [aws_security_group.converter.id]
  environment_variables = {
    DATABASE_USERNAME           = resource.aws_ssm_parameter.database_username.value
    DATABASE_NAME               = resource.aws_ssm_parameter.database_name.value
    DATABASE_PASSWORD           = resource.aws_ssm_parameter.database_password.value
    DATABASE_PORT               = resource.aws_ssm_parameter.database_port.value
    DATABASE_HOST               = trim(resource.aws_ssm_parameter.database_host.value, ":5432")
    DATABASE_CONNECTION_TIMEOUT = 120000
  }
}

resource "aws_cloudwatch_log_group" "lambda_converter" {
  name              = "/aws/lambda/${module.lambda_converter.function_name}"
  retention_in_days = 5
}

resource "aws_lambda_event_source_mapping" "video_converter_event_source_mapping" {
  event_source_arn = aws_sqs_queue.video_converter_files.arn
  enabled          = true
  function_name    = module.lambda_converter.arn
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.project}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "sts:AssumeRole"
      ],
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Effect = "Allow"
    }]
  })
}

resource "aws_iam_policy" "ssm_policy" {
  name        = "ssm_policy"
  description = "SSM Policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter"
        ],
        Resource = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project}/*"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "ssm_policy_attachment" {
  name       = "ssm_policy_attachment"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = aws_iam_policy.ssm_policy.arn
}

resource "aws_iam_policy_attachment" "lambda_policy_attachment" {
  name       = "${var.project}-lambda-policy-attachment"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AWSLambda_FullAccess"
}

resource "aws_iam_policy_attachment" "lambda_cloudwatch_policy" {
  name       = "${var.project}-lambda_cloudwatch_policy"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

resource "aws_iam_policy_attachment" "lambda_sqs_policy" {
  name       = "${var.project}-lambda_sqs_policy"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

resource "aws_iam_policy_attachment" "lambda_rds_policy" {
  name       = "lambda_rds_policy"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSReadOnlyAccess"
}

resource "aws_iam_policy_attachment" "lambda_vpc_policy" {
  name       = "lambda_vpc_policy"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonVPCFullAccess"
}

resource "aws_security_group" "converter" {
  name   = "converter"
  vpc_id = local.aws_vpc_id

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
  subnet_ids = local.aws_public_subnets
}

resource "aws_security_group" "rds_public_sg" {
  name        = var.project
  description = "Allow postgres inbound traffic"
  vpc_id      = local.aws_vpc_id

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