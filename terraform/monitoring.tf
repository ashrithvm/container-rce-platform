# CloudWatch Monitoring and Alarms
resource "aws_cloudwatch_metric_alarm" "api_lambda_errors" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-api-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors API Lambda errors"
  alarm_actions       = [aws_sns_topic.alerts[0].arn]

  dimensions = {
    FunctionName = aws_lambda_function.api.function_name
  }

  tags = {
    Name        = "${var.project_name}-api-lambda-errors-alarm"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "executor_lambda_errors" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-executor-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors Executor Lambda errors"
  alarm_actions       = [aws_sns_topic.alerts[0].arn]

  dimensions = {
    FunctionName = aws_lambda_function.executor.function_name
  }

  tags = {
    Name        = "${var.project_name}-executor-lambda-errors-alarm"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "sqs_dlq_messages" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-sqs-dlq-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ApproximateNumberOfVisibleMessages"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "This metric monitors messages in DLQ"
  alarm_actions       = [aws_sns_topic.alerts[0].arn]

  dimensions = {
    QueueName = aws_sqs_queue.code_execution_dlq.name
  }

  tags = {
    Name        = "${var.project_name}-sqs-dlq-alarm"
    Environment = var.environment
  }
}

# SNS Topic for alerts
resource "aws_sns_topic" "alerts" {
  count = var.enable_monitoring ? 1 : 0

  name = "${var.project_name}-alerts"

  tags = {
    Name        = "${var.project_name}-alerts"
    Environment = var.environment
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  count = var.enable_monitoring ? 1 : 0

  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.api.function_name],
            [".", "Errors", ".", "."],
            [".", "Duration", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "API Lambda Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.executor.function_name],
            [".", "Errors", ".", "."],
            [".", "Duration", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Executor Lambda Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/SQS", "NumberOfMessagesSent", "QueueName", aws_sqs_queue.code_execution_queue.name],
            [".", "NumberOfMessagesReceived", ".", "."],
            [".", "ApproximateNumberOfVisibleMessages", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "SQS Queue Metrics"
          period  = 300
        }
      }
    ]
  })
}

# Lambda Insights for enhanced monitoring
resource "aws_lambda_layer_version" "lambda_insights" {
  count = var.enable_monitoring ? 1 : 0

  filename   = "lambda-insights-extension.zip"
  layer_name = "${var.project_name}-lambda-insights"

  compatible_runtimes = ["nodejs20.x"]

  # This would need the actual Lambda Insights extension zip
  # For now, we'll comment this out and add it manually if needed
  lifecycle {
    ignore_changes = [filename]
  }
}
