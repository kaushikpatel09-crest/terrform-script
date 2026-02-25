variable "environment" {
  type        = string
  description = "Environment name"
}

variable "project_name" {
  type        = string
  description = "Project name"
}

variable "secret_name" {
  type        = string
  description = "The name of the secret"
}

variable "secret_description" {
  type        = string
  description = "The description of the secret"
  default     = ""
}

variable "secret_string" {
  type        = string
  description = "The secret string value"
  sensitive   = true
}

variable "recovery_window_in_days" {
  type        = number
  description = "Number of days to retain deleted secrets (set to 0 for immediate deletion)"
  default     = 7
}
