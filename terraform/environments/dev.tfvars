environment = "dev"
aws_region  = "us-east-1"

# VPC Configuration
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]

# ECS Frontend Configuration
frontend_image              = "943143228843.dkr.ecr.us-east-1.amazonaws.com/conde-nast-frontend-dev"
frontend_image_tag          = "latest"
frontend_task_cpu           = 256
frontend_task_memory        = 512
frontend_desired_count      = 1
frontend_min_capacity       = 1
frontend_max_capacity       = 2
frontend_ecr_repository_arn = "arn:aws:ecr:us-east-1:943143228843:repository/conde-nast-frontend" # Update with your ECR repo ARN

# ECS Backend Configuration
backend_image              = "943143228843.dkr.ecr.us-east-1.amazonaws.com/conde-nast-backend-dev"
backend_image_tag          = "latest"
backend_task_cpu           = 256
backend_task_memory        = 512
backend_desired_count      = 1
backend_min_capacity       = 1
backend_max_capacity       = 2
backend_ecr_repository_arn = "arn:aws:ecr:us-east-1:943143228843:repository/conde-nast-backend"                              # Update with your ECR repo ARN
bedrock_model_arn          = "arn:aws:bedrock:us-east-1:943143228843:inference-profile/us.twelvelabs.marengo-embed-3-0-v1:0" # Update with your Bedrock model ARN

# DocumentDB Configuration
documentdb_engine_version        = "4.0.0"
documentdb_master_username       = "masteruser"
documentdb_backup_retention_days = 7
documentdb_num_instances         = 1
documentdb_instance_class        = "db.t3.medium"
documentdb_skip_final_snapshot   = true

# ECS Ingestion Backend Service Configuration
ingestion_image         = "your-ingestion-image" # Update with your ingestion service image
ingestion_image_tag     = "latest"
ingestion_task_cpu      = 256
ingestion_task_memory   = 512
ingestion_desired_count = 1
ingestion_min_capacity  = 1
ingestion_max_capacity  = 2
ecr_repository_arn      = "arn:aws:ecr:us-east-1:943143228843:repository/your-repo" # Update with your ECR repo ARN

# Load Balancer Configuration
enable_https    = false
certificate_arn = ""
