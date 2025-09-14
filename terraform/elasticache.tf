# ElastiCache Subnet Group
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project_name}-redis-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name        = "${var.project_name}-redis-subnet-group"
    Environment = var.environment
  }
}

# ElastiCache Redis Cluster
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id         = "${var.project_name}-redis"
  description                  = "Redis cluster for RCE platform job status"
  
  node_type                    = var.elasticache_node_type
  port                         = 6379
  parameter_group_name         = "default.redis7"
  
  num_cache_clusters           = 1
  
  subnet_group_name            = aws_elasticache_subnet_group.redis.name
  security_group_ids           = [aws_security_group.elasticache.id]
  
  at_rest_encryption_enabled   = true
  transit_encryption_enabled   = true
  
  automatic_failover_enabled   = false # Single node for cost efficiency
  multi_az_enabled            = false
  
  maintenance_window          = "sun:03:00-sun:04:00"
  snapshot_retention_limit    = 1
  snapshot_window            = "02:00-03:00"
  
  tags = {
    Name        = "${var.project_name}-redis"
    Environment = var.environment
  }
}

# Security Group for ElastiCache
resource "aws_security_group" "elasticache" {
  name_prefix = "${var.project_name}-elasticache-"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Redis from Lambda"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-elasticache-sg"
    Environment = var.environment
  }
}
