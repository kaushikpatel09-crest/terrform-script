terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  }
}

# ECR Frontend Repository
module "ecr_frontend" {
  source = "./modules/ecr"

  repository_name = "${var.project_name}-frontend-${var.environment}"
  environment     = var.environment
  project_name    = var.project_name
  scan_on_push    = true
}

# ECR Backend Repository
module "ecr_backend" {
  source = "./modules/ecr"

  repository_name = "${var.project_name}-backend-${var.environment}"
  environment     = var.environment
  project_name    = var.project_name
  scan_on_push    = true
}

# ECR Ingestion Repository
module "ecr_ingestion" {
  source = "./modules/ecr"

  repository_name = "${var.project_name}-ingestion-${var.environment}"
  environment     = var.environment
  project_name    = var.project_name
  scan_on_push    = true
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  environment          = var.environment
  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

# ECS Frontend Module
module "ecs_frontend" {
  source = "./modules/ecs"

  environment    = var.environment
  project_name   = var.project_name
  cluster_name   = "${var.project_name}-fe-${var.environment}"
  service_name   = "fe-service"
  container_name = "frontend"
  container_port = 3000
  task_cpu       = var.frontend_task_cpu
  task_memory    = var.frontend_task_memory
  desired_count  = var.frontend_desired_count
  min_capacity   = var.frontend_min_capacity
  max_capacity   = var.frontend_max_capacity

  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.ecs_frontend_security_group_id]

  container_image     = var.frontend_image
  container_image_tag = var.frontend_image_tag
  log_group_name      = "/ecs/${var.project_name}-fe-${var.environment}"

  #ecr_repository_arn = var.frontend_ecr_repository_arn
  ecr_repository_arn = module.ecr_frontend.repository_arn

  environment_variables = {
    VITE_BE_BASE_URL = var.backend_base_url
  }

  load_balancer_target_group_arn = module.external_alb.target_group_arn

  depends_on = [module.vpc, module.external_alb]
}

# ECS Backend Module
module "ecs_backend" {
  source = "./modules/ecs"

  environment    = var.environment
  project_name   = var.project_name
  cluster_name   = "${var.project_name}-be-${var.environment}"
  service_name   = "be-service"
  container_name = "backend"
  container_port = 8080
  task_cpu       = var.backend_task_cpu
  task_memory    = var.backend_task_memory
  desired_count  = var.backend_desired_count
  min_capacity   = var.backend_min_capacity
  max_capacity   = var.backend_max_capacity

  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.ecs_backend_security_group_id]

  container_image     = var.backend_image
  container_image_tag = var.backend_image_tag
  log_group_name      = "/ecs/${var.project_name}-be-${var.environment}"
  bedrock_model_arn   = var.bedrock_model_arn

  #ecr_repository_arn = var.backend_ecr_repository_arn
  ecr_repository_arn = module.ecr_backend.repository_arn

  load_balancer_target_group_arn = module.internal_alb.target_group_arn

  depends_on = [module.vpc, module.internal_alb]
  environment_variables = {
    OPENSEARCH_ENDPOINT   = module.opensearch.collection_endpoint
    OPENSEARCH_REGION     = var.aws_region
    OPENSEARCH_SERVICE    = var.opensearch_service
    OPENSEARCH_INDEX_NAME = var.opensearch_index_name
    EMBEDDING_MODEL_NAME  = var.embedding_model_name
    S3_BUCKET_OWNER_ID    = data.aws_caller_identity.current.account_id
    IMAGE_SEARCH_BUCKET   = module.s3_buckets.image_search_bucket_name
    DOCUMENTDB_URI        = module.documentdb.documentdb_uri
    DB_NAME               = var.db_name
    ERRORS_COLLECTION     = var.errors_collection
    SEARCH_COLLECTION     = var.search_collection
  }


}

# SQS Module for Landing S3 Notifications
module "sqs_landing" {
  source = "./modules/sqs"

  environment   = var.environment
  project_name  = var.project_name
  queue_name    = "landing-events"
  s3_bucket_arn = module.s3_buckets.landing_bucket_arn
}

# S3 Bucket Notification (Landing -> SQS)
resource "aws_s3_bucket_notification" "landing_to_sqs" {
  bucket = module.s3_buckets.landing_bucket_name

  queue {
    queue_arn = module.sqs_landing.queue_arn
    events    = ["s3:ObjectCreated:*"]
    # filter_suffix = ".json" # Example filter, can be removed or adjusted
  }

  depends_on = [module.sqs_landing]
}

# ECS Ingestion Backend Service
module "ecs_ingestion" {
  source = "./modules/ecs"

  environment    = var.environment
  project_name   = var.project_name
  cluster_name   = "${var.project_name}-ingestion-${var.environment}"
  service_name   = "ingestion-service"
  container_name = "ingestion"
  container_port = 9001
  task_cpu       = var.ingestion_task_cpu
  task_memory    = var.ingestion_task_memory
  desired_count  = var.ingestion_desired_count
  min_capacity   = var.ingestion_min_capacity
  max_capacity   = var.ingestion_max_capacity

  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.ecs_ingestion_security_group_id]

  container_image     = var.ingestion_image
  container_image_tag = var.ingestion_image_tag
  log_group_name      = "/ecs/${var.project_name}-ingestion-${var.environment}"

  # S3 bucket access
  enable_s3_access             = true
  s3_bucket_arns               = module.s3_buckets.all_bucket_arns
  bedrock_model_arn            = var.bedrock_model_arn
 # ecr_repository_arn           = var.ingestion_ecr_repository_arn
  ecr_repository_arn           = module.ecr_ingestion.repository_arn
  sqs_queue_arn                = module.sqs_landing.queue_arn
  enable_sqs_access            = true
  enable_ecs_opensearch_access = true

  depends_on = [module.vpc, module.s3_buckets, module.sqs_landing]

  environment_variables = {
    OPENSEARCH_ENDPOINT    = module.opensearch.collection_endpoint
    SQS_QUEUE_URL          = module.sqs_landing.queue_url
    AWS_REGION             = var.aws_region
    SQS_VISIBILITY_TIMEOUT = var.ingestion_sqs_visibility_timeout
    SQS_WAIT_TIME_SECONDS  = var.ingestion_sqs_wait_time_seconds
    SQS_HEARTBEAT_INTERVAL = var.ingestion_sqs_heartbeat_interval
    SQS_MAX_MESSAGES       = var.ingestion_sqs_max_messages
    CONCURRENCY            = var.ingestion_concurrency
    INDEX_NAME             = var.ingestion_index_name
    MAX_SIZE_GB            = var.ingestion_max_size_gb
    MAX_DURATION_MINUTES   = var.ingestion_max_duration_minutes
    MAX_WAIT_TIME_SECONDS  = var.ingestion_max_wait_time_seconds
    POLL_INTERVAL_SECONDS  = var.ingestion_poll_interval_seconds
    PROCESSED_BUCKET       = module.s3_buckets.landing_bucket_name
    AWS_BUCKET_OWNER       = data.aws_caller_identity.current.account_id
    DOCUMENTDB_URI         = module.documentdb.documentdb_uri
    DB_NAME                = var.db_name
    JOBS_COLLECTION        = var.jobs_collection
    ERRORS_COLLECTION      = var.errors_collection
    SEARCH_COLLECTION      = var.search_collection


  }
}

# DocumentDB Module (3rd Private Subnet)
module "documentdb" {
  source = "./modules/documentdb"

  environment           = var.environment
  project_name          = var.project_name
  cluster_identifier    = "${var.project_name}-docdb-${var.environment}-v3"
  engine_version        = var.documentdb_engine_version
  master_username       = var.documentdb_master_username
  master_password       = var.documentdb_master_password
  backup_retention_days = var.documentdb_backup_retention_days
  num_instances         = var.documentdb_num_instances
  instance_class        = var.documentdb_instance_class

  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.documentdb_security_group_id]

  skip_final_snapshot = var.documentdb_skip_final_snapshot

  depends_on = [module.vpc]
}

# External ALB (Public facing from Internet Gateway)
module "external_alb" {
  source = "./modules/load_balancer"

  environment        = var.environment
  project_name       = var.project_name
  load_balancer_name = "${var.project_name}-external-alb-${var.environment}"
  internal           = false

  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.public_subnet_ids
  security_group_ids = [module.vpc.alb_public_security_group_id]

  target_group_name = "${var.project_name}-external-tg-${var.environment}"
  target_group_port = 3000
  target_type       = "ip"
  health_check_path = "/health"

  enable_https    = var.enable_https
  certificate_arn = var.certificate_arn

  depends_on = [module.vpc]
}

# Internal ALB (Internal traffic from External ALB)
module "internal_alb" {
  source = "./modules/load_balancer"

  environment        = var.environment
  project_name       = var.project_name
  load_balancer_name = "${var.project_name}-internal-alb-${var.environment}"
  internal           = true

  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.alb_internal_security_group_id]

  target_group_name = "${var.project_name}-internal-tg-${var.environment}"
  target_group_port = 8080
  target_type       = "ip"
  health_check_path = "/health"

  enable_https = false

  depends_on = [module.vpc]
}

# S3 Module (Landing, Raw, Processed zones)
module "s3_buckets" {
  source = "./modules/s3"

  environment  = var.environment
  project_name = var.project_name
}

# OpenSearch Serverless Module (with standby replicas)
module "opensearch" {
  source = "./modules/opensearch"

  environment  = var.environment
  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnet_ids

  # Allow both ingestion and backend ECS services
  ingestion_service_security_group_id = module.vpc.ecs_ingestion_security_group_id
  backend_service_security_group_id   = module.vpc.ecs_backend_security_group_id

  # depends_on = [module.ecs_ingestion, module.ecs_backend]
}

# OpenSearch Access Policy (Defined here to avoid circular dependency with ECS)
resource "aws_opensearchserverless_access_policy" "main" {
  name        = "${var.project_name}-access-${var.environment}"
  type        = "data"
  description = "Access policy for OpenSearch Serverless"
  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection",
          Resource = [
            "collection/${module.opensearch.collection_name}"
          ],
          Permission = [
            "aoss:CreateCollectionItems",
            "aoss:DeleteCollectionItems",
            "aoss:UpdateCollectionItems",
            "aoss:DescribeCollectionItems"
          ]
        },
        {
          ResourceType = "index",
          Resource = [
            "index/${module.opensearch.collection_name}/*"
          ],
          Permission = [
            "aoss:CreateIndex",
            "aoss:DeleteIndex",
            "aoss:UpdateIndex",
            "aoss:DescribeIndex",
            "aoss:ReadDocument",
            "aoss:WriteDocument"
          ]
        }
      ],
      Principal = [
        module.ecs_ingestion.task_role_arn,
        module.ecs_backend.task_role_arn,
        data.aws_caller_identity.current.arn
      ]
    }
  ])
}

data "aws_caller_identity" "current" {}
