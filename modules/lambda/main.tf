resource "aws_lambda_function" "main" {
  function_name                  = var.name
  role                           = var.lambda_role
  handler                        = var.handler
  runtime                        = var.runtime
  s3_bucket                      = var.source_bucket
  s3_key                         = var.source_key
  timeout                        = var.timeout
  memory_size                    = var.memory_size
  layers                         = var.layers
  architectures                  = var.architectures
  reserved_concurrent_executions = "-1"
  source_code_hash               = var.source_code_hash


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
