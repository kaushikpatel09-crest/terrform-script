# Complete File Structure

## Full Project Directory Tree

```
conde-nast/
│
├── 📚 DOCUMENTATION
│   ├── 🚀 PROJECT_DELIVERY.md .................. Project summary and what's included
│   ├── 📖 INDEX.md ............................. Navigation guide for all files
│   ├── ⚡ QUICKSTART.md ........................ Quick overview (START HERE)
│   ├── 📋 README.md ............................ Complete reference documentation
│   ├── 🚢 DEPLOYMENT_GUIDE.md .................. Step-by-step deployment instructions
│   ├── 🏗️ ARCHITECTURE.md ..................... Infrastructure diagrams and design
│   ├── 🔧 MODULES.md .......................... Detailed module documentation
│   ├── 🔐 GITHUB_ACTIONS_SETUP.md ............. CI/CD pipeline configuration
│   ├── 🔄 GITHUB_PIPELINE_SETUP.md ............ Pipeline setup instructions
│   ├── 🖼️ GITHUB_PIPELINE_VISUAL.md .......... Visual pipeline reference
│   ├── 📦 GITHUB_PIPELINE_COMPLETE_SETUP.md ... Full pipeline with all stages
│   ├── ⚡ PIPELINE_QUICK_SETUP.md ............. Quick pipeline reference
│   ├── 🔑 OIDC_TROUBLESHOOTING.md ............. OIDC auth troubleshooting guide
│   └── 📦 DEPLOYMENT_APPLICATIONS.md .......... Application deployment notes
│
├── ⚙️ TERRAFORM CONFIGURATION (terraform/)
│   │
│   ├── ROOT MODULE
│   │   ├── main.tf ............................ Orchestrates all modules
│   │   ├── variables.tf ....................... Input variables and validation
│   │   └── outputs.tf ......................... Output values for all resources
│   │
│   ├── 🌍 ENVIRONMENTS (terraform/environments/)
│   │   ├── dev.tfvars ......................... Development environment config
│   │   └── stage.tfvars ....................... Stage environment config
│   │
│   └── 📦 MODULES (terraform/modules/)
│       │
│       ├── VPC MODULE (vpc/)
│       │   ├── main.tf ........................ VPC, subnets, NAT, IGW, security groups, flow logs
│       │   ├── variables.tf .................. Input variables
│       │   └── outputs.tf ..................... VPC ID, subnet IDs, security group IDs
│       │
│       ├── ECS MODULE (ecs/)
│       │   ├── main.tf ........................ Cluster (optional), task definition, service, autoscaling
│       │   ├── iam.tf ......................... All IAM roles and policies (execution + task roles)
│       │   ├── variables.tf .................. Input variables (incl. create_cluster, container_secrets)
│       │   └── outputs.tf ..................... Cluster name/ARN, service name/ARN, task def ARN
│       │
│       ├── SECRETS MODULE (secrets/)
│       │   ├── main.tf ........................ Secrets Manager secret + secret version
│       │   ├── variables.tf .................. secret_name, secret_string, recovery_window_in_days
│       │   └── outputs.tf ..................... secret_arn, secret_id, secret_name
│       │
│       ├── S3 MODULE (s3/)
│       │   ├── main.tf ........................ S3 buckets: processed, image-search
│       │   ├── variables.tf .................. Input variables
│       │   └── outputs.tf ..................... Bucket names and ARNs
│       │
│       ├── SQS MODULE (sqs/)
│       │   ├── main.tf ........................ SQS queue (landing-events)
│       │   ├── variables.tf .................. Input variables
│       │   └── outputs.tf ..................... queue_arn, queue_url
│       │
│       ├── DOCUMENTDB MODULE (documentdb/)
│       │   ├── main.tf ........................ DocumentDB cluster, subnet group, instances
│       │   ├── variables.tf .................. Input variables
│       │   └── outputs.tf ..................... cluster_endpoint, documentdb_uri (sensitive)
│       │
│       ├── ECR MODULE (ecr/)
│       │   ├── main.tf ........................ ECR repository
│       │   ├── variables.tf .................. Input variables
│       │   └── outputs.tf ..................... repository_url, repository_arn
│       │
│       ├── LOAD BALANCER MODULE (load_balancer/)
│       │   ├── main.tf ........................ ALB, target group, listeners
│       │   ├── variables.tf .................. Input variables
│       │   └── outputs.tf ..................... load_balancer_dns_name, target_group_arn
│       │
│       └── OPENSEARCH MODULE (opensearch/)
│           ├── main.tf ........................ OpenSearch Serverless collection + access policies
│           ├── variables.tf .................. Input variables
│           └── outputs.tf ..................... collection_endpoint, collection_arn
│
└── 🔗 CI/CD CONFIGURATION (.github/)
    └── WORKFLOWS (.github/workflows/)
        ├── terraform.yml ..................... Main Terraform plan/apply/destroy workflow
        └── terraform-validate.yml ........... Validation and security scanning
```

---

## Module Count Summary

```
Terraform Modules:
├── vpc            3 files (main, variables, outputs)
├── ecs            4 files (main, iam, variables, outputs)   ← iam.tf added
├── secrets        3 files (main, variables, outputs)        ← NEW module
├── s3             3 files (main, variables, outputs)
├── sqs            3 files (main, variables, outputs)
├── documentdb     3 files (main, variables, outputs)
├── ecr            3 files (main, variables, outputs)
├── load_balancer  3 files (main, variables, outputs)
└── opensearch     3 files (main, variables, outputs)
─────────────────────────────────────────
MODULES TOTAL:    28 files across 9 modules
```

---

## ECS Cluster Layout

| Cluster Name | Services | Module Call |
|---|---|---|
| `<project>-app-<env>` | Frontend (`fe`) + Backend (`be`) | `ecs_frontend` creates, `ecs_backend` joins |
| `<project>-ingestion-<env>` | Ingestion (`ingestion`) | `ecs_ingestion` creates standalone |

---

## Task Definition Naming Convention

```
<project_name>-<service_name>-task-definition-<environment>

Examples:
  conde-nast-fe-task-definition-dev
  conde-nast-be-task-definition-dev
  conde-nast-ingestion-task-definition-dev
```

---

## Secrets Management

| Secret | Module | Used By (via container_secrets) |
|--------|--------|---------------------------------|
| `<project>-documentdb-url-<env>` | `secrets_docdb` | BE, Ingestion |

Secrets are injected at **container startup** via the ECS `secrets` block — never as plain-text environment variables. The ECS Task Execution Role is automatically granted `secretsmanager:GetSecretValue`.

---

## S3 Bucket Access Matrix

| Service | processed bucket | image-search bucket |
|---------|-----------------|---------------------|
| Backend (`be`) | ✅ Read/Write | ✅ Read/Write |
| Ingestion | ✅ Read/Write | ✗ |
| Frontend (`fe`) | ✗ | ✗ |

---

## AWS Resources Created (All Modules)

### VPC Module — ~21 resources
- VPC, IGW, Elastic IP, NAT GW, 1 public + 3 private subnets
- 2 route tables, 4 route table associations
- 5 security groups (ALB public, ALB internal, FE ECS, BE ECS, Ingestion ECS, DocumentDB)
- CloudWatch log group + VPC flow logs + IAM role

### ECS Module — per instance
- CloudWatch Log Group (1)
- ECS Cluster (0–1, `create_cluster` flag)
- ECS Capacity Provider (0–1)
- Task Definition (1)
- ECS Service (1)
- App Auto Scaling Target (1)
- Auto Scaling Policies (2)
- IAM Task Execution Role (1) + policies (2–3)
- IAM Task Role (1) + policies (0–4, conditional)

> **3 ECS module calls**: 2 for app cluster (FE creates, BE joins) + 1 for ingestion cluster

### Secrets Module — per instance
- Secrets Manager Secret (1)
- Secret Version (1)

> **1 instance**: `secrets_docdb`

### S3 Module
- S3 Buckets × 2 (processed, image-search)
- Versioning, encryption, public-access-block per bucket

### SQS Module
- SQS Queue (1): `landing-events`

### DocumentDB Module
- Subnet Group, Cluster, Parameter Group, Instances (1–3), CloudWatch Log Group

### ECR Module — 3 repositories
- `frontend`, `backend`, `ingestion`

### Load Balancer Module — 2 ALBs
- External ALB (public) + Internal ALB (private)
- Target groups, listeners per ALB

### OpenSearch Module
- Serverless collection + access policies

---

## Module Dependencies Graph

```
VPC  ──────────────────────────────────────────────────────────┐
 │                                                             │
 ├──→ ECR (frontend, backend, ingestion)                       │
 │                                                             │
 ├──→ External ALB ──→ ECS Frontend (creates app cluster)      │
 │         └──────────→ ECS Backend  (joins  app cluster) ←───┘
 │
 ├──→ Internal ALB ──→ ECS Backend (above)
 │
 ├──→ ECS Ingestion (creates ingestion cluster)
 │        └──→ SQS Module
 │
 ├──→ DocumentDB ──→ Secrets Module (secrets_docdb)
 │                       │
 │           ┌───────────┴───────────┐
 │           ▼                       ▼
 │     ECS Backend             ECS Ingestion
 │    (container_secrets)    (container_secrets)
 │
 ├──→ S3 Module (processed + image-search)
 │       ├──→ ECS Backend  (processed + image-search)
 │       └──→ ECS Ingestion (processed only)
 │
 └──→ OpenSearch Module
         ├──→ ECS Backend  (collection_arn + endpoint)
         └──→ ECS Ingestion (collection_arn + endpoint)
```

---

## Implementation Highlights

✅ **Shared ECS Cluster** — FE and BE share one cluster; Ingestion is isolated
✅ **Secure Secrets** — DocumentDB URI stored in Secrets Manager, never in plain-text env vars
✅ **IAM Separation** — All IAM resources live in `iam.tf` for clean readability
✅ **Conditional Cluster Creation** — `create_cluster` flag avoids duplicating cluster resources
✅ **Least-Privilege IAM** — Each service only gets the permissions it needs
✅ **Unique Task Definitions** — Named with `task-definition-<env>` suffix to avoid cross-environment conflicts
✅ **Modular S3 Access** — Each service gets only its required bucket ARNs
✅ **Environment Parity** — All modules parameterized for dev/stage via `.tfvars` files

---

**File Structure Version**: 2.0
**Last Updated**: February 2026
