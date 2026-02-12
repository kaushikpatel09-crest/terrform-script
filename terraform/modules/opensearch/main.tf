terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# 1. Encryption Policy (Must strictly exist before collection creation)
resource "aws_opensearchserverless_security_policy" "encryption" {
  name        = "${var.project_name}-encryption-${var.environment}"
  type        = "encryption"
  description = "Encryption policy for OpenSearch Serverless"
  policy = jsonencode({
    Rules = [
      {
        ResourceType = "collection"
        Resource = [
          "collection/${var.project_name}-os-${var.environment}"
        ]
      }
    ]
    AWSOwnedKey = true
  })
}

# 2. VPC Endpoint Security Group
resource "aws_security_group" "opensearch" {
  name        = "${var.project_name}-opensearch-sg-${var.environment}"
  description = "Security group for OpenSearch VPC Endpoint"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-opensearch-sg-${var.environment}"
  }
}

resource "aws_security_group_rule" "ingress_ingestion" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.opensearch.id
  source_security_group_id = var.ingestion_service_security_group_id
  description              = "Allow HTTPS from Ingestion ECS service"
}

resource "aws_security_group_rule" "ingress_backend" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.opensearch.id
  source_security_group_id = var.backend_service_security_group_id
  description              = "Allow HTTPS from Backend ECS service"
}

resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.opensearch.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# 3. VPC Endpoint
resource "aws_opensearchserverless_vpc_endpoint" "main" {
  name               = "${var.project_name}-os-vpce-${var.environment}"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = [aws_security_group.opensearch.id]
}

# 4. Network Policy (Depends on VPCE)
resource "aws_opensearchserverless_security_policy" "network" {
  name        = "${var.project_name}-network-${var.environment}"
  type        = "network"
  description = "Network policy for OpenSearch Serverless"
  policy = jsonencode([
    {
      Description = "Private access via VPC Endpoint",
      Rules = [
        {
          ResourceType = "collection",
          Resource = [
            "collection/${var.project_name}-os-${var.environment}"
          ]
        },
        {
          ResourceType = "dashboard",
          Resource = [
            "collection/${var.project_name}-os-${var.environment}"
          ]
        }
      ],
      AllowFromPublic = false,
      SourceVPCEs = [
        aws_opensearchserverless_vpc_endpoint.main.id
      ]
    }
  ])

  # Ensure endpoint is ready before applying policy referencing it
  depends_on = [aws_opensearchserverless_vpc_endpoint.main]
}

# 5. Collection (Depends on Encryption Policy)
resource "aws_opensearchserverless_collection" "main" {
  name = "${var.project_name}-os-${var.environment}"
  type = "VECTORSEARCH"

  # Encryption policy must be applied first to matched collection name
  depends_on = [
    aws_opensearchserverless_security_policy.encryption
  ]

  tags = {
    Name = "${var.project_name}-os-${var.environment}"
  }
}

# Note: Access Policy has been moved to root main.tf to avoid dependency cycle with ECS roles.
