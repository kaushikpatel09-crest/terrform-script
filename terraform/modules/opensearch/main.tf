terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

############################
# Encryption Policy
############################
resource "aws_opensearchserverless_security_policy" "encryption" {
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

############################
# VPC Endpoint
############################
resource "aws_opensearchserverless_vpc_endpoint" "main" {
  name               = "${var.project_name}-aoss-vpce-${var.environment}"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = [aws_security_group.aoss_endpoint.id]
}

############################
# Security Group for VPC Endpoint
############################
resource "aws_security_group" "aoss_endpoint" {
  name        = "${var.project_name}-aoss-sg-${var.environment}"
  description = "Security group for OpenSearch Serverless endpoint"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTPS from ECS Backend"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = [
      var.backend_service_security_group_id,
      var.ingestion_service_security_group_id
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################
# Network Policy
############################
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

############################
# Collection
############################
resource "aws_opensearchserverless_collection" "main" {
  name             = "${var.project_name}-opensearch-${var.environment}"
  type             = "VECTORSEARCH"
  standby_replicas = "ENABLED"

  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network
  ]
}

############################
# Data Access Policy
############################
resource "aws_opensearchserverless_access_policy" "data_access" {
  name = "${var.project_name}-aoss-access-${var.environment}"
  type = "data"

  policy = jsonencode([
    {
      Principal = [
        var.backend_service_role_arn,
        var.ingestion_service_role_arn
      ]
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${aws_opensearchserverless_collection.main.name}"]
          Permission = [
            "aoss:DescribeCollectionItems",
            "aoss:CreateCollectionItems",
            "aoss:UpdateCollectionItems",
            "aoss:DeleteCollectionItems"
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
    }
  ])
}


