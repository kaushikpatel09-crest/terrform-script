environment = "stage"
aws_region  = "us-east-1"

# VPC Configuration
vpc_cidr               = "10.2.0.0/16"
availability_zones     = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs    = ["10.2.1.0/24"]
private_subnet_cidrs   = ["10.2.10.0/24", "10.2.20.0/24", "10.2.30.0/24"]

# ECS Frontend Configuration
frontend_image          = "nginx"
frontend_image_tag      = "latest"
frontend_task_cpu       = 512
frontend_task_memory    = 1024
frontend_desired_count  = 2
frontend_min_capacity   = 2
frontend_max_capacity   = 6

# ECS Backend Configuration
backend_image          = "node"
backend_image_tag      = "18-alpine"
backend_task_cpu       = 512
backend_task_memory    = 1024
backend_desired_count  = 2
backend_min_capacity   = 2
backend_max_capacity   = 6

# DocumentDB Configuration
documentdb_engine_version          = "4.0.0"
documentdb_master_username         = "admin"
documentdb_backup_retention_days   = 30
documentdb_num_instances           = 3
documentdb_instance_class          = "db.t3.medium"
documentdb_skip_final_snapshot     = false

# Load Balancer Configuration
enable_https    = true
certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERTIFICATE_ID"  # Update with your certificate
