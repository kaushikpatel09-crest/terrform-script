variable "environment" {
  type        = string
  description = "Environment name"
}

variable "project_name" {
  type        = string
  description = "Project name"
}

variable "queue_name" {
  type        = string
  description = "Name of the SQS queue"
}

variable "s3_bucket_arn" {
  type        = string
  description = "ARN of the S3 bucket that will send notifications"
}

variable "dlq_retention_days" {
  type        = number
  description = "Days until DLQ messages are deleted"
  default     = 14
}

variable "message_retention_seconds" {
  type        = number
  description = "Seconds until messages are deleted"
  default     = 345600 # 4 days
}

variable "visibility_timeout_seconds" {
  type        = number
  description = "Visibility timeout for messages"
  default     = 300 # 5 minutes
}
