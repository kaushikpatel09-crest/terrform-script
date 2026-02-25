# Module Documentation

---

## VPC Module (`terraform/modules/vpc`)

### Purpose
Creates a complete VPC infrastructure with networking, subnets, NAT gateway, security groups, and flow logs.

### Resources Created
- VPC (1)
- Internet Gateway (1)
- Public Subnet (1)
- Private Subnets (3)
- Elastic IP for NAT (1)
- NAT Gateway (1)
- Route Tables (2)
- Route Table Associations (4)
- Security Groups (5): ALB Public, ALB Internal, ECS Frontend, ECS Backend, ECS Ingestion, DocumentDB
- CloudWatch Log Group (1)
- VPC Flow Logs (1)
- IAM Role for VPC Flow Logs (1)

### Input Variables

| Variable | Type | Description | Required |
|----------|------|-------------|----------|
| environment | string | Environment name (dev/stage) | Yes |
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
| public_subnet_ids | Public subnet IDs |
| private_subnet_ids | List of private subnet IDs |
| nat_gateway_id | NAT Gateway ID |
| alb_public_security_group_id | Public ALB security group ID |
| alb_internal_security_group_id | Internal ALB security group ID |
| ecs_frontend_security_group_id | Frontend ECS security group ID |
| ecs_backend_security_group_id | Backend ECS security group ID |
| ecs_ingestion_security_group_id | Ingestion ECS security group ID |
| documentdb_security_group_id | DocumentDB security group ID |

---

## ECS Module (`terraform/modules/ecs`)

### Purpose
Creates an ECS Fargate service, task definition, auto-scaling, CloudWatch logging, and all required IAM roles/policies. Supports optionally joining an existing cluster rather than creating a new one.

### File Structure

| File | Responsibility |
|------|---------------|
| `main.tf` | ECS cluster (optional), task definition, service, auto-scaling, data sources |
| `iam.tf` | All IAM roles and inline policies (execution role + task role) |
| `variables.tf` | All input variables with defaults |
| `outputs.tf` | Cluster name/ARN, service name/ARN, task definition ARN |

### Resources Created

| Resource | Count | Notes |
|----------|-------|-------|
| CloudWatch Log Group | 1 | Per service |
| ECS Cluster | 0–1 | Controlled by `create_cluster` variable |
| ECS Cluster Capacity Providers | 0–1 | Created only when `create_cluster = true` |
| ECS Task Definition | 1 | Named `<project>-<service>-task-definition-<env>` |
| ECS Service | 1 | Fargate launch type |
| App Auto Scaling Target | 1 | |
| Auto Scaling Policies | 2 | CPU (70%) and Memory (80%) targets |
| IAM Task Execution Role | 1 | Used by ECS control plane |
| IAM Task Role | 1 | Used by the application container |
| IAM Role Policies | 2–6 | ECR pull, Secrets, Bedrock, S3, SQS, OpenSearch (conditional) |

### Input Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| environment | string | — | Environment name |
| project_name | string | — | Project name |
| cluster_name | string | — | ECS cluster name |
| create_cluster | bool | true | Whether to create a new cluster or join an existing one |
| service_name | string | — | Short service identifier (e.g. `fe`, `be`, `ingestion`) |
| container_name | string | — | Container name inside the task definition |
| container_port | number | — | Port the container listens on |
| container_image | string | — | ECR repository URL |
| container_image_tag | string | `latest` | Container image tag |
| task_cpu | number | — | vCPU units (256, 512, 1024, 2048, 4096) |
| task_memory | number | — | Memory in MB |
| desired_count | number | — | Initial desired task count |
| min_capacity | number | — | Auto-scaling minimum |
| max_capacity | number | — | Auto-scaling maximum |
| vpc_id | string | — | VPC ID |
| subnet_ids | list(string) | — | Private subnet IDs |
| security_group_ids | list(string) | — | Security group IDs |
| log_group_name | string | — | CloudWatch log group name |
| ecr_repository_arn | string | — | ECR repo ARN for image pull policy |
| load_balancer_target_group_arn | string | `""` | Target group ARN (omit for ingestion) |
| environment_variables | map(string) | `{}` | Plain-text environment variables |
| container_secrets | map(string) | `{}` | Secrets Manager ARN map injected securely at runtime |
| bedrock_model_arn | string | `""` | Bedrock model ARN (enables Bedrock policy) |
| enable_s3_access | bool | false | Enable S3 access policy |
| s3_bucket_arns | list(string) | `[]` | S3 bucket ARNs to grant access to |
| enable_sqs_access | bool | false | Enable SQS access policy |
| sqs_queue_arn | string | `""` | SQS queue ARN |
| enable_ecs_opensearch_access | bool | false | Enable OpenSearch Serverless access policy |
| opensearch_collection_arn | string | `""` | OpenSearch collection ARN |

### Outputs

| Output | Description |
|--------|-------------|
| cluster_name | ECS cluster name |
| cluster_arn | ECS cluster ARN |
| service_name | ECS service name |
| service_arn | ECS service ARN |
| task_definition_arn | Current active task definition ARN |

### Cluster Architecture

```
module "ecs_frontend"   → creates  conde-nast-app-<env>  cluster (create_cluster = true)
module "ecs_backend"    → joins    conde-nast-app-<env>  cluster (create_cluster = false)
module "ecs_ingestion"  → creates  conde-nast-ingestion-<env> cluster (create_cluster = true)
```

### IAM Policy Matrix (per service)

| Policy | FE | BE | Ingestion |
|--------|----|----|-----------|
| ECS Managed Execution Policy | ✅ | ✅ | ✅ |
| ECR Image Pull | ✅ | ✅ | ✅ |
| Secrets Manager Read | ✅ | ✅ | ✅ |
| Bedrock Invoke | ✗ | ✅ | ✅ |
| S3 Access | ✗ | ✅ | ✅ |
| SQS Access | ✗ | ✗ | ✅ |
| OpenSearch Access | ✗ | ✅ | ✅ |

### Auto Scaling
- **CPU Policy**: Target 70% utilization
- **Memory Policy**: Target 80% utilization
- Scale range: `min_capacity` → `max_capacity`

### Example Usage — Shared Cluster (BE joins FE's cluster)

```hcl
module "ecs_frontend" {
  source         = "./modules/ecs"
  cluster_name   = "conde-nast-app-dev"
  create_cluster = true
  service_name   = "fe"
  container_port = 3000
  # ...
}

module "ecs_backend" {
  source         = "./modules/ecs"
  cluster_name   = "conde-nast-app-dev"
  create_cluster = false          # joins existing cluster
  service_name   = "be"
  container_port = 8080

  container_secrets = {
    DOCUMENTDB_URI = module.secrets_docdb.secret_arn
  }

  enable_s3_access = true
  s3_bucket_arns   = [
    module.s3_buckets.processed_bucket_arn,
    module.s3_buckets.image_search_bucket_arn
  ]
  # ...
  depends_on = [module.ecs_frontend]
}
```

---

## Secrets Module (`terraform/modules/secrets`)

### Purpose
Creates an AWS Secrets Manager secret and stores a secret string value. Designed to be generic and reusable for any secret in the project.

### Resources Created
- `aws_secretsmanager_secret` (1)
- `aws_secretsmanager_secret_version` (1)

### Input Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| environment | string | — | Environment name |
| project_name | string | — | Project name |
| secret_name | string | — | Full name of the secret |
| secret_description | string | `""` | Human-readable description |
| secret_string | string | — | Secret value (sensitive) |
| recovery_window_in_days | number | `7` | Days before secret can be permanently deleted (0 = immediate) |

### Outputs

| Output | Description |
|--------|-------------|
| secret_arn | Secret ARN (used to grant IAM access and reference from ECS) |
| secret_id | Secret ID |
| secret_name | Secret name |

### Example Usage

```hcl
module "secrets_docdb" {
  source = "./modules/secrets"

  environment             = var.environment
  project_name            = var.project_name
  secret_name             = "${var.project_name}-documentdb-url-${var.environment}"
  secret_description      = "DocumentDB connection URI"
  secret_string           = module.documentdb.documentdb_uri
  recovery_window_in_days = 7

  depends_on = [module.documentdb]
}
```

> **Note**: AWS enforces a recovery window on secrets. If a secret with the same name is stuck in "scheduled for deletion" state, either set `recovery_window_in_days = 0` (development only) or use a different name (e.g. append a version suffix).

---

## S3 Module (`terraform/modules/s3`)

### Purpose
Creates S3 buckets for the data pipeline. Currently manages two zones:
- **Processed** zone — cleaned and processed content
- **Image-search** zone — images used for visual search

### Resources Created (per bucket)
- S3 Bucket (2)
- S3 Bucket Versioning (2)
- S3 Server-Side Encryption (2)
- S3 Public Access Block (2)

### Outputs

| Output | Description |
|--------|-------------|
| processed_bucket_name | Processed bucket name |
| processed_bucket_arn | Processed bucket ARN |
| image_search_bucket_name | Image-search bucket name |
| image_search_bucket_arn | Image-search bucket ARN |

---

## DocumentDB Module (`terraform/modules/documentdb`)

### Purpose
Creates DocumentDB cluster (MongoDB-compatible) with encryption, automated backups, and audit logging.

### Resources Created
- DocumentDB Subnet Group (1)
- DocumentDB Cluster (1)
- DocumentDB Cluster Parameter Group (1)
- DocumentDB Cluster Instances (1–3)
- CloudWatch Log Group (1)

### Input Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| environment | string | — | Environment name |
| project_name | string | — | Project name |
| cluster_identifier | string | — | Cluster identifier |
| engine_version | string | `4.0.0` | DocumentDB engine version |
| master_username | string | — | Master username (sensitive) |
| master_password | string | — | Master password, min 8 chars (sensitive) |
| backup_retention_days | number | `7` | Backup retention days (1–35) |
| num_instances | number | `1` | Number of instances |
| instance_class | string | `db.t3.medium` | Instance class |
| vpc_id | string | — | VPC ID |
| subnet_ids | list(string) | — | Subnet IDs |
| security_group_ids | list(string) | — | Security group IDs |
| skip_final_snapshot | bool | `false` | Skip final snapshot on destroy |

### Outputs

| Output | Description |
|--------|-------------|
| cluster_id | Cluster identifier |
| cluster_arn | Cluster ARN |
| cluster_endpoint | Writer endpoint (sensitive) |
| reader_endpoint | Reader endpoint (sensitive) |
| port | Port (27017) |
| documentdb_uri | Full MongoDB connection URI (sensitive) — stored in Secrets Manager |

> **Security note**: `documentdb_uri` is passed directly to the `secrets_docdb` module and stored in AWS Secrets Manager. It is **never** set as a plain-text ECS environment variable.

---

## OpenSearch Module (`terraform/modules/opensearch`)

### Purpose
Creates an Amazon OpenSearch Serverless collection for vector search / semantic search capabilities.

### Key IAM Notes
- ECS BE and Ingestion services are granted `aoss:APIAccessAll` on the collection ARN via the ECS task role.
- The ECS task execution role principal must be added to the OpenSearch data access policy.

---

## SQS Module (`terraform/modules/sqs`)

### Purpose
Creates an SQS queue used to trigger the Ingestion service when new files are available in S3.

### Queue
- **Name**: `landing-events`
- **Access**: Ingestion ECS task role receives `sqs:ReceiveMessage`, `sqs:DeleteMessage`, `sqs:GetQueueAttributes`, `sqs:ChangeMessageVisibility`

---

## Load Balancer Module (`terraform/modules/load_balancer`)

### Purpose
Creates an Application Load Balancer with target group, HTTP listener, and optional HTTPS listener.

### Resources Created
- Application Load Balancer (1)
- Target Group (1)
- HTTP Listener (1)
- HTTPS Listener (0–1, optional)

### Input Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| environment | string | — | Environment name |
| project_name | string | — | Project name |
| load_balancer_name | string | — | ALB name |
| internal | bool | `false` | Internal or internet-facing |
| vpc_id | string | — | VPC ID |
| subnet_ids | list(string) | — | Subnet IDs |
| security_group_ids | list(string) | — | Security group IDs |
| target_group_name | string | — | Target group name |
| target_group_port | number | `80` | Target group port |
| target_type | string | `ip` | Target type |
| health_check_path | string | `/health` | Health check path |
| enable_https | bool | `false` | Enable HTTPS |
| certificate_arn | string | `""` | ACM certificate ARN |

### Outputs

| Output | Description |
|--------|-------------|
| load_balancer_dns_name | ALB DNS name |
| load_balancer_arn | ALB ARN |
| target_group_arn | Target group ARN |

---

## ECR Module (`terraform/modules/ecr`)

### Purpose
Creates ECR repositories for each container image.

| Repository | Used By |
|-----------|---------|
| `conde-nast-frontend-<env>` | FE ECS service |
| `conde-nast-backend-<env>` | BE ECS service |
| `conde-nast-ingestion-<env>` | Ingestion ECS service |

---

## Module Integration Flow

```
Root Module (main.tf)
├── VPC Module
│   ├── VPC, Subnets, NAT Gateway
│   └── Security Groups (per service)
│
├── ECR Modules (frontend, backend, ingestion)
│
├── External ALB Module (public)
│   └── Target Group → FE service (port 3000)
│
├── Internal ALB Module (private)
│   └── Target Group → BE service (port 8080)
│
├── ECS Frontend Module  ← creates app cluster
│   └── Service: fe  (port 3000)
│
├── ECS Backend Module   ← joins app cluster
│   └── Service: be  (port 8080)
│       ├── Bedrock, S3 (processed + image-search), OpenSearch
│       └── DOCUMENTDB_URI from Secrets Manager
│
├── ECS Ingestion Module ← creates ingestion cluster
│   └── Service: ingestion  (port 9001)
│       ├── SQS, S3 (processed only), OpenSearch, Bedrock
│       └── DOCUMENTDB_URI from Secrets Manager
│
├── DocumentDB Module
│   └── Writer endpoint → uri passed to Secrets Module
│
├── Secrets Module (secrets_docdb)
│   └── Stores DocumentDB URI in Secrets Manager
│       └── ARN referenced in ECS task definitions (be + ingestion)
│
├── S3 Module
│   └── Buckets: processed, image-search
│
├── SQS Module (sqs_landing)
│   └── Queue: landing-events
│
└── OpenSearch Module
    └── Collection endpoint → BE + Ingestion env vars
```

## Module Dependencies

```
VPC Module
├─→ External ALB  → ECS Frontend (create_cluster=true)
│                          │
│                  ECS Backend (create_cluster=false, depends_on=FE)
├─→ Internal ALB  → (above)
├─→ ECS Ingestion (create_cluster=true, own cluster)
├─→ DocumentDB    → Secrets Module (secrets_docdb)
│                          │
│                   referenced by BE + Ingestion ECS secrets
├─→ S3 Buckets    → referenced by BE (processed+image-search) + Ingestion (processed)
├─→ SQS           → referenced by Ingestion
└─→ OpenSearch    → referenced by BE + Ingestion
```

---

**Module Documentation Version**: 2.0
**Last Updated**: February 2026
