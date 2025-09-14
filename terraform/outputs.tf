# Outputs for the infrastructure
output "api_gateway_url" {
  description = "URL of the API Gateway"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "cloudfront_distribution_url" {
  description = "CloudFront distribution URL"
  value       = "https://${aws_cloudfront_distribution.frontend_with_api[0].domain_name}"
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.frontend_with_api[0].id
}

output "s3_frontend_bucket" {
  description = "S3 bucket for frontend hosting"
  value       = aws_s3_bucket.frontend.bucket
}

output "s3_code_storage_bucket" {
  description = "S3 bucket for code storage"
  value       = aws_s3_bucket.code_storage.bucket
}

output "redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = aws_elasticache_replication_group.redis.configuration_endpoint_address
  sensitive   = true
}

output "sqs_queue_url" {
  description = "SQS queue URL"
  value       = aws_sqs_queue.code_execution_queue.id
}

output "lambda_api_function_name" {
  description = "API Lambda function name"
  value       = aws_lambda_function.api.function_name
}

output "lambda_executor_function_name" {
  description = "Executor Lambda function name"
  value       = aws_lambda_function.executor.function_name
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "custom_domain_name" {
  description = "Custom domain name (if configured)"
  value       = var.domain_name != "" ? var.domain_name : "Not configured"
}

output "sns_alerts_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = var.enable_monitoring ? aws_sns_topic.alerts[0].arn : "Monitoring disabled"
}
