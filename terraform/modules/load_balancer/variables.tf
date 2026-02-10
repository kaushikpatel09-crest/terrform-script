variable "environment" {
  type        = string
  description = "Environment name"
}

variable "project_name" {
  type        = string
  description = "Project name"
}

variable "load_balancer_name" {
  type        = string
  description = "Load balancer name"
}

variable "internal" {
  type        = bool
  description = "Whether the load balancer is internal"
  default     = false
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

variable "target_group_name" {
  type        = string
  description = "Target group name"
}

variable "target_group_port" {
  type        = number
  description = "Target group port"
  default     = 3000
}

variable "target_type" {
  type        = string
  description = "Target type (instance, ip, lambda)"
  default     = "ip"
}

variable "health_check_path" {
  type        = string
  description = "Health check path"
  default     = "/"
}

variable "enable_https" {
  type        = bool
  description = "Enable HTTPS"
  default     = false
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate ARN"
  default     = ""
}
