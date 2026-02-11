output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = [for subnet in aws_subnet.private : subnet.id]
}

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = aws_nat_gateway.main.id
}

output "nat_gateway_public_ip" {
  description = "NAT Gateway public IP"
  value       = aws_eip.nat.public_ip
}

output "alb_public_security_group_id" {
  description = "Public ALB security group ID"
  value       = aws_security_group.alb_public.id
}

output "alb_internal_security_group_id" {
  description = "Internal ALB security group ID"
  value       = aws_security_group.alb_internal.id
}

output "ecs_frontend_security_group_id" {
  description = "ECS Frontend security group ID"
  value       = aws_security_group.ecs_frontend.id
}

output "ecs_backend_security_group_id" {
  description = "ECS Backend security group ID"
  value       = aws_security_group.ecs_backend.id
}

output "ecs_ingestion_security_group_id" {
  description = "ECS Ingestion security group ID"
  value       = aws_security_group.ecs_ingestion.id
}

output "documentdb_security_group_id" {
  description = "DocumentDB security group ID"
  value       = aws_security_group.documentdb.id
}
