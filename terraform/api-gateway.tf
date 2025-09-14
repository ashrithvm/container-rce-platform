# API Gateway REST API
resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.project_name}-api"
  description = "API Gateway for Container RCE Platform"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name        = "${var.project_name}-api"
    Environment = var.environment
  }
}

# API Gateway Resource for /execute
resource "aws_api_gateway_resource" "execute" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "execute"
}

# API Gateway Resource for /job-status
resource "aws_api_gateway_resource" "job_status" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "job-status"
}

# API Gateway Resource for /job-status/{jobId}
resource "aws_api_gateway_resource" "job_status_id" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.job_status.id
  path_part   = "{jobId}"
}

# API Gateway Method for POST /execute
resource "aws_api_gateway_method" "execute_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.execute.id
  http_method   = "POST"
  authorization = "NONE"
}

# API Gateway Method for GET /job-status/{jobId}
resource "aws_api_gateway_method" "job_status_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.job_status_id.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.jobId" = true
  }
}

# API Gateway Options method for CORS on /execute
resource "aws_api_gateway_method" "execute_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.execute.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# API Gateway Options method for CORS on /job-status/{jobId}
resource "aws_api_gateway_method" "job_status_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.job_status_id.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# Lambda Integration for POST /execute
resource "aws_api_gateway_integration" "execute_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_method.execute_post.resource_id
  http_method = aws_api_gateway_method.execute_post.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.api.invoke_arn
}

# Lambda Integration for GET /job-status/{jobId}
resource "aws_api_gateway_integration" "job_status_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_method.job_status_get.resource_id
  http_method = aws_api_gateway_method.job_status_get.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.api.invoke_arn
}

# CORS Integration for /execute OPTIONS
resource "aws_api_gateway_integration" "execute_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_method.execute_options.resource_id
  http_method = aws_api_gateway_method.execute_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# CORS Integration for /job-status/{jobId} OPTIONS
resource "aws_api_gateway_integration" "job_status_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_method.job_status_options.resource_id
  http_method = aws_api_gateway_method.job_status_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# Method Responses for CORS
resource "aws_api_gateway_method_response" "execute_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.execute.id
  http_method = aws_api_gateway_method.execute_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_method_response" "job_status_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.job_status_id.id
  http_method = aws_api_gateway_method.job_status_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# Integration Responses for CORS
resource "aws_api_gateway_integration_response" "execute_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.execute.id
  http_method = aws_api_gateway_method.execute_options.http_method
  status_code = aws_api_gateway_method_response.execute_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.execute_options]
}

resource "aws_api_gateway_integration_response" "job_status_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.job_status_id.id
  http_method = aws_api_gateway_method.job_status_options.http_method
  status_code = aws_api_gateway_method_response.job_status_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.job_status_options]
}

# Lambda permissions for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "main" {
  depends_on = [
    aws_api_gateway_integration.execute_lambda,
    aws_api_gateway_integration.job_status_lambda,
    aws_api_gateway_integration.execute_options,
    aws_api_gateway_integration.job_status_options
  ]

  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.execute.id,
      aws_api_gateway_resource.job_status.id,
      aws_api_gateway_resource.job_status_id.id,
      aws_api_gateway_method.execute_post.id,
      aws_api_gateway_method.job_status_get.id,
      aws_api_gateway_integration.execute_lambda.id,
      aws_api_gateway_integration.job_status_lambda.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.environment

  tags = {
    Name        = "${var.project_name}-api-stage"
    Environment = var.environment
  }
}

# API Gateway Usage Plan
resource "aws_api_gateway_usage_plan" "main" {
  name         = "${var.project_name}-usage-plan"
  description  = "Usage plan for RCE Platform API"

  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = aws_api_gateway_stage.main.stage_name
  }

  throttle_settings {
    rate_limit  = 100
    burst_limit = 200
  }

  quota_settings {
    limit  = 10000
    period = "DAY"
  }

  tags = {
    Name        = "${var.project_name}-usage-plan"
    Environment = var.environment
  }
}
