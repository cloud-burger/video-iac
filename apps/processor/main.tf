resource "aws_sqs_queue" "video_processor_files_dlq" {
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

resource "aws_sqs_queue" "video_processor_files" {
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
      deadLetterTargetArn = aws_sqs_queue.video_processor_files_dlq.arn
      maxReceiveCount     = 5
    }
  )
}

data "aws_iam_policy_document" "video_processor" {
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

resource "aws_sns_topic" "video_processor" {
  name   = "${var.project}-s3-${var.environment}"
  policy = data.aws_iam_policy_document.video_processor.json
}

resource "aws_s3_bucket" "video_files" {
  bucket = "${var.project}-files-${var.environment}"

  tags = {
    Name        = "${var.project}-files-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_notification" "video_processor_notification" {
  bucket = aws_s3_bucket.video_files.id

  topic {
    topic_arn     = aws_sns_topic.video_processor.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".mp4"
  }
}

resource "aws_dynamodb_table" "video_processor" {
  name         = "${var.project}-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "file_name"
    type = "S"
  }

  attribute {
    name = "user"
    type = "S"
  }
  
  attribute {
    name = "status"
    type = "S"
  }

  global_secondary_index {
    name            = "user_gsi"
    hash_key        = "user"
    projection_type = "ALL"
  }
}

module "lambda_processor" {
  source             = "../../modules/lambda"
  name               = "${var.project}-${var.environment}"
  lambda_role        = aws_iam_role.lambda_role.arn
  handler            = "src/api/handlers/processor.handler"
  source_bucket      = "cloud-burger-artifacts"
  source_key         = "processor.zip"
  project            = var.project
  source_code_hash   = base64encode(sha256("${var.commit_hash}"))
}

resource "aws_cloudwatch_log_group" "lambda_processor" {
  name              = "/aws/lambda/${module.lambda_processor.function_name}"
  retention_in_days = 5
}

resource "aws_lambda_event_source_mapping" "video_processor_event_source_mapping" {
  event_source_arn = aws_sqs_queue.video_processor_files.arn
  enabled          = true
  function_name    = module.lambda_processor.arn
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
