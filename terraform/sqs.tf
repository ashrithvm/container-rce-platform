# SQS Queue for job management
resource "aws_sqs_queue" "code_execution_queue" {
  name                       = "${var.project_name}-execution-queue"
  delay_seconds              = 0
  max_message_size           = 262144
  message_retention_seconds  = 1209600 # 14 days
  receive_wait_time_seconds  = 0
  visibility_timeout_seconds = var.sqs_visibility_timeout

  tags = {
    Name        = "${var.project_name}-execution-queue"
    Environment = var.environment
  }
}

# SQS Dead Letter Queue
resource "aws_sqs_queue" "code_execution_dlq" {
  name                       = "${var.project_name}-execution-dlq"
  delay_seconds              = 0
  max_message_size           = 262144
  message_retention_seconds  = 1209600 # 14 days
  receive_wait_time_seconds  = 0
  visibility_timeout_seconds = var.sqs_visibility_timeout

  tags = {
    Name        = "${var.project_name}-execution-dlq"
    Environment = var.environment
  }
}

# SQS Queue Policy
resource "aws_sqs_queue_policy" "code_execution_queue" {
  queue_url = aws_sqs_queue.code_execution_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.api_lambda.arn
        }
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.code_execution_queue.arn
      }
    ]
  })
}

# SQS Redrive Policy for Dead Letter Queue
resource "aws_sqs_queue_redrive_policy" "code_execution_queue" {
  queue_url = aws_sqs_queue.code_execution_queue.id

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.code_execution_dlq.arn
    maxReceiveCount     = 3
  })
}
