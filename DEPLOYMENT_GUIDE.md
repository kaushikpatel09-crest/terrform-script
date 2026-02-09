# Deployment Guide

## Quick Start

### Prerequisites Checklist
- [ ] AWS account with appropriate permissions
- [ ] Terraform >= 1.0 installed
- [ ] AWS CLI v2 installed
- [ ] Git installed
- [ ] S3 bucket for state created
- [ ] DynamoDB table for locking created
- [ ] GitHub secrets configured (if using CI/CD)

## Local Deployment

### 1. Clone Repository and Setup

```bash
# Clone the repository
git clone <repository-url>
cd conde-nast

# Windows (PowerShell)
.\setup.bat validate

# macOS/Linux
chmod +x setup.sh
./setup.sh check
```

### 2. Configure AWS Credentials

```bash
# Configure AWS CLI
aws configure

# Enter:
# AWS Access Key ID: [your-access-key]
# AWS Secret Access Key: [your-secret-key]
# Default region: us-east-1
# Default output format: json

# Verify configuration
aws sts get-caller-identity
```

### 3. Initialize Backend

```bash
# Windows (PowerShell)
.\setup.bat validate

# macOS/Linux
./setup.sh init dev
```

When prompted, enter:
- S3 bucket name: `your-terraform-state-bucket`
- DynamoDB table name: `terraform-lock`
- AWS region: `us-east-1`

### 4. Plan Deployment

```bash
# Windows
.\setup.bat plan dev

# macOS/Linux
./setup.sh plan dev
```

When prompted, enter DocumentDB password: `YourSecurePassword123!`

### 5. Review Plan

The plan output shows:
- Resources to be created
- Network architecture
- ECS clusters and services
- DocumentDB cluster
- Load balancers
- Security groups

Example output:
```
Plan: 85 to add, 0 to change, 0 to destroy.
```

### 6. Apply Configuration

```bash
# Windows
.\setup.bat apply dev

# macOS/Linux
./setup.sh apply dev
```

Confirm by typing `yes` when prompted.

The deployment typically takes:
- **5-10 minutes**: VPC and networking
- **10-15 minutes**: ECS clusters and services
- **15-20 minutes**: DocumentDB cluster
- **Total: ~20-30 minutes**

### 7. View Outputs

```bash
# Windows
.\setup.bat output dev

# macOS/Linux
./setup.sh output dev

# Output example:
# external_alb_dns_name = "conde-nast-external-alb-dev-123456789.us-east-1.elb.amazonaws.com"
# documentdb_cluster_endpoint = "conde-nast-docdb-dev.cluster-xxxxxxxxxx.us-east-1.docdb.amazonaws.com:27017"
```

### 8. Test Connectivity

```bash
# Test external ALB
curl http://<external-alb-dns-name>

# Get ECS services
aws ecs list-services --cluster conde-nast-fe-dev
aws ecs list-services --cluster conde-nast-be-dev

# Check DocumentDB
# ConnectionString: mongodb://admin:password@endpoint:27017/admin?ssl=true&authSource=admin
```

## GitHub Actions Deployment

### 1. Prerequisites

- GitHub repository pushed with code
- AWS OIDC provider configured
- GitHub secrets configured:
  - `AWS_ROLE_ARN`
  - `TF_STATE_BUCKET`
  - `TF_LOCK_TABLE`
  - `DOCUMENTDB_PASSWORD`

### 2. Plan Deployment

1. Go to **GitHub Actions** → **Terraform Plan & Apply**
2. Click **Run workflow**
3. Select environment: `dev`
4. Select action: `plan`
5. Click **Run workflow**
6. Wait for completion and review plan

### 3. Apply Deployment

1. Go to **GitHub Actions** → **Terraform Plan & Apply**
2. Click **Run workflow**
3. Select environment: `dev`
4. Select action: `apply`
5. Click **Run workflow**
6. Wait for completion

### 4. Monitor Deployment

- View **Summary**: Shows Terraform outputs
- Download **Artifacts**: Contains plan file
- Review **Logs**: Detailed execution logs

## Multi-Environment Deployment

### Deploy to QA

```bash
# Local
.\setup.bat plan qa
.\setup.bat apply qa

# GitHub Actions
# Same process, select environment: qa
```

### Deploy to Stage

```bash
# Local
.\setup.bat plan stage
.\setup.bat apply stage

# GitHub Actions
# Same process, select environment: stage
```

## Configuration Updates

### Update Container Images

Edit `terraform/environments/dev.tfvars`:

```hcl
# Frontend
frontend_image = "my-registry/frontend"
frontend_image_tag = "v1.0.0"

# Backend
backend_image = "my-registry/backend"
backend_image_tag = "v1.0.0"
```

Apply changes:
```bash
./setup.sh plan dev
./setup.sh apply dev
```

### Modify Auto Scaling

Edit `terraform/environments/qa.tfvars`:

```hcl
# Increase QA capacity
frontend_max_capacity = 8      # was 4
backend_max_capacity = 8       # was 4
backend_desired_count = 3      # was 2
```

Apply changes:
```bash
./setup.sh plan qa
./setup.sh apply qa
```

### Enable HTTPS for Stage

Edit `terraform/environments/stage.tfvars`:

```hcl
enable_https = true
certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxx"
```

Apply changes:
```bash
./setup.sh plan stage
./setup.sh apply stage
```

## Monitoring Deployment

### CloudWatch Logs

```bash
# Frontend ECS logs
aws logs tail /ecs/conde-nast-fe-dev --follow

# Backend ECS logs
aws logs tail /ecs/conde-nast-be-dev --follow

# DocumentDB logs
aws logs tail /aws/docdb/conde-nast-docdb-dev --follow

# VPC Flow Logs
aws logs tail /aws/vpc/flowlogs/conde-nast-dev --follow
```

### ECS Services

```bash
# Check frontend service
aws ecs describe-services \
  --cluster conde-nast-fe-dev \
  --services conde-nast-fe-service

# Check backend service
aws ecs describe-services \
  --cluster conde-nast-be-dev \
  --services conde-nast-be-service

# Get running tasks
aws ecs list-tasks --cluster conde-nast-fe-dev
```

### Load Balancer Health

```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:...

# Check ALB
aws elbv2 describe-load-balancers \
  --names conde-nast-external-alb-dev
```

## Scaling Services

### Horizontal Scaling

Auto scaling is configured with metrics:
- **CPU**: Target 70%
- **Memory**: Target 80%

For manual scaling:

```bash
# Update frontend desired count
aws ecs update-service \
  --cluster conde-nast-fe-dev \
  --service conde-nast-fe-service \
  --desired-count 3

# Update backend desired count
aws ecs update-service \
  --cluster conde-nast-be-dev \
  --service conde-nast-be-service \
  --desired-count 3
```

Or through Terraform:

```hcl
# terraform/environments/dev.tfvars
frontend_desired_count = 3
backend_desired_count = 3
```

### Vertical Scaling (Task Size)

Update Terraform variables:

```hcl
# terraform/environments/dev.tfvars
frontend_task_cpu = 512      # was 256
frontend_task_memory = 1024  # was 512
backend_task_cpu = 1024      # was 512
backend_task_memory = 2048   # was 1024
```

## Troubleshooting Deployments

### Check Terraform State

```bash
# List all resources
terraform state list

# Show specific resource
terraform state show 'module.ecs_frontend.aws_ecs_service.main'

# Refresh state
terraform refresh
```

### Common Issues

#### "Error: VPC not found"

```bash
# Verify VPC exists
aws ec2 describe-vpcs --filters "Name=cidr,Values=10.0.0.0/16"

# Or recreate
terraform apply -target=module.vpc
```

#### "Error: Security Group not found"

```bash
# Verify security groups
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=vpc-xxxxx"

# Recreate all VPC resources
terraform destroy -target=module.vpc
terraform apply -target=module.vpc
```

#### "Error: ECS Service failing to start tasks"

```bash
# Check ECS logs
aws logs tail /ecs/conde-nast-fe-dev --follow

# Check service events
aws ecs describe-services \
  --cluster conde-nast-fe-dev \
  --services conde-nast-fe-service \
  --query 'services[0].events' \
  --output table
```

#### "Error: DocumentDB unable to connect"

```bash
# Verify cluster endpoint
aws docdb describe-db-clusters \
  --db-cluster-identifier conde-nast-docdb-dev \
  --query 'DBClusters[0].Endpoint'

# Check security group
aws ec2 describe-security-groups \
  --group-ids sg-xxxxx \
  --query 'SecurityGroups[0].IpPermissions'
```

### Enable Debug Logging

```bash
# Enable Terraform debug
export TF_LOG=DEBUG
./setup.sh plan dev
unset TF_LOG

# Enable AWS CLI debug
aws ec2 describe-vpcs --debug

# Check CloudTrail logs
aws cloudtrail lookup-events --lookup-attributes AttributeKey=ResourceName,AttributeValue=conde-nast-vpc-dev
```

## Destroying Infrastructure

### Local Destruction

```bash
# Destroy dev environment
./setup.sh destroy dev

# Confirm by typing: dev
```

### GitHub Actions Destruction

1. Go to **GitHub Actions** → **Terraform Plan & Apply**
2. Click **Run workflow**
3. Select environment: `dev`
4. Select action: `destroy`
5. Click **Run workflow**

### Manual State Cleanup

```bash
# If automated destroy fails
terraform destroy -var-file="environments/dev.tfvars" -var="documentdb_master_password=xxx" -auto-approve

# If that fails, remove from state
terraform state rm 'module.documentdb.aws_docdb_cluster.main'
terraform state rm 'module.ecs_frontend.aws_ecs_service.main'

# Then retry destroy
terraform destroy -auto-approve
```

## Backup and Recovery

### Backup Terraform State

```bash
# Download state file
aws s3 cp s3://your-terraform-state-bucket/dev/terraform.tfstate ./terraform.tfstate.backup

# Verify backup
terraform state list -state=./terraform.tfstate.backup
```

### Backup DocumentDB

```bash
# Enable automated backups (already configured)
# Backups retained: 7-30 days depending on environment

# Manual backup
aws docdb create-db-cluster-snapshot \
  --db-cluster-identifier conde-nast-docdb-dev \
  --db-cluster-snapshot-identifier conde-nast-docdb-dev-backup-$(date +%s)

# List snapshots
aws docdb describe-db-cluster-snapshots \
  --db-cluster-identifier conde-nast-docdb-dev
```

## Cost Monitoring

```bash
# Estimate monthly cost
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# View current spend
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '30 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost
```

## Post-Deployment Steps

1. **Test Endpoints**
   ```bash
   curl http://<external-alb-dns>
   ```

2. **Configure Application**
   - Update app configuration with DocumentDB endpoint
   - Deploy application containers
   - Test application health

3. **Setup Monitoring**
   - Configure CloudWatch alarms
   - Setup SNS notifications
   - Create dashboards

4. **Configure DNS**
   - Update Route 53 or DNS provider
   - Point domain to External ALB
   - Test DNS resolution

5. **Enable HTTPS**
   - Request ACM certificate
   - Update stage.tfvars with certificate ARN
   - Apply changes

6. **Backup Configuration**
   - Export Terraform state
   - Document environment variables
   - Store passwords securely (AWS Secrets Manager)

## Next Steps

1. Review [ARCHITECTURE.md](ARCHITECTURE.md) for architecture details
2. Review [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md) for CI/CD setup
3. Review [README.md](README.md) for complete documentation
4. Monitor costs and performance regularly
5. Schedule regular backup tests
