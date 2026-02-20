output "landing_bucket_name" {
  description = "Landing zone S3 bucket name"
  value       = aws_s3_bucket.landing.id
}

output "landing_bucket_arn" {
  description = "Landing zone S3 bucket ARN"
  value       = aws_s3_bucket.landing.arn
}

output "raw_bucket_name" {
  description = "Raw zone S3 bucket name"
  value       = aws_s3_bucket.raw.id
}

output "raw_bucket_arn" {
  description = "Raw zone S3 bucket ARN"
  value       = aws_s3_bucket.raw.arn
}

output "processed_bucket_name" {
  description = "Processed zone S3 bucket name"
  value       = aws_s3_bucket.processed.id
}

output "processed_bucket_arn" {
  description = "Processed zone S3 bucket ARN"
  value       = aws_s3_bucket.processed.arn
}

output "image_search_bucket_arn" {
  description = "Image search S3 bucket ARN"
  value       = aws_s3_bucket.image_search.arn
}

output "all_bucket_arns" {
  description = "All S3 bucket ARNs"
  value = [
    aws_s3_bucket.landing.arn,
    aws_s3_bucket.raw.arn,
    aws_s3_bucket.processed.arn,
    aws_s3_bucket.image_search.arn
  ]
}

output "image_search_bucket_name" {
  description = "Image search S3 bucket name"
  value       = aws_s3_bucket.image_search.id
}

output "landing" {
  description = "Landing S3 bucket name"
  value       = aws_s3_bucket.landing.id
}
