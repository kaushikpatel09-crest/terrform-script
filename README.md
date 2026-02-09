# Terraform AWS Infrastructure

This project contains Infrastructure as Code (IaC) using Terraform to deploy a complete AWS infrastructure with VPC, ECS, DocumentDB, and Load Balancers across multiple environments (dev, qa, stage).

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Environment Configuration](#environment-configuration)
- [Deployment](#deployment)
- [GitHub Actions Pipeline](#github-actions-pipeline)
- [Outputs](#outputs)
- [Troubleshooting](#troubleshooting)

## Architecture Overview

### Infrastructure Components

#### VPC (Virtual Private Cloud)
- **CIDR**: Environment-specific (10.0.0.0/16 for dev, 10.1.0.0/16 for qa, 10.2.0.0/16 for stage)
- **1 Public Subnet**: For NAT Gateway and public-facing ALB
- **3 Private Subnets**: For ECS Frontend, ECS Backend, and DocumentDB
- **1 NAT Gateway**: For outbound internet access from private subnets

#### ECS (Elastic Container Service)
- **Frontend Cluster**: Runs containerized web application (Nginx/React)
  - Task CPU: 256-512 (configurable per environment)
  - Task Memory: 512-1024 MB (configurable per environment)
  - Auto Scaling: Min 1-2, Max 2-6 tasks
  - Health Checks: Every 30 seconds

- **Backend Cluster**: Runs containerized API service (Node.js)
  - Task CPU: 256-512 (configurable per environment)
  - Task Memory: 512-1024 MB (configurable per environment)
  - Auto Scaling: Min 1-2, Max 2-6 tasks
  - Health Checks: Every 30 seconds

#### Load Balancers
- **External ALB (Application Load Balancer)**:
  - Public-facing from Internet Gateway
  - Port 80 (HTTP) and 443 (HTTPS - optional)
  - Routes to internal ALB

- **Internal ALB**:
  - Private, accessible only from within VPC
  - Routes traffic to both Frontend and Backend ECS services
  - Allows traffic only from External ALB

#### DocumentDB
- **Cluster**: MongoDB-compatible document database
  - Engine: 4.0.0
  - Instances: 1-3 (configurable per environment)
  - Backup Retention: 7-30 days (configurable per environment)
  - Encryption: Enabled
  - Placed in 3rd private subnet

#### Security Groups
- **Public ALB SG**: Allows inbound 80/443 from 0.0.0.0/0
- **Internal ALB SG**: Allows inbound 80 from Public ALB SG
- **ECS SG**: Allows inbound from Internal ALB SG and VPC CIDR
- **DocumentDB SG**: Allows inbound port 27017 from ECS SG

#### Auto Scaling
- **Frontend**: CPU threshold 70%, Memory threshold 80%
- **Backend**: CPU threshold 70%, Memory threshold 80%
- **Min/Max capacity**: Environment-specific

## Prerequisites

### Local Development
1. **Terraform** >= 1.0
   ```bash
   # macOS
   brew install terraform
   
   # Windows
   choco install terraform
   
   # Linux
   terraform version # download from https://www.terraform.io/downloads
   ```

2. **AWS CLI** >= 2.0
   ```bash
   # Install AWS CLI v2
   https://aws.amazon.com/cli/
   ```

3. **AWS Account** with appropriate permissions
   - EC2
   - VPC
   - ECS
   - DocumentDB
   - Elastic Load Balancing
   - CloudWatch
   - IAM
   - S3 (for remote state)
   - DynamoDB (for state locking)

4. **AWS Credentials**
   ```bash
   aws configure
   # Enter your AWS Access Key ID and Secret Access Key
   ```

### GitHub Setup
1. AWS IAM Role for GitHub Actions (OIDC)
2. S3 bucket for Terraform state
3. DynamoDB table for state locking
4. GitHub Secrets configured (see [GitHub Actions Setup](#github-actions-setup))

## Project Structure

```
.
├── .github/
│   └── workflows/
│       ├── terraform.yml              # Main Terraform Plan/Apply workflow
│       └── terraform-validate.yml     # Validation and security scanning
├── terraform/
│   ├── main.tf                        # Root module - orchestrates all modules
│   ├── variables.tf                   # Input variables
│   ├── outputs.tf                     # Output values
│   ├── environments/
│   │   ├── dev.tfvars                 # Dev environment variables
│   │   ├── qa.tfvars                  # QA environment variables
│   │   └── stage.tfvars               # Stage environment variables
│   └── modules/
│       ├── vpc/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── ecs/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── load_balancer/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       └── documentdb/
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
└── README.md
```

## Environment Configuration

### Dev Environment
- **VPC CIDR**: 10.0.0.0/16
- **Frontend Tasks**: 1 desired, 1-2 range
- **Backend Tasks**: 1 desired, 1-2 range
- **DocumentDB**: 1 instance, db.t3.small, 7-day retention
- **HTTPS**: Disabled

### QA Environment
- **VPC CIDR**: 10.1.0.0/16
- **Frontend Tasks**: 2 desired, 2-4 range
- **Backend Tasks**: 2 desired, 2-4 range
- **DocumentDB**: 2 instances, db.t3.medium, 14-day retention
- **HTTPS**: Disabled

### Stage Environment
- **VPC CIDR**: 10.2.0.0/16
- **Frontend Tasks**: 2 desired, 2-6 range
- **Backend Tasks**: 2 desired, 2-6 range
- **DocumentDB**: 3 instances, db.t3.medium, 30-day retention
- **HTTPS**: Enabled

## Deployment

### Local Deployment

#### 1. Initialize Terraform
```bash
cd terraform
terraform init -backend-config="bucket=YOUR_BUCKET" \
               -backend-config="key=dev/terraform.tfstate" \
               -backend-config="region=us-east-1" \
               -backend-config="dynamodb_table=terraform-lock"
```

#### 2. Validate Configuration
```bash
terraform validate
terraform fmt -recursive
```

#### 3. Plan Deployment
```bash
terraform plan -var-file="environments/dev.tfvars" \
               -var="documentdb_master_password=YourSecurePassword123!" \
               -out=tfplan
```

#### 4. Apply Configuration
```bash
terraform apply tfplan
```

#### 5. Destroy Resources (if needed)
```bash
terraform destroy -var-file="environments/dev.tfvars" \
                  -var="documentdb_master_password=YourSecurePassword123!"
```

### Remote State Configuration

Create S3 bucket and DynamoDB table:
```bash
# S3 bucket for state
aws s3 mb s3://your-terraform-state-bucket --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket your-terraform-state-bucket \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# DynamoDB table for locking
aws dynamodb create-table \
  --table-name terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

## GitHub Actions Pipeline

### Setup

#### 1. Create GitHub Secrets
In your GitHub repository settings, add the following secrets:

```
AWS_ROLE_ARN              # ARN of IAM role for GitHub OIDC
TF_STATE_BUCKET           # S3 bucket name for Terraform state
TF_LOCK_TABLE             # DynamoDB table name for state locking
DOCUMENTDB_PASSWORD       # DocumentDB master password
```

#### 2. Create AWS IAM Role for GitHub OIDC

```bash
# Create trust policy
cat > trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_ORG/YOUR_REPO:*"
        }
      }
    }
  ]
}
EOF

# Create IAM role
aws iam create-role \
  --role-name github-terraform-role \
  --assume-role-policy-document file://trust-policy.json

# Attach policy
aws iam put-role-policy \
  --role-name github-terraform-role \
  --policy-name terraform-policy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "ec2:*",
          "vpc:*",
          "ecs:*",
          "elasticloadbalancing:*",
          "docdb:*",
          "logs:*",
          "cloudwatch:*",
          "iam:*",
          "s3:*",
          "dynamodb:*"
        ],
        "Resource": "*"
      }
    ]
  }'
```

### Running the Pipeline

#### 1. Plan Deployment
```
Go to Actions → Terraform Plan & Apply → Run workflow
- Select environment: dev, qa, or stage
- Select action: plan
- Review the output and plan
```

#### 2. Apply Deployment
```
Go to Actions → Terraform Plan & Apply → Run workflow
- Select environment: dev, qa, or stage
- Select action: apply
- Pipeline will automatically apply the changes
```

#### 3. Destroy Resources
```
Go to Actions → Terraform Plan & Apply → Run workflow
- Select environment: dev, qa, or stage
- Select action: destroy
- Pipeline will destroy all resources
```

### Pipeline Details

**Terraform Plan & Apply Workflow** (`terraform.yml`)
- **Trigger**: Manual workflow dispatch with environment dropdown
- **Steps**:
  1. Checkout code
  2. Configure AWS credentials via OIDC
  3. Setup Terraform
  4. Format check
  5. Initialize Terraform
  6. Validate configuration
  7. Plan changes (or apply/destroy based on input)
  8. Create summary in workflow summary
  9. Upload plan artifact
  10. Post results to PR

**Terraform Validation Workflow** (`terraform-validate.yml`)
- **Trigger**: Push to main/develop or PR
- **Steps**:
  1. Format check
  2. Initialize (dry-run)
  3. Validate
  4. TFLint security checks
  5. Checkov security scanning
  6. Generate Terraform documentation

## Outputs

After deployment, Terraform outputs the following values:

### VPC Outputs
- `vpc_id`: VPC identifier
- `vpc_cidr`: VPC CIDR block
- `public_subnet_id`: Public subnet ID
- `private_subnet_ids`: List of private subnet IDs
- `nat_gateway_id`: NAT Gateway ID
- `nat_gateway_public_ip`: NAT Gateway Elastic IP

### ECS Outputs
- `ecs_frontend_cluster_name`: Frontend cluster name
- `ecs_frontend_service_name`: Frontend service name
- `ecs_backend_cluster_name`: Backend cluster name
- `ecs_backend_service_name`: Backend service name

### DocumentDB Outputs
- `documentdb_cluster_endpoint`: Connection endpoint
- `documentdb_reader_endpoint`: Read replica endpoint

### Load Balancer Outputs
- `external_alb_dns_name`: External ALB DNS (public)
- `external_alb_arn`: External ALB ARN
- `internal_alb_dns_name`: Internal ALB DNS (private)
- `internal_alb_arn`: Internal ALB ARN

## Accessing Services

### External ALB
```
http://external-alb-dns-name  # From internet
```

### Internal ALB
```
http://internal-alb-dns-name  # From within VPC only
```

### DocumentDB Connection String
```
mongodb://admin:password@cluster-endpoint:27017/?ssl=true&replicaSet=rs0&authSource=admin
```

## Troubleshooting

### Terraform State Issues
```bash
# List state resources
terraform state list

# Show specific resource
terraform state show 'module.vpc.aws_vpc.main'

# Remove resource from state (careful!)
terraform state rm 'module.vpc.aws_vpc.main'
```

### Common Errors

#### "Error: Backend initialization required"
```bash
terraform init -reconfigure
```

#### "Error: Resource already exists"
```bash
# Import existing resource
terraform import aws_vpc.main vpc-1234567890abcdef0
```

#### "Error: Invalid provider configuration"
```bash
# Verify AWS credentials
aws sts get-caller-identity
```

### Debugging

#### Enable debug logging
```bash
export TF_LOG=DEBUG
terraform apply
unset TF_LOG
```

#### Validate JSON in variables
```bash
terraform validate
terraform plan -json | jq '.'
```

## Security Best Practices

1. **Sensitive Data**: Never commit secrets to git
   - Use GitHub Secrets for sensitive variables
   - Use AWS Secrets Manager for runtime secrets
   - Encrypt Terraform state (S3 SSE-S3, DynamoDB encryption)

2. **IAM Permissions**: Use principle of least privilege
   - Limit GitHub Actions IAM role to necessary permissions
   - Use resource-based policies when possible

3. **Network Security**:
   - Security groups restrict traffic appropriately
   - Private subnets use NAT Gateway for outbound access
   - DocumentDB encryption enabled

4. **State Management**:
   - Remote state in S3 with encryption
   - State locking with DynamoDB
   - Enable MFA delete on S3 bucket

5. **Monitoring**:
   - CloudWatch Logs for all services
   - VPC Flow Logs enabled
   - ECS Container Insights enabled

## Cost Optimization

- **Dev**: Minimal resources (t3.small/micro instances)
- **QA**: Medium resources (t3.medium instances)
- **Stage**: Production-grade resources
- **Auto Scaling**: Scales down during off-hours if configured with CloudWatch events
- **Spot Instances**: Uses Fargate Spot for non-critical workloads (10% default weight)

## Maintenance

### Regular Tasks
- Review and update container image tags
- Monitor costs in AWS Cost Explorer
- Review security group rules
- Update Terraform version annually
- Backup DocumentDB data

### Scaling Adjustments
Edit `terraform/environments/[env].tfvars`:
```hcl
frontend_min_capacity  = 2
frontend_max_capacity  = 8
backend_min_capacity   = 2
backend_max_capacity   = 8
```

Then run:
```bash
terraform plan -var-file="environments/dev.tfvars" -var="documentdb_master_password=..."
terraform apply
```

## Contributing

1. Create a feature branch
2. Make changes to Terraform code
3. Run `terraform fmt -recursive` to format
4. Validate: `terraform validate`
5. Create PR for review
6. Once approved, use GitHub Actions to deploy

## Additional Resources

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-best-practices.html)
- [DocumentDB Documentation](https://docs.aws.amazon.com/documentdb/)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices.html)

## License

MIT License - See LICENSE file for details

## Support

For issues or questions:
1. Check the Troubleshooting section
2. Review GitHub Actions logs
3. Check AWS CloudTrail logs
4. Open an issue in the repository
