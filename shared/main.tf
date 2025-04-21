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
    "profile",
    "cloud-burger-video/list_videos",
    "cloud-burger-video/put_video_url",
    "cloud-burger-video/get_video_frames_url"
  ]
}

resource "aws_cognito_resource_server" "main_resource_server" {
  user_pool_id = aws_cognito_user_pool.main.id
  identifier   = "cloud-burger-video"
  name         = "Recursos das rotas de administracao"

  scope {
    scope_name        = "list_videos"
    scope_description = "Lista os videos e seus status de processamento"
  }

  scope {
    scope_name        = "put_video_url"
    scope_description = "Obtem url para upload de video"
  }

  scope {
    scope_name        = "get_video_frames_url"
    scope_description = "Obtem url para obter zip com frames do video"
  }
}

resource "aws_api_gateway_rest_api" "main" {
  name = "${var.project}-video-${var.environment}"

  body = templatefile("${path.module}/openapi.yaml", {
    lambda_function_list_video           = "arn:aws:apigateway:${var.region}:lambda:path/${var.api_version}/functions/arn:aws:lambda:us-east-1:${data.aws_caller_identity.current.account_id}:function:video-converter-list-videos-prod/invocations",
    lambda_function_put_video_url        = "arn:aws:apigateway:${var.region}:lambda:path/${var.api_version}/functions/arn:aws:lambda:us-east-1:${data.aws_caller_identity.current.account_id}:function:video-converter-get-video-url-prod/invocations",
    lambda_function_get_video_frames_url = "arn:aws:apigateway:${var.region}:lambda:path/${var.api_version}/functions/arn:aws:lambda:us-east-1:${data.aws_caller_identity.current.account_id}:function:video-converter-get-video-frames-url-prod/invocations",
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

# data "aws_iam_policy_document" "invocation_assume_role" {
#   statement {
#     effect = "Allow"

#     principals {
#       type        = "Service"
#       identifiers = ["apigateway.amazonaws.com"]
#     }

#     actions = ["sts:AssumeRole"]
#   }
# }

# resource "aws_iam_role" "invocation_role" {
#   name               = "api_gateway_auth_invocation"
#   path               = "/"
#   assume_role_policy = data.aws_iam_policy_document.invocation_assume_role.json
# }

# data "aws_iam_policy_document" "invocation_policy" {
#   statement {
#     effect    = "Allow"
#     actions   = ["lambda:InvokeFunction"]
#     resources = [module.lambda_authorizer.arn]
#   }
# }

# resource "aws_iam_role_policy" "invocation_policy" {
#   name   = "default"
#   role   = aws_iam_role.invocation_role.id
#   policy = data.aws_iam_policy_document.invocation_policy.json
# }