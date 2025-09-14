# S3 Bucket for code storage and static website hosting
resource "aws_s3_bucket" "code_storage" {
  bucket = "${var.project_name}-code-storage-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "${var.project_name}-code-storage"
    Purpose     = "Code execution temporary storage"
    Environment = var.environment
  }
}

resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project_name}-frontend-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "${var.project_name}-frontend"
    Purpose     = "Static website hosting"
    Environment = var.environment
  }
}

# Random ID for unique bucket naming
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "code_storage" {
  bucket = aws_s3_bucket.code_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "code_storage" {
  bucket = aws_s3_bucket.code_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# S3 bucket public access block for code storage (keep private)
resource "aws_s3_bucket_public_access_block" "code_storage" {
  bucket = aws_s3_bucket.code_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket public access block for frontend (allow CloudFront access)
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket lifecycle configuration for code storage
resource "aws_s3_bucket_lifecycle_configuration" "code_storage" {
  bucket = aws_s3_bucket.code_storage.id

  rule {
    id     = "cleanup_temp_code"
    status = "Enabled"

    expiration {
      days = 1 # Delete temporary code files after 1 day
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }
}

# S3 bucket policy for frontend (CloudFront access)
resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
          }
        }
      }
    ]
  })

  depends_on = [aws_cloudfront_distribution.frontend]
}

# S3 bucket website configuration
resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html" # SPA routing
  }
}
