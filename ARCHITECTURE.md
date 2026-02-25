# Architecture Diagram

## Infrastructure Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           AWS ACCOUNT                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                    VPC (10.x.0.0/16)                                  │  │
│  │                                                                       │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐ │  │
│  │  │                PUBLIC SUBNET (10.x.1.0/24)                      │ │  │
│  │  │                                                                 │ │  │
│  │  │  ┌──────────────────────┐    ┌──────────────────┐              │ │  │
│  │  │  │  Internet Gateway    │◄──►│  NAT Gateway     │              │ │  │
│  │  │  │  (IGW)               │    │  (Elastic IP)    │              │ │  │
│  │  │  └──────────────────────┘    └──────────────────┘              │ │  │
│  │  │           │ (inbound)                  │ (outbound)             │ │  │
│  │  │           ▼                            ▼                        │ │  │
│  │  │  ┌──────────────────────────────────────────────────────────┐  │ │  │
│  │  │  │        EXTERNAL ALB (Public-facing)                       │  │ │  │
│  │  │  │  - Port 80 / 443 (HTTPS optional)                        │  │ │  │
│  │  │  │  - SG: Allow 0.0.0.0/0                                   │  │ │  │
│  │  │  └──────────────────────────────────────────────────────────┘  │ │  │
│  │  └──────────────────────────────────────────────────────────────────┘ │  │
│  │              │                                                         │  │
│  │  ┌───────────┼─────────────────────────────────────────────────────┐  │  │
│  │  │           ▼          PRIVATE SUBNETS                            │  │  │
│  │  │  ┌──────────────────────────────────────────────────────────┐   │  │  │
│  │  │  │        INTERNAL ALB (Private)                             │   │  │  │
│  │  │  │  - Port 80  |  SG: Allow from External ALB SG             │   │  │  │
│  │  │  └─────────────────────┬────────────────────────────────────┘   │  │  │
│  │  │                        │                                         │  │  │
│  │  │         ┌──────────────┴───────────────┐                        │  │  │
│  │  │         ▼                              ▼                         │  │  │
│  │  │  ┌──────────────────────┐   ┌──────────────────────┐            │  │  │
│  │  │  │ APP CLUSTER          │   │ INGESTION CLUSTER     │            │  │  │
│  │  │  │ (conde-nast-app-dev) │   │ (conde-nast-          │            │  │  │
│  │  │  │                      │   │  ingestion-dev)        │            │  │  │
│  │  │  │  ┌────────────────┐  │   │  ┌────────────────┐   │            │  │  │
│  │  │  │  │ FE Service     │  │   │  │ Ingestion Svc  │   │            │  │  │
│  │  │  │  │ Port: 3000     │  │   │  │ Port: 9001     │   │            │  │  │
│  │  │  │  └────────────────┘  │   │  └───────┬────────┘   │            │  │  │
│  │  │  │  ┌────────────────┐  │   │          │ SQS        │            │  │  │
│  │  │  │  │ BE Service     │  │   │          ▼             │            │  │  │
│  │  │  │  │ Port: 8080     │  │   │  ┌────────────────┐   │            │  │  │
│  │  │  │  │ + Bedrock      │  │   │  │  SQS Queue     │   │            │  │  │
│  │  │  │  │ + OpenSearch   │  │   │  │  landing-events│   │            │  │  │
│  │  │  │  │ + S3 Access    │  │   │  └────────────────┘   │            │  │  │
│  │  │  │  └────────────────┘  │   └──────────────────────┘            │  │  │
│  │  │  └──────────────────────┘                                        │  │  │
│  │  │                                                                   │  │  │
│  │  │  ┌──────────────────────────────────────────────────────────┐   │  │  │
│  │  │  │  AWS DocumentDB Cluster (Private Subnet 3)                │   │  │  │
│  │  │  │  Port: 27017  |  URI stored in Secrets Manager            │   │  │  │
│  │  │  └──────────────────────────────────────────────────────────┘   │  │  │
│  │  └─────────────────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  AWS Managed Services (outside VPC):                                        │
│  ├─ ECR Repositories  (frontend, backend, ingestion container images)       │
│  ├─ OpenSearch Serverless Collection                                         │
│  ├─ Secrets Manager  (DocumentDB URI)                                       │
│  ├─ S3 Buckets  (processed, image-search)                                   │
│  └─ Amazon Bedrock  (inference profile: BE service only)                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## ECS Cluster Design

| Cluster | Services | Access |
|---------|----------|--------|
| `conde-nast-app-<env>` | Frontend (port 3000) + Backend (port 8080) | FE via External ALB, BE via Internal ALB |
| `conde-nast-ingestion-<env>` | Ingestion (port 9001) | Internal only, no ALB |

> The FE and BE services **share a single ECS cluster** to reduce cluster overhead. The cluster is created by the `ecs_frontend` module call (`create_cluster = true`) and joined by the `ecs_backend` call (`create_cluster = false`).

---

## Traffic Flow

### External User → Frontend
1. **User** → HTTP/HTTPS → External ALB (public)
2. **External ALB** → routes to FE ECS Service (port 3000)
3. **FE container** → calls BE via `VITE_BE_BASE_URL` (Internal ALB DNS)

### External User → Backend (via FE)
1. **FE** → Internal ALB (private)
2. **Internal ALB** → BE ECS Service (port 8080)
3. **BE container** → queries DocumentDB, OpenSearch, S3, Bedrock as needed

### Ingestion Flow
1. **SQS queue** (`landing-events`) receives messages from the `processed` S3 bucket trigger
2. **Ingestion ECS** polls the queue and processes media files
3. Results written to OpenSearch, DocumentDB, and S3

### ECS → External Services (Outbound)
- All private subnet traffic that needs to reach the internet uses the **NAT Gateway**

---

## IAM Permission Model

### Task Execution Role (ECS control plane)
- `AmazonECSTaskExecutionRolePolicy` (AWS managed)
- ECR image pull permissions (`ecr:GetAuthorizationToken`, `ecr:BatchGetImage`, etc.)
- `secretsmanager:GetSecretValue` (to inject `DOCUMENTDB_URI` at container startup)

### Task Role (Container application)
Granted conditionally per service:

| Policy | FE | BE | Ingestion |
|--------|----|----|-----------|
| Bedrock Invoke | ✗ | ✅ | ✅ |
| S3 Access | ✗ | ✅ (processed + image-search) | ✅ (processed only) |
| SQS Access | ✗ | ✗ | ✅ |
| OpenSearch Access | ✗ | ✅ | ✅ |

---

## Task Definition Naming

Task definitions are uniquely named per service and environment:

```
conde-nast-fe-task-definition-<env>
conde-nast-be-task-definition-<env>
conde-nast-ingestion-task-definition-<env>
```

---

## Secrets Management

| Secret | Name Pattern | Used By |
|--------|-------------|---------|
| DocumentDB URI | `conde-nast-documentdb-url-<env>` | BE, Ingestion |

Secrets are injected at **container startup** via ECS `secrets` block referencing the Secrets Manager ARN — not passed as plain-text environment variables.

---

## S3 Bucket Access Matrix

| Bucket | BE Access | Ingestion Access |
|--------|-----------|-----------------|
| `conde-nast-processed-<env>` | ✅ Read/Write | ✅ Read/Write |
| `conde-nast-image-search-<env>` | ✅ Read/Write | ✗ |

---

## Environment Differences

| Component | Dev | Stage |
|-----------|-----|-------|
| **VPC CIDR** | 10.0.0.0/16 | 10.2.0.0/16 |
| **Frontend Tasks** | 1 desired, 1-2 range | 1 desired, 1-2 range |
| **Backend Tasks** | 1 desired, 1-2 range | 1 desired, 1-2 range |
| **Ingestion Tasks** | 1 desired, 1-2 range | 1 desired, 1-2 range |
| **Task CPU** | 256 | 256 |
| **Task Memory** | 512 MB | 512 MB |
| **DocumentDB Instances** | 1 (t3.medium) | 1 (t3.medium) |
| **DocumentDB Retention** | 7 days | 7 days |
| **HTTPS** | No | No |
| **Secret Recovery Window** | 7 days | 7 days |

---

## Security Zones

### Zone 1: Internet
- External clients can reach: **External ALB only**

### Zone 2: Public Subnet
- Internet Gateway, NAT Gateway, Elastic IP
- External ALB hosted here

### Zone 3: Private Subnets — Application Layer
- App ECS Cluster (FE + BE services)
- Ingestion ECS Cluster
- Internal ALB
- Outbound Internet via NAT Gateway

### Zone 4: Private Subnet — Data Layer
- DocumentDB Cluster (port 27017)
- Only reachable from ECS security groups

### Zone 5: AWS-Managed (Global)
- ECR, S3, OpenSearch Serverless, Secrets Manager, Bedrock
- Accessed from ECS via VPC NAT Gateway / AWS PrivateLink

---

## High Availability

- **Multi-AZ**: Resources distributed across 3 availability zones
- **Auto Scaling**: Horizontal scaling on CPU (70%) and Memory (80%) metrics
- **Load Balancing**: External and Internal ALBs distribute traffic across tasks
- **Database Replication**: DocumentDB instances with replica set
- **CloudWatch Logging**: All ECS services log to CloudWatch Log Groups

---

**Architecture Version**: 2.0
**Last Updated**: February 2026
