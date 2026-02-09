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
│  │  │            PUBLIC SUBNET (10.x.1.0/24)                          │ │  │
│  │  │                                                                 │ │  │
│  │  │  ┌──────────────────────┐      ┌──────────────────┐            │ │  │
│  │  │  │  Internet Gateway    │◄────►│  NAT Gateway     │            │ │  │
│  │  │  │  (IGW)               │      │  (EIP)           │            │ │  │
│  │  │  └──────────────────────┘      └──────────────────┘            │ │  │
│  │  │           │                             │                        │ │  │
│  │  │           │                             │                        │ │  │
│  │  │           ▼                             ▼                        │ │  │
│  │  │  ┌──────────────────────────────────────────────────────────┐  │ │  │
│  │  │  │        EXTERNAL ALB (Public)                              │  │ │  │
│  │  │  │  - Port 80: HTTP                                          │  │ │  │
│  │  │  │  - Port 443: HTTPS (optional)                             │  │ │  │
│  │  │  │  - SG: Allow 0.0.0.0/0                                    │  │ │  │
│  │  │  │  - Routes to Internal ALB                                 │  │ │  │
│  │  │  └──────────────────────────────────────────────────────────┘  │ │  │
│  │  │           │                                                      │ │  │
│  │  └───────────┼──────────────────────────────────────────────────────┘ │  │
│  │              │                                                        │  │
│  │  ┌───────────┼────────────────────────────────────────────────────┐  │  │
│  │  │           ▼                                                    │  │  │
│  │  │  ┌──────────────────────────────────────────────────────────┐ │  │  │
│  │  │  │        INTERNAL ALB (Private)                             │ │  │  │
│  │  │  │  - Port 80: HTTP                                          │ │  │  │
│  │  │  │  - SG: Allow from External ALB                            │ │  │  │
│  │  │  │  - Subnets: Across all private subnets                    │ │  │  │
│  │  │  └──────────────────────────────────────────────────────────┘ │  │  │
│  │  │           │                                                    │  │  │
│  │  └───────────┼────────────────────────────────────────────────────┘  │  │
│  │              │                                                        │  │
│  │  ┌───────────┴────────────┬─────────────────────────┐                │  │
│  │  │                        │                         │                │  │
│  │  ▼                        ▼                         ▼                │  │
│  │  ┌──────────────────────────────────────────────────────────────┐   │  │
│  │  │ PRIVATE SUBNET 1 (10.x.10.0/24)                              │   │  │
│  │  │                                                              │   │  │
│  │  │  ┌──────────────────────────────────────────────────────┐  │   │  │
│  │  │  │  ECS FRONTEND CLUSTER                                │  │   │  │
│  │  │  │  ├─ Service: frontend-service                        │  │   │  │
│  │  │  │  ├─ Task Definition: Frontend App (Nginx/React)      │  │   │  │
│  │  │  │  ├─ Container Port: 3000                             │  │   │  │
│  │  │  │  ├─ Desired Count: 1-2 (dev), 2 (qa), 2 (stage)      │  │   │  │
│  │  │  │  ├─ Min Capacity: 1 (dev), 2 (qa/stage)              │  │   │  │
│  │  │  │  ├─ Max Capacity: 2 (dev), 4 (qa), 6 (stage)         │  │   │  │
│  │  │  │  └─ Auto Scaling: CPU 70%, Memory 80%                │  │   │  │
│  │  │  └──────────────────────────────────────────────────────┘  │   │  │
│  │  │                                                              │   │  │
│  │  │  SG: Allow from Internal ALB + VPC CIDR                     │   │  │
│  │  └──────────────────────────────────────────────────────────────┘   │  │
│  │  ┌──────────────────────────────────────────────────────────────┐   │  │
│  │  │ PRIVATE SUBNET 2 (10.x.20.0/24)                              │   │  │
│  │  │                                                              │   │  │
│  │  │  ┌──────────────────────────────────────────────────────┐  │   │  │
│  │  │  │  ECS BACKEND CLUSTER                                 │  │   │  │
│  │  │  │  ├─ Service: backend-service                         │  │   │  │
│  │  │  │  ├─ Task Definition: Backend API (Node.js)           │  │   │  │
│  │  │  │  ├─ Container Port: 8080                             │  │   │  │
│  │  │  │  ├─ Desired Count: 1-2 (dev), 2 (qa), 2 (stage)      │  │   │  │
│  │  │  │  ├─ Min Capacity: 1 (dev), 2 (qa/stage)              │  │   │  │
│  │  │  │  ├─ Max Capacity: 2 (dev), 4 (qa), 6 (stage)         │  │   │  │
│  │  │  │  └─ Auto Scaling: CPU 70%, Memory 80%                │  │   │  │
│  │  │  └──────────────────────────────────────────────────────┘  │   │  │
│  │  │                                                              │   │  │
│  │  │  SG: Allow from Internal ALB + VPC CIDR                     │   │  │
│  │  │  Outbound: NAT via NAT Gateway                              │   │  │
│  │  └──────────────────────────────────────────────────────────────┘   │  │
│  │  ┌──────────────────────────────────────────────────────────────┐   │  │
│  │  │ PRIVATE SUBNET 3 (10.x.30.0/24)                              │   │  │
│  │  │                                                              │   │  │
│  │  │  ┌──────────────────────────────────────────────────────┐  │   │  │
│  │  │  │  AWS DOCUMENTDB CLUSTER                              │  │   │  │
│  │  │  │  ├─ Engine: DocumentDB (MongoDB-compatible)          │  │   │  │
│  │  │  │  ├─ Instance Class: db.t3.small (dev), medium (qa/s) │  │   │  │
│  │  │  │  ├─ Instances: 1 (dev), 2 (qa), 3 (stage)            │  │   │  │
│  │  │  │  ├─ Backup Retention: 7-30 days                      │  │   │  │
│  │  │  │  ├─ Encryption: Enabled                              │  │   │  │
│  │  │  │  ├─ Port: 27017                                      │  │   │  │
│  │  │  │  └─ TLS: Enabled                                     │  │   │  │
│  │  │  └──────────────────────────────────────────────────────┘  │   │  │
│  │  │                                                              │   │  │
│  │  │  SG: Allow port 27017 from ECS SG                           │   │  │
│  │  └──────────────────────────────────────────────────────────────┘   │  │
│  │                                                                      │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  Security Groups:                                                         │
│  ├─ ALB Public SG: 80, 443 from 0.0.0.0/0 → Any outbound                 │
│  ├─ ALB Internal SG: 80 from ALB Public SG → Any outbound                 │
│  ├─ ECS SG: 3000, 8080 from ALB Internal SG, VPC CIDR → Any outbound     │
│  └─ DocumentDB SG: 27017 from ECS SG → Any outbound                       │
│                                                                             │
│  Routing:                                                                 │
│  ├─ Public Route Table: 0.0.0.0/0 → IGW                                   │
│  └─ Private Route Table: 0.0.0.0/0 → NAT Gateway                          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Traffic Flow

### External User → Application

1. **User** (Internet) 
   → HTTP/HTTPS to External ALB DNS name
   
2. **External ALB** (Public, in Public Subnet)
   → Routes to Internal ALB (private IP)
   
3. **Internal ALB** (Private, in Private Subnets)
   → Routes to ECS Services (Frontend/Backend)
   
4. **ECS Services** (Private Subnets 1 & 2)
   → Processes request
   → Queries DocumentDB if needed (port 27017 allowed by SG)
   
5. **DocumentDB** (Private Subnet 3)
   → Returns data to Backend
   
6. **Response** → Back through ALBs to User

### ECS → External Services

- **Outbound Traffic**: Uses NAT Gateway in Public Subnet
- **Outbound Route**: Private Route Table → NAT Gateway → IGW → Internet

## Environment Differences

| Component | Dev | QA | Stage |
|-----------|-----|----|----|
| **VPC CIDR** | 10.0.0.0/16 | 10.1.0.0/16 | 10.2.0.0/16 |
| **Frontend Tasks** | 1 desired, 1-2 range | 2 desired, 2-4 range | 2 desired, 2-6 range |
| **Backend Tasks** | 1 desired, 1-2 range | 2 desired, 2-4 range | 2 desired, 2-6 range |
| **Frontend CPU** | 256 | 512 | 512 |
| **Frontend Memory** | 512 MB | 1024 MB | 1024 MB |
| **Backend CPU** | 256 | 512 | 512 |
| **Backend Memory** | 512 MB | 1024 MB | 1024 MB |
| **DocumentDB Instances** | 1 (t3.small) | 2 (t3.medium) | 3 (t3.medium) |
| **DocumentDB Retention** | 7 days | 14 days | 30 days |
| **HTTPS** | No | No | Yes |

## Security Zones

### Zone 1: Internet
- External clients
- Can access: External ALB only

### Zone 2: Public Subnet
- Internet Gateway
- NAT Gateway
- Elastic IP
- Can access: Internet and VPC
- Cannot access: Private subnets directly

### Zone 3: Private Subnets (1 & 2) - Application Layer
- ECS Frontend Cluster (Subnet 1)
- ECS Backend Cluster (Subnet 2)
- Can access: Other private subnets, Internet via NAT Gateway
- Cannot access: Internet directly, Public subnet directly

### Zone 4: Private Subnet (3) - Data Layer
- DocumentDB Cluster
- Can access: Other private subnets
- Cannot access: Internet, public subnet, external connections

## Data Flow Patterns

### 1. Frontend Request
User → External ALB → Internal ALB → Frontend ECS → Response → User

### 2. Backend Request
User → External ALB → Internal ALB → Backend ECS → Response → User

### 3. Backend → DocumentDB
Backend ECS → DocumentDB (Port 27017) → Data → Backend ECS

### 4. Backend → External API
Backend ECS → NAT Gateway → IGW → External API (uses ECS security group outbound rule)

## High Availability

- **Multi-AZ Deployment**: Resources distributed across 3 availability zones
- **Auto Scaling**: Horizontal scaling based on CPU/Memory metrics
- **Load Balancing**: External and Internal ALBs distribute traffic
- **Database Replication**: DocumentDB replicas across instances
- **CloudWatch Monitoring**: Container Insights enabled for all ECS resources
- **VPC Flow Logs**: Network traffic monitoring
