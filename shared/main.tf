resource "aws_cognito_user_pool" "main" {
  name = "cloud-burger-video"

  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_numbers   = true
    require_symbols   = true
  }
}

resource "aws_cognito_user_pool_domain" "main_domain" {
  domain       = "cloud-burger-video"
  user_pool_id = aws_cognito_user_pool.main.id
}

resource "aws_cognito_user_pool_client" "main_client" {
  name                                 = "cloud-burger-admin-video-app"
  user_pool_id                         = aws_cognito_user_pool.main.id
  allowed_oauth_flows_user_pool_client = true
  supported_identity_providers         = ["COGNITO"]
  callback_urls                        = ["http://localhost:9090/callback"]
  generate_secret                      = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes = [
    "email",
    "openid",
    "profile"
  ]
}

resource "aws_api_gateway_rest_api" "main" {
  name = "${var.project}-video-${var.environment}"

  body = templatefile("${path.module}/openapi.yaml", {
    lambda_function_list_video           = "arn:aws:apigateway:${var.region}:lambda:path/${var.api_version}/functions/arn:aws:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:video-converter-list-videos-${var.environment}/invocations",
    lambda_function_put_video_url        = "arn:aws:apigateway:${var.region}:lambda:path/${var.api_version}/functions/arn:aws:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:video-converter-get-video-url-${var.environment}/invocations",
    lambda_function_get_video_frames_url = "arn:aws:apigateway:${var.region}:lambda:path/${var.api_version}/functions/arn:aws:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:video-converter-get-video-frames-url-${var.environment}/invocations",
    provider_arn                         = aws_cognito_user_pool.main.arn
  })

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  lifecycle {
    ignore_changes = [
      policy
    ]
  }
}

resource "aws_api_gateway_stage" "main_stage" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.environment
}

resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([aws_api_gateway_rest_api.main.body]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_iam_policy_document" "main_policy_document" {
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions   = ["execute-api:Invoke"]
    resources = ["*"]
  }
}

resource "aws_api_gateway_rest_api_policy" "main_policy" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  policy      = data.aws_iam_policy_document.main_policy_document.json
}


resource "aws_iam_policy" "lambda_custom_policy" {
  name        = "${var.project}-custom-${var.environment}"
  description = "${var.project}-custom-${var.environment}"
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
      },
      {
        Effect = "Allow",
        Action = [
          "lambda:InvokeFunction"
        ],
        Resource = "arn:aws:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function/*"
      }
    ]
  })
}

locals {
  policies = {
    0 = "arn:aws:iam::aws:policy/AWSLambda_FullAccess"
    1 = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
    2 = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
    3 = aws_iam_policy.lambda_custom_policy.arn
    4 = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
    5 = "arn:aws:iam::aws:policy/AmazonRDSReadOnlyAccess"
    6 = "arn:aws:iam::aws:policy/AmazonVPCFullAccess"
  }
}

resource "aws_iam_policy_attachment" "lambda_policy_attachment" {
  for_each = local.policies
  name       = "${var.project}-lambda-policy-attachment"
  roles      = [
    "video-converter-${var.environment}",
    "video-notification-${var.environment}"
  ]
  policy_arn = each.value
}

