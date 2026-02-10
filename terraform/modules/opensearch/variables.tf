variable "environment" {
  type        = string
  description = "Environment name"
}

variable "project_name" {
  type        = string
  description = "Project name"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "ingestion_service_security_group_id" {
  type        = string
  description = "Security group ID of the Ingestion ECS service"
}

variable "ingestion_service_role_arn" {
  type        = string
  description = "IAM role ARN of the Ingestion ECS service"
}
