module "lambda_notification" {
  source             = "../../modules/lambda"
  name               = "${var.project}-${var.environment}"
  lambda_role        = aws_iam_role.lambda_role.arn
  handler            = "src/api/handlers/notification.handler"
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

resource "aws_sns_topic" "video_email_notification" {
  name   = "${var.project}-email-${var.environment}"
}