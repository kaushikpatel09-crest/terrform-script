terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# S3 Bucket - Landing Zone
resource "aws_s3_bucket" "landing" {
  bucket = "${var.project_name}-landing-${var.environment}"

  tags = {
    Name = "${var.project_name}-landing-${var.environment}"
    Zone = "landing"
  }
}

# Enable versioning for landing zone
#resource "aws_s3_bucket_versioning" "landing" {
#  bucket = aws_s3_bucket.landing.id

#  versioning_configuration {
#    status = "Enabled"
#  }
#}

# Enable encryption for landing zone
resource "aws_s3_bucket_server_side_encryption_configuration" "landing" {
  bucket = aws_s3_bucket.landing.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access for landing zone
resource "aws_s3_bucket_public_access_block" "landing" {
  bucket = aws_s3_bucket.landing.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket - Raw Zone
resource "aws_s3_bucket" "raw" {
  bucket = "${var.project_name}-raw-${var.environment}"

  tags = {
    Name = "${var.project_name}-raw-${var.environment}"
    Zone = "raw"
  }
}

# Enable versioning for raw zone
#resource "aws_s3_bucket_versioning" "raw" {
#  bucket = aws_s3_bucket.raw.id

#  versioning_configuration {
#    status = "Enabled"
#  }
#}

# Enable encryption for raw zone
resource "aws_s3_bucket_server_side_encryption_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access for raw zone
resource "aws_s3_bucket_public_access_block" "raw" {
  bucket = aws_s3_bucket.raw.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
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
