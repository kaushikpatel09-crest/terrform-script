output "cluster_id" {
  description = "DocumentDB cluster ID"
  value       = aws_docdb_cluster.main.id
}

output "cluster_arn" {
  description = "DocumentDB cluster ARN"
  value       = aws_docdb_cluster.main.arn
}

output "cluster_endpoint" {
  description = "DocumentDB cluster endpoint"
  value       = aws_docdb_cluster.main.endpoint
  sensitive   = true
}

output "reader_endpoint" {
  description = "DocumentDB reader endpoint"
  value       = aws_docdb_cluster.main.reader_endpoint
  sensitive   = true
}

output "port" {
  description = "DocumentDB port"
  value       = aws_docdb_cluster.main.port
}

output "master_username" {
  description = "Master username"
  value       = aws_docdb_cluster.main.master_username
  sensitive   = true
}
