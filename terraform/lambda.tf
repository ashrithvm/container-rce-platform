# Security Group for Lambda functions
resource "aws_security_group" "lambda" {
  name_prefix = "${var.project_name}-lambda-"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-lambda-sg"
    Environment = var.environment
  }
}

# IAM Role for API Lambda Function
resource "aws_iam_role" "api_lambda" {
  name = "${var.project_name}-api-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-api-lambda-role"
    Environment = var.environment
  }
}

# IAM Role for Executor Lambda Function
resource "aws_iam_role" "executor_lambda" {
  name = "${var.project_name}-executor-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-executor-lambda-role"
    Environment = var.environment
  }
}

# IAM Policy for API Lambda
resource "aws_iam_role_policy" "api_lambda" {
  name = "${var.project_name}-api-lambda-policy"
  role = aws_iam_role.api_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.code_execution_queue.arn
      },
      {
        Effect = "Allow"
        Action = [
          "elasticache:DescribeReplicationGroups",
          "elasticache:DescribeCacheClusters"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.code_storage.arn}/*"
      }
    ]
  })
}

# IAM Policy for Executor Lambda
resource "aws_iam_role_policy" "executor_lambda" {
  name = "${var.project_name}-executor-lambda-policy"
  role = aws_iam_role.executor_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.code_execution_queue.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.code_storage.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# VPC Configuration for Lambda functions
resource "aws_iam_role_policy_attachment" "api_lambda_vpc" {
  role       = aws_iam_role.api_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "executor_lambda_vpc" {
  role       = aws_iam_role.executor_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Archive source code for API Lambda
data "archive_file" "api_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../aws-lambda/api"
  output_path = "${path.module}/api-lambda.zip"
}

# Archive source code for Executor Lambda  
data "archive_file" "executor_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../aws-lambda/executor"
  output_path = "${path.module}/executor-lambda.zip"
}

# API Lambda Function
resource "aws_lambda_function" "api" {
  filename         = data.archive_file.api_lambda.output_path
  function_name    = "${var.project_name}-api"
  role            = aws_iam_role.api_lambda.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.api_lambda.output_base64sha256
  runtime         = "nodejs20.x"
  timeout         = 30
  memory_size     = 256

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      SQS_QUEUE_URL        = aws_sqs_queue.code_execution_queue.id
      S3_CODE_BUCKET       = aws_s3_bucket.code_storage.bucket
      REDIS_ENDPOINT       = aws_elasticache_replication_group.redis.configuration_endpoint_address
      REDIS_PORT           = "6379"
      ENVIRONMENT          = var.environment
    }
  }

  tags = {
    Name        = "${var.project_name}-api-lambda"
    Environment = var.environment
  }

  depends_on = [
    aws_iam_role_policy_attachment.api_lambda_vpc,
    aws_cloudwatch_log_group.api_lambda
  ]
}

# Executor Lambda Function
resource "aws_lambda_function" "executor" {
  filename         = data.archive_file.executor_lambda.output_path
  function_name    = "${var.project_name}-executor"
  role            = aws_iam_role.executor_lambda.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.executor_lambda.output_base64sha256
  runtime         = "nodejs20.x"
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size

  environment {
    variables = {
      S3_CODE_BUCKET = aws_s3_bucket.code_storage.bucket
      REDIS_ENDPOINT = aws_elasticache_replication_group.redis.configuration_endpoint_address
      REDIS_PORT     = "6379"
      ENVIRONMENT    = var.environment
    }
  }

  tags = {
    Name        = "${var.project_name}-executor-lambda"
    Environment = var.environment
  }

  depends_on = [
    aws_iam_role_policy_attachment.executor_lambda_vpc,
    aws_cloudwatch_log_group.executor_lambda
  ]
}

# SQS trigger for Executor Lambda
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.code_execution_queue.arn
  function_name    = aws_lambda_function.executor.arn
  batch_size       = 10
  enabled          = true

  depends_on = [aws_iam_role_policy.executor_lambda]
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "api_lambda" {
  name              = "/aws/lambda/${var.project_name}-api"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-api-lambda-logs"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "executor_lambda" {
  name              = "/aws/lambda/${var.project_name}-executor"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-executor-lambda-logs"
    Environment = var.environment
  }
}
