variable "environment" {
  type        = string
  description = "Environment name"
}

variable "project_name" {
  type        = string
  description = "Project name"
}

variable "cluster_name" {
  type        = string
  description = "ECS cluster name"
}

variable "service_name" {
  type        = string
  description = "ECS service name"
}

variable "container_name" {
  type        = string
  description = "Container name"
}

variable "container_port" {
  type        = number
  description = "Container port"
}

variable "container_image" {
  type        = string
  description = "Container image"
}

variable "container_image_tag" {
  type        = string
  description = "Container image tag"
  default     = "latest"
}

variable "task_cpu" {
  type        = number
  description = "Task CPU (256, 512, 1024, 2048, 4096)"
}

variable "task_memory" {
  type        = number
  description = "Task memory in MB"
}

variable "desired_count" {
  type        = number
  description = "Desired number of tasks"
}

variable "min_capacity" {
  type        = number
  description = "Minimum capacity"
}

variable "max_capacity" {
  type        = number
  description = "Maximum capacity"
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

variable "load_balancer_target_group_arn" {
  type        = string
  description = "Load balancer target group ARN"
}

variable "log_group_name" {
  type        = string
  description = "CloudWatch log group name"
}

variable "bedrock_model_arn" {
  type        = string
  description = "(Optional) ARN of the Bedrock model that this service is allowed to invoke. Leave empty to skip granting Bedrock permissions."
  default     = ""
}
