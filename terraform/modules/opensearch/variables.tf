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

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for VPC endpoint"
}

variable "ingestion_service_security_group_id" {
  type        = string
  description = "Security group ID of the Ingestion ECS service"
}

variable "backend_service_security_group_id" {
  type        = string
  description = "Security group ID of the Backend ECS service"
}

# Removed role ARNs to break dependency cycle
