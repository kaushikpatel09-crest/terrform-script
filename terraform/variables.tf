variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, qa, stage)"
  validation {
    condition     = contains(["dev", "qa", "stage"], var.environment)
    error_message = "Environment must be dev, qa, or stage."
  }
}

variable "project_name" {
  type        = string
  description = "Project name"
  default     = "conde-nast"
}

# VPC Variables
variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block"
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Public subnet CIDR blocks"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Private subnet CIDR blocks (3 subnets required)"

  validation {
    condition     = length(var.private_subnet_cidrs) == 3
    error_message = "Must provide exactly 3 rivate subnet CIDR blocks."
  }
}

# ECS Frontend Variables
variable "frontend_image" {
  type        = string
  description = "Frontend container image URL"
  default     = "nginx:latest"
}

variable "frontend_image_tag" {
  type        = string
  description = "Frontend container image tag"
  default     = "latest"
}

variable "frontend_task_cpu" {
  type        = number
  description = "Frontend task CPU"
  default     = 256
}

variable "frontend_task_memory" {
  type        = number
  description = "Frontend task memory in MB"
  default     = 512
}

variable "frontend_desired_count" {
  type        = number
  description = "Desired number of frontend tasks"
  default     = 2
}

variable "frontend_min_capacity" {
  type        = number
  description = "Minimum frontend capacity"
  default     = 1
}

variable "frontend_max_capacity" {
  type        = number
  description = "Maximum frontend capacity"
  default     = 4
}

# ECS Backend Variables
variable "backend_image" {
  type        = string
  description = "Backend container image URL"
  default     = "node:18-alpine"
}

variable "backend_image_tag" {
  type        = string
  description = "Backend container image tag"
  default     = "latest"
}

variable "backend_task_cpu" {
  type        = number
  description = "Backend task CPU"
  default     = 512
}

variable "backend_task_memory" {
  type        = number
  description = "Backend task memory in MB"
  default     = 1024
}

variable "backend_desired_count" {
  type        = number
  description = "Desired number of backend tasks"
  default     = 2
}

variable "backend_min_capacity" {
  type        = number
  description = "Minimum backend capacity"
  default     = 1
}

variable "backend_max_capacity" {
  type        = number
  description = "Maximum backend capacity"
  default     = 4
}

# DocumentDB Variables
variable "documentdb_engine_version" {
  type        = string
  description = "DocumentDB engine version"
  default     = "4.0.0"
}

variable "documentdb_master_username" {
  type        = string
  description = "DocumentDB master username"
  sensitive   = true
  default     = "admin"
}

variable "documentdb_master_password" {
  type        = string
  description = "DocumentDB master password"
  sensitive   = true
}

variable "documentdb_backup_retention_days" {
  type        = number
  description = "DocumentDB backup retention days"
  default     = 7
}

variable "documentdb_num_instances" {
  type        = number
  description = "Number of DocumentDB instances"
  default     = 1
}

variable "documentdb_instance_class" {
  type        = string
  description = "DocumentDB instance class"
  default     = "db.t3.medium"
}

variable "documentdb_skip_final_snapshot" {
  type        = bool
  description = "Skip final snapshot on cluster deletion"
  default     = false
}

# Load Balancer Variables
variable "enable_https" {
  type        = bool
  description = "Enable HTTPS for external ALB"
  default     = false
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate ARN for HTTPS"
  default     = ""
}

variable "bedrock_model_arn" {
  type        = string
  description = "ARN of the Bedrock model to use for inference"
  default     = ""
}

# Ingestion Service Variables
variable "ingestion_image" {
  type        = string
  description = "Container image for Ingestion service"
  default     = "node"
}

variable "ingestion_image_tag" {
  type        = string
  description = "Container image tag for Ingestion service"
  default     = "18-alpine"
}

variable "ingestion_task_cpu" {
  type        = number
  description = "Ingestion task CPU (256, 512, 1024, 2048, 4096)"
  default     = 512
}

variable "ingestion_task_memory" {
  type        = number
  description = "Ingestion task memory in MB"
  default     = 1024
}

variable "ingestion_desired_count" {
  type        = number
  description = "Desired number of Ingestion tasks"
  default     = 1
}

variable "ingestion_min_capacity" {
  type        = number
  description = "Minimum Ingestion capacity"
  default     = 1
}

variable "ingestion_max_capacity" {
  type        = number
  description = "Maximum Ingestion capacity"
  default     = 3
}

variable "ecr_repository_arn" {
  type        = string
  description = "(Optional) ARN of ECR repository for image access"
  default     = ""
}