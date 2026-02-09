environment = "qa"
aws_region  = "us-east-1"

# VPC Configuration
vpc_cidr             = "10.1.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs  = ["10.1.1.0/24"]
private_subnet_cidrs = ["10.1.10.0/24", "10.1.20.0/24", "10.1.30.0/24"]

# ECS Frontend Configuration
frontend_image         = "nginx"
frontend_image_tag     = "latest"
frontend_task_cpu      = 512
frontend_task_memory   = 1024
frontend_desired_count = 2
frontend_min_capacity  = 2
frontend_max_capacity  = 4

# ECS Backend Configuration
backend_image         = "node"
backend_image_tag     = "18-alpine"
backend_task_cpu      = 512
backend_task_memory   = 1024
backend_desired_count = 2
backend_min_capacity  = 2
backend_max_capacity  = 4

# DocumentDB Configuration
documentdb_engine_version        = "4.0.0"
documentdb_master_username       = "admin"
documentdb_backup_retention_days = 14
documentdb_num_instances         = 2
documentdb_instance_class        = "db.t3.medium"
documentdb_skip_final_snapshot   = true

# Load Balancer Configuration
enable_https    = false
certificate_arn = ""
