# Project Summary and Quick Reference

## Project Overview

This Terraform project deploys a complete production-ready AWS infrastructure for Condé Nast with:

- **3 Environments**: dev, qa, stage (with environment dropdown in GitHub Actions)
- **VPC Architecture**: 1 public subnet, 3 private subnets, NAT gateway
- **Container Orchestration**: ECS Fargate with auto-scaling
- **Database**: DocumentDB (MongoDB-compatible)
- **Load Balancing**: External ALB (internet-facing) + Internal ALB (VPC-only)
- **CI/CD**: GitHub Actions pipeline with plan/apply/destroy workflow

## Quick Links

| Document | Purpose |
|----------|---------|
| [README.md](README.md) | Complete documentation and reference |
| [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) | Step-by-step deployment instructions |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Architecture diagrams and design |
| [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md) | CI/CD setup and configuration |

## Key Features

### ✅ Multi-Environment Support
```
Dev   → 10.0.0.0/16  → 1 task, minimal resources
QA    → 10.1.0.0/16  → 2 tasks, medium resources
Stage → 10.2.0.0/16  → 2 tasks, full resources + HTTPS
```

### ✅ Environment Selection via GitHub Actions
```yaml
workflow_dispatch:
  inputs:
    environment:
      type: choice
      options:
        - dev
        - qa
        - stage
    action:
      type: choice
      options:
        - plan
        - apply
        - destroy
```

### ✅ VPC with NAT Gateway
- 1 public subnet for NAT Gateway
- 3 private subnets for:
  1. ECS Frontend (port 3000)
  2. ECS Backend (port 8080)
  3. DocumentDB (port 27017)

### ✅ ECS Services with Auto Scaling
**Frontend Cluster**:
- Task: Nginx/React application
- Port: 3000
- CPU Scale: 70% threshold
- Memory Scale: 80% threshold

**Backend Cluster**:
- Task: Node.js API
- Port: 8080
- CPU Scale: 70% threshold
- Memory Scale: 80% threshold

### ✅ Load Balancers
**External ALB**:
- Public IP from Internet Gateway
- Port 80 (HTTP) and 443 (HTTPS optional)
- Routes to Internal ALB

**Internal ALB**:
- Private IP in VPC
- Routes to Frontend and Backend ECS services
- Allows traffic only from External ALB

### ✅ DocumentDB
- MongoDB-compatible database
- Cluster endpoint for connections
- 1-3 instances per environment
- TLS encryption enabled
- Automated backups

### ✅ Security
- Security groups with least privilege access
- Private subnets with NAT for outbound
- VPC Flow Logs enabled
- CloudWatch monitoring
- Container Insights

## Project Structure

```
.
├── .github/
│   └── workflows/
│       ├── terraform.yml              # Main deployment pipeline
│       └── terraform-validate.yml     # Validation and security scanning
├── terraform/
│   ├── main.tf                        # Root module
│   ├── variables.tf                   # Input variables
│   ├── outputs.tf                     # Output values
│   ├── environments/
│   │   ├── dev.tfvars                 # Dev configuration
│   │   ├── qa.tfvars                  # QA configuration
│   │   └── stage.tfvars               # Stage configuration
│   └── modules/
│       ├── vpc/                       # VPC module
│       ├── ecs/                       # ECS module
│       ├── load_balancer/             # Load Balancer module
│       └── documentdb/                # DocumentDB module
├── setup.sh                           # Linux/macOS setup script
├── setup.bat                          # Windows setup script
├── README.md                          # Full documentation
├── DEPLOYMENT_GUIDE.md                # Deployment instructions
├── ARCHITECTURE.md                    # Architecture details
├── GITHUB_ACTIONS_SETUP.md            # CI/CD setup
└── .gitignore                         # Git ignore rules
```

## Getting Started

### 1. Prerequisites
```bash
# Install
terraform >= 1.0
aws-cli >= 2.0
git

# Configure
aws configure
# Enter: Access Key, Secret Key, Region, Output format
```

### 2. Setup Backend
```bash
# Create S3 bucket
aws s3 mb s3://your-terraform-state-bucket --region us-east-1

# Create DynamoDB table
aws dynamodb create-table \
  --table-name terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### 3. Deploy Infrastructure
```bash
# macOS/Linux
chmod +x setup.sh
./setup.sh init dev
./setup.sh plan dev
./setup.sh apply dev

# Windows
.\setup.bat validate
.\setup.bat plan dev
.\setup.bat apply dev
```

### 4. View Outputs
```bash
# macOS/Linux
./setup.sh output dev

# Windows
.\setup.bat output dev
```

## GitHub Actions Setup

### 1. Create AWS OIDC
```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
  --client-id-list sts.amazonaws.com
```

### 2. Create IAM Role
```bash
# Use trust policy from GITHUB_ACTIONS_SETUP.md
aws iam create-role \
  --role-name github-terraform-role \
  --assume-role-policy-document file://trust-policy.json
```

### 3. Add GitHub Secrets
- `AWS_ROLE_ARN`: Role ARN from step 2
- `TF_STATE_BUCKET`: S3 bucket name
- `TF_LOCK_TABLE`: DynamoDB table name
- `DOCUMENTDB_PASSWORD`: Secure password

### 4. Run Deployment
Go to GitHub Actions → Terraform Plan & Apply → Run workflow
- Select environment (dev/qa/stage)
- Select action (plan/apply/destroy)

## Configuration Files

### dev.tfvars
```hcl
# Minimal resources for development
vpc_cidr = "10.0.0.0/16"
frontend_task_cpu = 256
frontend_task_memory = 512
frontend_desired_count = 1
documentdb_num_instances = 1
documentdb_instance_class = "db.t3.small"
```

### qa.tfvars
```hcl
# Medium resources for QA testing
vpc_cidr = "10.1.0.0/16"
frontend_task_cpu = 512
frontend_task_memory = 1024
frontend_desired_count = 2
documentdb_num_instances = 2
documentdb_instance_class = "db.t3.medium"
```

### stage.tfvars
```hcl
# Production-grade resources
vpc_cidr = "10.2.0.0/16"
frontend_task_cpu = 512
frontend_task_memory = 1024
frontend_desired_count = 2
documentdb_num_instances = 3
documentdb_instance_class = "db.t3.medium"
enable_https = true
```

## Common Commands

### Planning & Applying
```bash
# Plan deployment
terraform plan -var-file="environments/dev.tfvars" \
               -var="documentdb_master_password=xxx"

# Apply deployment
terraform apply -var-file="environments/dev.tfvars" \
                -var="documentdb_master_password=xxx"

# Destroy resources
terraform destroy -var-file="environments/dev.tfvars" \
                  -var="documentdb_master_password=xxx"
```

### State Management
```bash
# List resources
terraform state list

# Show resource details
terraform state show 'module.vpc.aws_vpc.main'

# Remove resource
terraform state rm 'resource-name'

# Refresh state
terraform refresh
```

### Debugging
```bash
# Enable debug logging
export TF_LOG=DEBUG

# Format check
terraform fmt -recursive

# Validate
terraform validate

# Show outputs
terraform output
```

## Monitoring

### CloudWatch Logs
```bash
# Frontend logs
aws logs tail /ecs/conde-nast-fe-dev --follow

# Backend logs
aws logs tail /ecs/conde-nast-be-dev --follow

# DocumentDB logs
aws logs tail /aws/docdb/conde-nast-docdb-dev --follow
```

### ECS Services
```bash
# List clusters
aws ecs list-clusters

# Describe service
aws ecs describe-services --cluster conde-nast-fe-dev \
                         --services conde-nast-fe-service

# List tasks
aws ecs list-tasks --cluster conde-nast-fe-dev
```

### Load Balancers
```bash
# Describe ALBs
aws elbv2 describe-load-balancers \
  --names conde-nast-external-alb-dev

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:...
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Backend initialization required" | Run `terraform init -reconfigure` |
| "Error: Access Denied" | Verify AWS credentials: `aws sts get-caller-identity` |
| "Error: VPC not found" | Run `terraform apply -target=module.vpc` |
| "ECS tasks not starting" | Check logs: `aws logs tail /ecs/... --follow` |
| "Cannot connect to DocumentDB" | Verify SG: `aws ec2 describe-security-groups` |

## Cost Estimation

### Monthly Cost (Approximate)

**Dev Environment**:
- VPC: ~$45 (NAT gateway data transfer)
- ECS: ~$80 (1-2 tasks)
- DocumentDB: ~$30 (1 instance t3.small)
- **Total: ~$155/month**

**QA Environment**:
- VPC: ~$45
- ECS: ~$200 (2-4 tasks)
- DocumentDB: ~$60 (2 instances t3.medium)
- **Total: ~$305/month**

**Stage Environment**:
- VPC: ~$45
- ECS: ~$200 (2-6 tasks)
- DocumentDB: ~$90 (3 instances t3.medium)
- Load Balancers: ~$30
- **Total: ~$365/month**

## Security Considerations

1. ✅ Private subnets for sensitive resources
2. ✅ NAT gateway for outbound-only internet access
3. ✅ Security groups with least privilege
4. ✅ DocumentDB encryption enabled
5. ✅ VPC Flow Logs for auditing
6. ✅ Secrets stored in GitHub Secrets (not in code)
7. ✅ HTTPS support for production
8. ✅ CloudWatch monitoring enabled

## Support

For issues or questions:
1. Check [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) troubleshooting section
2. Review [ARCHITECTURE.md](ARCHITECTURE.md) for design details
3. Check GitHub Actions logs for CI/CD issues
4. Review AWS CloudTrail logs for API calls

## Next Steps

1. Read [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for detailed setup
2. Review [ARCHITECTURE.md](ARCHITECTURE.md) to understand design
3. Follow [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md) for CI/CD
4. Deploy to dev environment first
5. Test and validate
6. Scale to qa and stage as needed

## Additional Resources

- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-best-practices.html)
- [DocumentDB Documentation](https://docs.aws.amazon.com/documentdb/)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices.html)

---

**Created**: February 6, 2026
**Version**: 1.0
**Status**: Production Ready
