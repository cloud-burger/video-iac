resource "aws_lambda_function" "main" {
  function_name                  = var.name
  role                           = var.lambda_role
  image_uri                      = var.image_uri
  package_type                   = "Image"
  timeout                        = var.timeout
  memory_size                    = var.memory_size
  architectures                  = ["arm64"]
  reserved_concurrent_executions = "-1"

  tags = merge(var.tags, {
    Service = var.project
  })

  environment {
    variables = merge(var.environment_variables, {
      SERVICE      = var.project,
      NODE_OPTIONS = "--enable-source-maps"
    })
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }
}