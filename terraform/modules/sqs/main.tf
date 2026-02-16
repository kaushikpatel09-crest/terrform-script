terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Dead Letter Queue
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.project_name}-${var.queue_name}-dlq-${var.environment}"
  message_retention_seconds = var.dlq_retention_days * 86400
}

# Main Queue
resource "aws_sqs_queue" "main" {
  name                       = "${var.project_name}-${var.queue_name}-${var.environment}"
  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 5
  })

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

/*
# Queue Policy to allow S3 notifications
resource "aws_sqs_queue_policy" "allow_s3" {
  queue_url = aws_sqs_queue.main.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "s3.amazonaws.com"
        },
        Action   = "sqs:SendMessage",
        Resource = aws_sqs_queue.main.arn,
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = var.s3_bucket_arn
          }
        }
      }
    ]
  })
}
*/
