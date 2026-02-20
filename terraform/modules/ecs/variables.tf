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
  default     = ""
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

variable "s3_bucket_arns" {
  type        = list(string)
  description = "(Optional) List of S3 bucket ARNs that this service is allowed to access. Leave empty to skip granting S3 permissions."
  default     = []
}

variable "enable_s3_access" {
  type        = bool
  description = "Enable S3 CRUD access for this ECS service"
  default     = false
}

variable "ecr_repository_arn" {
  type        = string
  description = "(Optional) ARN of ECR repository for image access. Leave empty to skip granting ECR permissions."
  default     = ""
}

variable "sqs_queue_arn" {
  type        = string
  description = "(Optional) ARN of SQS queue for message processing permissions."
  default     = ""
}

variable "enable_sqs_access" {
  type        = bool
  description = "Enable SQS queue access permissions"
  default     = false
}

variable "environment_variables" {
  type        = map(string)
  description = "(Optional) Map of environment variables to set in the container. Example: { BE_BASE_URL = 'https://api.example.com' }"
  default     = {}
}

variable "enable_ecs_opensearch_access" {
  type        = bool
  description = "Enable OpenSearch access for this ECS service"
  default     = true
}

variable "opensearch_collection_arn" {
  type        = string
  description = "(Optional) ARN of the OpenSearch Serverless collection this service is allowed to access. Required when enable_ecs_opensearch_access is true."
  default     = ""
}
