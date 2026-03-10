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

output "documentdb_uri" {
  description = "Connection URI for DocumentDB"
  # Notes on the connection string parameters:
  # - directConnection=true: Connects directly to the DocumentDB cluster proxy endpoint
  #   without triggering PyMongo's replica set topology discovery. Without this,
  #   PyMongo sees 'replicaSet' mode, tries to resolve internal member hostnames from
  #   the isMaster response, and fails with ReplicaSetNoPrimary / server_type Unknown.
  # - replicaSet=rs0 is intentionally OMITTED for the same reason above.
  # - retryWrites=false: Required for DocumentDB — retryable writes are not supported.
  # - readPreference=secondaryPreferred: Allows reads from replicas to reduce load.
  # - tls=false: TLS is disabled at the parameter group level (tls=disabled).
  value     = "mongodb://${aws_docdb_cluster.main.master_username}:${var.master_password}@${aws_docdb_cluster.main.endpoint}:${aws_docdb_cluster.main.port}/?tls=true&directConnection=true&readPreference=secondaryPreferred&retryWrites=false"
  sensitive = true
}
