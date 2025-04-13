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
    "cloud-burger-video/customer_write",
    "cloud-burger-video/customer_read"
  ]
}

resource "aws_cognito_resource_server" "main_resource_server" {
  user_pool_id = aws_cognito_user_pool.main.id
  identifier   = "cloud-burger-video"
  name         = "Recursos das rotas de administracao"

  scope {
    scope_name        = "customer_write"
    scope_description = "Criar clientes"
  }

  scope {
    scope_name        = "customer_read"
    scope_description = "Ler dados dos clientes"
  }
}

resource "aws_api_gateway_rest_api" "main" {
  name = "${var.project}-video-${var.environment}"

  # body = templatefile("${path.module}/openapi.yaml", {
  #   load_balancer_uri      = "http://api.cloudburger.com.br",
  #   authorizer_uri         = module.lambda_authorizer.invoke_arn,
  #   authorizer_credentials = aws_iam_role.invocation_role.arn,
  #   provider_arn           = aws_cognito_user_pool.main.arn,
  #   vpc_link_id            = aws_api_gateway_vpc_link.main_vpc_link.id
  # })

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  lifecycle {
    ignore_changes = [
      policy
    ]
  }
}

# resource "aws_api_gateway_stage" "main_stage" {
#   deployment_id = aws_api_gateway_deployment.main.id
#   rest_api_id   = aws_api_gateway_rest_api.main.id
#   stage_name    = var.environment
# }

# resource "aws_api_gateway_deployment" "main" {
#   rest_api_id = aws_api_gateway_rest_api.main.id

#   triggers = {
#     redeployment = sha1(jsonencode([aws_api_gateway_rest_api.main.body]))
#   }

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# resource "aws_api_gateway_vpc_link" "main_vpc_link" {
#   name = "k8s-vpc-link"

#   target_arns = [
#     data.aws_lb.loadbalancer.arn
#   ]
# }

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