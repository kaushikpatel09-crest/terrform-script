environment = "dev"
aws_region  = "us-east-1"

# VPC Configuration
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]

# ECS Frontend Configuration
frontend_image_tag     = "latest"
frontend_task_cpu      = 256
frontend_task_memory   = 512
frontend_desired_count = 1
frontend_min_capacity  = 1
frontend_max_capacity  = 2
backend_base_url       = "" # Will be set via GitHub Actions environment variable

# ECS Backend Configuration
backend_image_tag     = "latest"
backend_task_cpu      = 256
backend_task_memory   = 512
backend_desired_count = 1
backend_min_capacity  = 1
backend_max_capacity  = 2
bedrock_model_id      = "us.twelvelabs.marengo-embed-3-0-v1:0" # Only the model ID - ARN is constructed dynamically by Terraform

# DocumentDB Configuration
documentdb_engine_version        = "8.0.0"
documentdb_master_username       = "masteruser"
documentdb_backup_retention_days = 7
documentdb_num_instances         = 1
documentdb_instance_class        = "db.t3.medium"
documentdb_skip_final_snapshot   = true

# ECS Ingestion Backend Service Configuration
ingestion_image_tag     = "latest"
ingestion_task_cpu      = 256
ingestion_task_memory   = 512
ingestion_desired_count = 1
ingestion_min_capacity  = 1
ingestion_max_capacity  = 2

# Load Balancer Configuration
enable_https    = false
certificate_arn = ""

# SQS Settings
ingestion_sqs_visibility_timeout = 300
ingestion_sqs_wait_time_seconds  = 20
ingestion_sqs_heartbeat_interval = 120
ingestion_sqs_max_messages       = 1

# Ingestion Settings
ingestion_concurrency           = 1
ingestion_index_name            = "video-index-dev"
ingestion_max_size_gb           = 6
ingestion_max_duration_minutes  = 240
ingestion_max_wait_time_seconds = 3600
ingestion_poll_interval_seconds = 30

# Buckets
#ingestion_processed_bucket = "conde-nast-landing-dev"
#ingestion_aws_bucket_owner = "943143228843"


opensearch_service    = "aoss"
opensearch_index_name = "video_clips_3_faiss_per_modality"
embedding_model_name  = "us.twelvelabs.marengo-embed-3-0-v1:0"
#s3_bucket_owner_id    = "943143228843"
#s3_bucket_name        = "conde-nast-image-search-dev"


db_name           = "video_search"
jobs_collection   = "video_ingestion_jobs"
errors_collection = "video_pipeline_errors"
search_collection = "video_search_logs"
