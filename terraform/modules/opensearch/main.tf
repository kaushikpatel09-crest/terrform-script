terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Encryption policy required for the collection
resource "aws_opensearchserverless_security_policy" "encryption" {
  # Name must be 3–32 characters
  name = "${var.project_name}-aoss-enc-${var.environment}"
  type = "encryption"

  policy = jsonencode({
    Rules = [{
      ResourceType = "collection"
      Resource     = ["collection/${var.project_name}-opensearch-${var.environment}"]
    }]
    AWSOwnedKey = true
  })
}

# OpenSearch Serverless VECTOR collection with standby replicas
resource "aws_opensearchserverless_collection" "main" {
  name             = "${var.project_name}-opensearch-${var.environment}"
  type             = "VECTORSEARCH"
  standby_replicas = "ENABLED"

  # Ensure encryption and network policies exist first
  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network
  ]

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
        }
      ]
      Principal = [
        var.ingestion_service_role_arn,
        var.backend_service_role_arn
      ]
    }
  ])
}

# Network security policy - private access via VPC endpoint only
resource "aws_opensearchserverless_security_policy" "network" {
  name = "${var.project_name}-aoss-net-${var.environment}"
  type = "network"

  policy = jsonencode([
    {
      Rules = [{
        ResourceType = "collection"
        Resource     = ["collection/${var.project_name}-opensearch-${var.environment}"]
      }]
      AllowFromPublic = false
      SourceVPCEs     = [aws_opensearchserverless_vpc_endpoint.main.id]
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
