# Module Documentation

## VPC Module (`terraform/modules/vpc`)

### Purpose
Creates a complete VPC infrastructure with networking, subnets, NAT gateway, and security groups.

### Resources Created
- VPC (1)
- Internet Gateway (1)
- Public Subnet (1)
- Private Subnets (3)
- Elastic IP for NAT (1)
- NAT Gateway (1)
- Route Tables (2)
- Route Table Associations (4)
- Security Groups (4)
- CloudWatch Log Group (1)
- VPC Flow Logs (1)
- IAM Role for VPC Flow Logs (1)

### Input Variables

| Variable | Type | Description | Required |
|----------|------|-------------|----------|
| environment | string | Environment name (dev/qa/stage) | Yes |
| project_name | string | Project name | Yes |
| vpc_cidr | string | VPC CIDR block | Yes |
| availability_zones | list(string) | List of AZs | Yes |
| public_subnet_cidrs | list(string) | Public subnet CIDR blocks | Yes |
| private_subnet_cidrs | list(string) | Private subnet CIDR blocks (must be 3) | Yes |

### Outputs

| Output | Description |
|--------|-------------|
| vpc_id | VPC identifier |
| vpc_cidr | VPC CIDR block |
| public_subnet_id | Public subnet ID |
| private_subnet_ids | List of private subnet IDs |
| nat_gateway_id | NAT Gateway ID |
| nat_gateway_public_ip | NAT Gateway Elastic IP |
| alb_public_security_group_id | Public ALB security group ID |
| alb_internal_security_group_id | Internal ALB security group ID |
| ecs_security_group_id | ECS security group ID |
| documentdb_security_group_id | DocumentDB security group ID |

### Example Usage

```hcl
module "vpc" {
  source = "./modules/vpc"

  environment            = "dev"
  project_name           = "conde-nast"
  vpc_cidr               = "10.0.0.0/16"
  availability_zones     = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnet_cidrs    = ["10.0.1.0/24"]
  private_subnet_cidrs   = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]
}
```

---

## ECS Module (`terraform/modules/ecs`)

### Purpose
Creates ECS cluster with Fargate services, task definitions, auto-scaling, and CloudWatch logging.

### Resources Created
- CloudWatch Log Group (1)
- ECS Cluster (1)
- ECS Cluster Capacity Providers (1)
- ECS Task Definition (1)
- ECS Service (1)
- App Auto Scaling Target (1)
- Auto Scaling Policies (2)
- IAM Role for Task Execution (1)
- IAM Role for Task (1)
- IAM Role Policies (2)

### Input Variables

| Variable | Type | Description | Required |
|----------|------|-------------|----------|
| environment | string | Environment name | Yes |
| project_name | string | Project name | Yes |
| cluster_name | string | ECS cluster name | Yes |
| service_name | string | ECS service name | Yes |
| container_name | string | Container name | Yes |
| container_port | number | Container port | Yes |
| container_image | string | Container image URL | Yes |
| container_image_tag | string | Container image tag | No (default: latest) |
| task_cpu | number | Task CPU (256, 512, 1024, 2048, 4096) | Yes |
| task_memory | number | Task memory in MB | Yes |
| desired_count | number | Desired number of tasks | Yes |
| min_capacity | number | Minimum capacity for auto-scaling | Yes |
| max_capacity | number | Maximum capacity for auto-scaling | Yes |
| vpc_id | string | VPC ID | Yes |
| subnet_ids | list(string) | Subnet IDs for placement | Yes |
| security_group_ids | list(string) | Security group IDs | Yes |
| load_balancer_target_group_arn | string | Target group ARN for load balancer | Yes |
| log_group_name | string | CloudWatch log group name | Yes |

### Outputs

| Output | Description |
|--------|-------------|
| cluster_name | ECS cluster name |
| cluster_arn | ECS cluster ARN |
| service_name | ECS service name |
| service_arn | ECS service ARN |
| task_definition_arn | ECS task definition ARN |

### Example Usage

```hcl
module "ecs_frontend" {
  source = "./modules/ecs"

  environment           = "dev"
  project_name          = "conde-nast"
  cluster_name          = "conde-nast-fe-dev"
  service_name          = "conde-nast-fe-service"
  container_name        = "frontend"
  container_port        = 3000
  container_image       = "nginx"
  container_image_tag   = "latest"
  task_cpu              = 256
  task_memory           = 512
  desired_count         = 1
  min_capacity          = 1
  max_capacity          = 2
  
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = [module.vpc.private_subnet_ids[0]]
  security_group_ids    = [module.vpc.ecs_security_group_id]
  
  load_balancer_target_group_arn = module.internal_alb.target_group_arn
  log_group_name        = "/ecs/conde-nast-fe-dev"
}
```

### Auto Scaling
- **CPU Policy**: Target 70% utilization
- **Memory Policy**: Target 80% utilization
- **Min Tasks**: Environment-specific
- **Max Tasks**: Environment-specific

---

## Load Balancer Module (`terraform/modules/load_balancer`)

### Purpose
Creates Application Load Balancer (ALB) with target groups, listeners, and health checks.

### Resources Created
- Application Load Balancer (1)
- Target Group (1)
- HTTP Listener (1)
- HTTPS Listener (0-1, optional)
- Listener Rules (0-1, optional for HTTP to HTTPS redirect)

### Input Variables

| Variable | Type | Description | Required |
|----------|------|-------------|----------|
| environment | string | Environment name | Yes |
| project_name | string | Project name | Yes |
| load_balancer_name | string | Load balancer name | Yes |
| internal | bool | Whether ALB is internal | No (default: false) |
| vpc_id | string | VPC ID | Yes |
| subnet_ids | list(string) | Subnet IDs for ALB placement | Yes |
| security_group_ids | list(string) | Security group IDs | Yes |
| target_group_name | string | Target group name | Yes |
| target_group_port | number | Target group port | No (default: 80) |
| target_type | string | Target type (instance, ip, lambda) | No (default: ip) |
| health_check_path | string | Health check path | No (default: /) |
| enable_https | bool | Enable HTTPS | No (default: false) |
| certificate_arn | string | ACM certificate ARN for HTTPS | No (default: "") |

### Outputs

| Output | Description |
|--------|-------------|
| load_balancer_id | Load balancer ID |
| load_balancer_arn | Load balancer ARN |
| load_balancer_dns_name | Load balancer DNS name |
| target_group_arn | Target group ARN |
| target_group_id | Target group ID |

### Example Usage

```hcl
module "external_alb" {
  source = "./modules/load_balancer"

  environment          = "dev"
  project_name         = "conde-nast"
  load_balancer_name   = "conde-nast-external-alb-dev"
  internal             = false
  
  vpc_id               = module.vpc.vpc_id
  subnet_ids           = [module.vpc.public_subnet_id]
  security_group_ids   = [module.vpc.alb_public_security_group_id]
  
  target_group_name    = "conde-nast-external-tg-dev"
  target_group_port    = 80
  target_type          = "ip"
  health_check_path    = "/"
  
  enable_https         = false
  certificate_arn      = ""
}
```

### Health Checks
- **Healthy Threshold**: 2 consecutive checks
- **Unhealthy Threshold**: 2 consecutive checks
- **Timeout**: 3 seconds
- **Interval**: 30 seconds
- **Path**: `/` (configurable)
- **Matcher**: 200 (HTTP status code)

---

## DocumentDB Module (`terraform/modules/documentdb`)

### Purpose
Creates DocumentDB cluster (MongoDB-compatible) with encryption, backups, and monitoring.

### Resources Created
- DocumentDB Subnet Group (1)
- DocumentDB Cluster (1)
- DocumentDB Cluster Parameter Group (1)
- DocumentDB Cluster Instances (1-3)
- CloudWatch Log Group (1)

### Input Variables

| Variable | Type | Description | Required |
|----------|------|-------------|----------|
| environment | string | Environment name | Yes |
| project_name | string | Project name | Yes |
| cluster_identifier | string | Cluster identifier | Yes |
| engine_version | string | DocumentDB engine version | No (default: 4.0.0) |
| master_username | string | Master username | Yes (sensitive) |
| master_password | string | Master password (min 8 chars) | Yes (sensitive) |
| backup_retention_days | number | Backup retention days (1-35) | No (default: 7) |
| num_instances | number | Number of instances (1-15) | No (default: 1) |
| instance_class | string | Instance class | No (default: db.t3.medium) |
| vpc_id | string | VPC ID | Yes |
| subnet_ids | list(string) | Subnet IDs for cluster | Yes |
| security_group_ids | list(string) | Security group IDs | Yes |
| skip_final_snapshot | bool | Skip final snapshot on deletion | No (default: false) |

### Outputs

| Output | Description |
|--------|-------------|
| cluster_id | DocumentDB cluster ID |
| cluster_arn | DocumentDB cluster ARN |
| cluster_endpoint | DocumentDB cluster endpoint (sensitive) |
| reader_endpoint | DocumentDB reader endpoint (sensitive) |
| port | DocumentDB port (27017) |
| master_username | Master username (sensitive) |

### Example Usage

```hcl
module "documentdb" {
  source = "./modules/documentdb"

  environment            = "dev"
  project_name           = "conde-nast"
  cluster_identifier     = "conde-nast-docdb-dev"
  engine_version         = "4.0.0"
  master_username        = "admin"
  master_password        = var.documentdb_master_password
  backup_retention_days  = 7
  num_instances          = 1
  instance_class         = "db.t3.small"
  
  vpc_id                 = module.vpc.vpc_id
  subnet_ids             = [module.vpc.private_subnet_ids[2]]
  security_group_ids     = [module.vpc.documentdb_security_group_id]
  
  skip_final_snapshot    = true
}
```

### Connection String
```
mongodb://username:password@cluster-endpoint:27017/?ssl=true&replicaSet=rs0&authSource=admin
```

### Features
- **Encryption**: Storage encryption enabled
- **TLS**: Enabled for connections
- **Backups**: Automated daily backups
- **Logs**: Audit, error, general, slowquery logs
- **Multi-Instance**: Replication across instances

---

## Module Integration Flow

```
Root Module (main.tf)
├── VPC Module
│   ├── Creates VPC (10.x.0.0/16)
│   ├── Creates 1 public subnet
│   ├── Creates 3 private subnets
│   ├── Creates NAT Gateway
│   └── Creates Security Groups
├── ECS Frontend Module
│   ├── Uses VPC
│   ├── Uses ECS Security Group
│   ├── Uses Private Subnet 1
│   └── Uses Internal ALB Target Group
├── ECS Backend Module
│   ├── Uses VPC
│   ├── Uses ECS Security Group
│   ├── Uses Private Subnet 2
│   └── Uses Internal ALB Target Group
├── DocumentDB Module
│   ├── Uses VPC
│   ├── Uses DocumentDB Security Group
│   └── Uses Private Subnet 3
├── External ALB Module
│   ├── Uses VPC
│   ├── Uses Public ALB Security Group
│   └── Uses Public Subnet
└── Internal ALB Module
    ├── Uses VPC
    ├── Uses Internal ALB Security Group
    ├── Uses All Private Subnets
    └── Routes to ECS Services
```

## Module Dependencies

```
VPC Module (no dependencies)
│
├─→ External ALB Module (depends on VPC)
│   │
│   └─→ Internal ALB Module (depends on VPC + External ALB)
│       │
│       ├─→ ECS Frontend (depends on VPC + Internal ALB)
│       │
│       └─→ ECS Backend (depends on VPC + Internal ALB)
│
└─→ DocumentDB Module (depends on VPC)
```

## Variable Validation

### VPC Module
- `private_subnet_cidrs` must have exactly 3 elements

### DocumentDB Module
- `master_password` must be at least 8 characters
- `backup_retention_days` must be between 1 and 35
- `num_instances` must be between 1 and 15

### Root Module
- `environment` must be one of: dev, qa, stage

## Common Patterns

### Deploying New Environment
1. Copy environment tfvars file
2. Update CIDR blocks
3. Update resource counts and sizes
4. Run terraform plan/apply

### Adding New ECS Service
1. Create new ECS module call
2. Configure cluster name and container port
3. Assign to appropriate subnet
4. Add to load balancer target group
5. Configure auto-scaling parameters

### Scaling Resources
1. Edit environment tfvars
2. Update task counts and sizes
3. Update database instances
4. Run terraform plan/apply

---

**Module Documentation Version**: 1.0
**Last Updated**: February 6, 2026
