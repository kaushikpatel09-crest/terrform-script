output "collection_id" {
  description = "OpenSearch collection ID"
  value       = aws_opensearchserverless_collection.main.id
}

output "collection_arn" {
  description = "OpenSearch collection ARN"
  value       = aws_opensearchserverless_collection.main.arn
}

output "collection_endpoint" {
  description = "OpenSearch collection endpoint"
  value       = aws_opensearchserverless_collection.main.collection_endpoint
}

output "dashboard_endpoint" {
  description = "OpenSearch dashboard endpoint"
  value       = aws_opensearchserverless_collection.main.dashboard_endpoint
}

output "security_group_id" {
  description = "OpenSearch security group ID"
  value       = aws_security_group.opensearch.id
}