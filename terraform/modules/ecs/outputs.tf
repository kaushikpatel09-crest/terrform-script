output "cluster_name" {
  description = "ECS cluster name"
  value       = var.create_cluster ? aws_ecs_cluster.main[0].name : var.cluster_name
}

output "cluster_arn" {
  description = "ECS cluster ARN"
  value       = var.create_cluster ? aws_ecs_cluster.main[0].arn : ""
}

output "service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.main.name
}

output "task_definition_arn" {
  description = "ECS task definition ARN"
  value       = aws_ecs_task_definition.main.arn
}

output "task_role_arn" {
  description = "ECS task IAM role ARN"
  value       = aws_iam_role.ecs_task_role.arn
}
