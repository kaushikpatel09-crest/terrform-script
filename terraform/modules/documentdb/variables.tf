variable "environment" {
  type        = string
  description = "Environment name"
}

variable "project_name" {
  type        = string
  description = "Project name"
}

variable "cluster_identifier" {
  type        = string
  description = "DocumentDB cluster identifier"
}

variable "engine_version" {
  type        = string
  description = "DocumentDB engine version"
  default     = "4.0.0"
}

variable "master_username" {
  type        = string
  description = "Master username"
  sensitive   = true
}

variable "master_password" {
  type        = string
  description = "Master password"
  sensitive   = true

  validation {
    condition     = length(var.master_password) >= 8
    error_message = "Password must be at least 8 characters long."
  }
}

variable "backup_retention_days" {
  type        = number
  description = "Backup retention days"
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "Backup retention days must be between 1 and 35."
  }
}

variable "num_instances" {
  type        = number
  description = "Number of instances"
  default     = 1

  validation {
    condition     = var.num_instances >= 1 && var.num_instances <= 15
    error_message = "Number of instances must be between 1 and 15."
  }
}

variable "instance_class" {
  type        = string
  description = "Instance class"
  default     = "db.t3.medium"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs"
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security group IDs"
}

variable "skip_final_snapshot" {
  type        = bool
  description = "Skip final snapshot on deletion"
  default     = false
}
