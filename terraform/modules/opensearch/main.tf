terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# OpenSearch Serverless collection with standby replicas
resource "aws_opensearchserverless_collection" "main" {
  name = "${var.project_name}-opensearch-${var.environment}"
  type = "SEARCH"
  # Enable standby replicas for higher availability
  standby_replicas = "ENABLED"

  tags = {
    Name = "${var.project_name}-opensearch-${var.environment}"
  }
}

# OpenSearch Security Group
resource "aws_security_group" "opensearch" {
  name        = "${var.project_name}-opensearch-sg-${var.environment}"
  description = "Security group for OpenSearch"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    security_groups = [
      var.ingestion_service_security_group_id,
      var.backend_service_security_group_id
    ]
    description = "Allow HTTPS from Ingestion and Backend ECS services"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-opensearch-sg-${var.environment}"
  }
}

# OpenSearch access policy for ECS ingestion and backend
resource "aws_opensearchserverless_access_policy" "main" {
  name        = "${var.project_name}-opensearch-access-${var.environment}"
  type        = "data"
  description = "Access policy for OpenSearch collection"
  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${aws_opensearchserverless_collection.main.name}"]
          Permission = [
            "aoss:CreateCollectionItems",
            "aoss:DeleteCollectionItems",
            "aoss:UpdateCollectionItems",
            "aoss:DescribeCollectionItems"
          ]
          Principal = [
            var.ingestion_service_role_arn,
            var.backend_service_role_arn
          ]
        },
        {
          ResourceType = "index"
          Resource     = ["index/${aws_opensearchserverless_collection.main.name}/*"]
          Permission = [
            "aoss:CreateIndex",
            "aoss:DeleteIndex",
            "aoss:UpdateIndex",
            "aoss:DescribeIndex",
            "aoss:ReadDocument",
            "aoss:WriteDocument"
          ]
          Principal = [
            var.ingestion_service_role_arn,
            var.backend_service_role_arn
          ]
        }
      ]
    }
  ])
}

# OpenSearch VPC endpoint for private access
resource "aws_opensearchserverless_vpc_endpoint" "main" {
  name               = "${var.project_name}-opensearch-vpc-ep-${var.environment}"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = [aws_security_group.opensearch.id]
}
