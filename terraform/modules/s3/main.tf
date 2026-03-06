terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Pre-existing bucket — created manually in AWS, NOT managed by Terraform.
# We only look it up here so its ARN/name can be passed to IAM policies
# and environment variables. Terraform will never modify or destroy it.
# ─────────────────────────────────────────────────────────────────────────────
data "aws_s3_bucket" "video_outputs" {
  bucket = "cne-production-video-outputs-demo"
}

# S3 Bucket - Processed Zone
resource "aws_s3_bucket" "processed" {
  bucket = "${var.project_name}-processed-${var.environment}"

  tags = {
    Name = "${var.project_name}-processed-${var.environment}"
    Zone = "processed"
  }
}

# Enable versioning for processed zone
#resource "aws_s3_bucket_versioning" "processed" {
#  bucket = aws_s3_bucket.processed.id

#  versioning_configuration {
#    status = "Enabled"
#  }
#}

# Enable encryption for processed zone
resource "aws_s3_bucket_server_side_encryption_configuration" "processed" {
  bucket = aws_s3_bucket.processed.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access for processed zone
resource "aws_s3_bucket_public_access_block" "processed" {
  bucket = aws_s3_bucket.processed.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}



# S3 Bucket - image-search
resource "aws_s3_bucket" "image_search" {
  bucket = "${var.project_name}-image-search-${var.environment}"

  tags = {
    Name = "${var.project_name}-image-search-${var.environment}"
    Zone = "image-search"
  }
}

# Enable versioning for image-search
#resource "aws_s3_bucket_versioning" "landing" {
#  bucket = aws_s3_bucket.landing.id

#  versioning_configuration {
#    status = "Enabled"
#  }
#}

# Enable encryption for image-search
resource "aws_s3_bucket_server_side_encryption_configuration" "image_search" {
  bucket = aws_s3_bucket.image_search.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access for image-search
resource "aws_s3_bucket_public_access_block" "image_search" {
  bucket = aws_s3_bucket.image_search.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
