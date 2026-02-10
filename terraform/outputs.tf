output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = module.vpc.nat_gateway_id
}

output "nat_gateway_public_ip" {
  description = "NAT Gateway public IP"
  value       = module.vpc.nat_gateway_public_ip
}

# ECS Frontend Outputs
output "ecs_frontend_cluster_name" {
  description = "ECS frontend cluster name"
  value       = module.ecs_frontend.cluster_name
}

output "ecs_frontend_service_name" {
  description = "ECS frontend service name"
  value       = module.ecs_frontend.service_name
}

# ECS Backend Outputs
output "ecs_backend_cluster_name" {
  description = "ECS backend cluster name"
  value       = module.ecs_backend.cluster_name
}

output "ecs_backend_service_name" {
  description = "ECS backend service name"
  value       = module.ecs_backend.service_name
}

# DocumentDB Outputs
output "documentdb_cluster_endpoint" {
  description = "DocumentDB cluster endpoint"
  value       = module.documentdb.cluster_endpoint
  sensitive   = true
}

output "documentdb_reader_endpoint" {
  description = "DocumentDB reader endpoint"
  value       = module.documentdb.reader_endpoint
  sensitive   = true
}

# External ALB Outputs
output "external_alb_dns_name" {
  description = "External ALB DNS name"
  value       = module.external_alb.load_balancer_dns_name
}

output "external_alb_arn" {
  description = "External ALB ARN"
  value       = module.external_alb.load_balancer_arn
}

# Internal ALB Outputs
output "internal_alb_dns_name" {
  description = "Internal ALB DNS name"
  value       = module.internal_alb.load_balancer_dns_name
}

output "internal_alb_arn" {
  description = "Internal ALB ARN"
  value       = module.internal_alb.load_balancer_arn
}

# ECR Outputs
output "ecr_frontend_repository_url" {
  description = "ECR frontend repository URL"
  value       = module.ecr_frontend.repository_url
}

output "ecr_frontend_repository_name" {
  description = "ECR frontend repository name"
  value       = module.ecr_frontend.repository_name
}

output "ecr_backend_repository_url" {
  description = "ECR backend repository URL"
  value       = module.ecr_backend.repository_url
}

output "ecr_backend_repository_name" {
  description = "ECR backend repository name"
  value       = module.ecr_backend.repository_name
}
