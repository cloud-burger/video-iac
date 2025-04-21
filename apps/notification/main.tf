module "lambda_notification" {
  source             = "../../modules/lambda"
  name               = "${var.project}-${var.environment}"
  lambda_role        = aws_iam_role.lambda_role.arn
  handler            = "src/app/handlers/send-notification/index.handler"
  source_bucket      = "cloud-burger-artifacts"
  source_key         = "notification.zip"
  project            = var.project
  source_code_hash   = base64encode(sha256("${var.commit_hash}"))
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.project}-${var.environment}"
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

resource "aws_iam_policy_attachment" "sns_policy_attachment" {
  name       = "${var.project}-sns-policy-attachment"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

resource "aws_iam_policy_attachment" "sqs_policy_attachment" {
  name       = "${var.project}-sqs-policy-attachment"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

resource "aws_sns_topic" "video_email_notification" {
  name   = "${var.project}-email-${var.environment}"
}

resource "aws_sqs_queue" "video_notification_dlq" {
  content_based_deduplication       = false
  delay_seconds                     = 0
  fifo_queue                        = false
  kms_data_key_reuse_period_seconds = 300
  max_message_size                  = 262144
  message_retention_seconds         = 345600
  name                              = "${var.project}-dlq-${var.environment}"
  receive_wait_time_seconds         = 0
  sqs_managed_sse_enabled           = true
  visibility_timeout_seconds        = 30
}

resource "aws_sqs_queue" "video_notification" {
  content_based_deduplication       = false
  delay_seconds                     = 0
  fifo_queue                        = false
  kms_data_key_reuse_period_seconds = 300
  max_message_size                  = 262144
  message_retention_seconds         = 345600
  name                              = "${var.project}-${var.environment}"
  receive_wait_time_seconds         = 0
  sqs_managed_sse_enabled           = true
  visibility_timeout_seconds        = 30
  redrive_policy = jsonencode(
    {
      deadLetterTargetArn = aws_sqs_queue.video_notification_dlq.arn
      maxReceiveCount     = 5
    }
  )
}

resource "aws_lambda_event_source_mapping" "video_converter_event_source_mapping" {
  event_source_arn = aws_sqs_queue.video_notification.arn
  enabled          = true
  function_name    = module.lambda_notification.arn
}


resource "aws_dynamodb_table" "video_notification" {
  name         = "${var.project}-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "notification_id"
    type = "S"
  }

  global_secondary_index {
    name            = "notification_id_gsi"
    hash_key        = "notification_id"
    projection_type = "ALL"
  }
}