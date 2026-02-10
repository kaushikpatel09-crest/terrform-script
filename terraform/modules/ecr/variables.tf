variable "repository_name" {
  type        = string
  description = "Name of the ECR repository"
}

variable "image_tag_mutability" {
  type        = string
  description = "The tag mutability setting for the repository (MUTABLE or IMMUTABLE)"
  default     = "MUTABLE"
}

variable "scan_on_push" {
  type        = bool
  description = "Indicates whether images are scanned after being pushed to the repository"
  default     = true
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "project_name" {
  type        = string
  description = "Project name"
}
