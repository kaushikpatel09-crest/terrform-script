# Condé Nast Application - Deployment Guide

## Overview

This guide walks through deploying and testing the sample Frontend and Backend applications.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      External ALB (Internet)                    │
│                    (External DNS endpoint)                       │
└─────────────────────┬───────────────────────────────────────────┘
                      │ Port 80/443
                      ▼
        ┌─────────────────────────────┐
        │   Frontend ECS Service       │
        │   (Nginx on port 80)         │
        │   - 3 tasks across 3 AZs     │
        │   - Auto-scaling enabled     │
        └─────────────────────────────┘
                      │
                      │ Internal ALB (Port 80)
                      ▼
        ┌─────────────────────────────┐
        │   Backend ECS Service        │
        │   (Node.js on port 8080)     │
        │   - 3 tasks across 3 AZs     │
        │   - Auto-scaling enabled     │
        │   - Bedrock integration      │
        └─────────────────────────────┘
                      │
                      │ Database
                      ▼
        ┌─────────────────────────────┐
        │      DocumentDB (Private)    │
        │   (Connection String)        │
        └─────────────────────────────┘
```

## Prerequisites

1. **GitHub Secrets** (Already configured in GitHub Actions):
   - `AWS_ROLE_ARN` - IAM role for GitHub Actions
   - `TF_STATE_BUCKET` - Terraform state bucket
   - `TF_LOCK_TABLE` - Terraform lock table
   - `DOCUMENTDB_PASSWORD` - Database master password

2. **AWS Resources** (Already provisioned):
   - VPC with 3 public and 3 private subnets
   - ECR repositories: `conde-nast-frontend-dev`, `conde-nast-backend-dev`
   - ECS clusters: `conde-nast-fe-dev`, `conde-nast-be-dev`
   - External ALB (public-facing)
   - Internal ALB (VPC-only)
   - DocumentDB cluster (optional)

## Building Docker Images Locally

### Frontend

```bash
cd apps/frontend
docker build -t conde-nast-frontend:latest .
docker run -p 8000:80 conde-nast-frontend:latest
# Visit: http://localhost:8000
```

### Backend

```bash
cd apps/backend
docker build -t conde-nast-backend:latest .
docker run -p 8080:8080 conde-nast-backend:latest
# Test: curl http://localhost:8080/api/health
```

## Deploying with GitHub Actions

### Option 1: Automatic Deployment (on push to main)

Simply push changes to the `apps/` directory:

```bash
git add apps/
git commit -m "Update frontend/backend"
git push origin main
```

The `ecr-push.yml` workflow will:
1. Build Docker images
2. Push to ECR
3. Update ECS services
4. Restart containers with new images

### Option 2: Manual Deployment (workflow_dispatch)

1. Go to GitHub → **Actions** → **Build & Push to ECR & Update ECS**
2. Click **Run workflow**
3. Select:
   - **Environment**: dev / qa / stage
   - **Service**: frontend / backend / both
4. Click **Run workflow**
5. Monitor the workflow execution

## Testing the Deployment

### 1. Get External ALB DNS

```bash
aws elbv2 describe-load-balancers \
  --names conde-nast-external-alb-dev \
  --query 'LoadBalancers[0].DNSName' \
  --output text
# Example output: conde-nast-external-alb-dev-123456789.us-east-1.elb.amazonaws.com
```

### 2. Access Frontend

Open in browser: `http://<EXTERNAL_ALB_DNS>`

You should see:
- ✅ Condé Nast Frontend page
- ✅ Environment: Development
- ✅ "Call Backend API" button

### 3. Test Backend Connectivity

Click **"Call Backend API"** button on the frontend:

**Success Response** (if backend is reachable):
```json
{
  "status": "healthy",
  "service": "condé-nast-backend",
  "environment": "development",
  "timestamp": "2026-02-10T12:00:00.000Z",
  "bedrock_configured": true
}
```

**Error Response** (if backend is not reachable):
```
Error: Backend Error: Failed to fetch
Note: Backend must be running at: http://internal-alb:80/api/health
```

### 4. Direct Backend API Calls

Get internal ALB DNS (from ECS console or Terraform outputs):

```bash
# Health check
curl http://<INTERNAL_ALB_DNS>/api/health

# API Info
curl http://<INTERNAL_ALB_DNS>/api/info

# Bedrock invoke (POST)
curl -X POST http://<INTERNAL_ALB_DNS>/api/bedrock/invoke \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Test prompt"}'

# DocumentDB status
curl http://<INTERNAL_ALB_DNS>/api/documentdb/status
```

## Environment Variables

### Frontend (Nginx)
- `ENVIRONMENT` - Set in task definition (e.g., "dev")
- No database connection needed

### Backend (Node.js)
- `PORT` - Service port (default: 8080)
- `ENVIRONMENT` - Deployment environment
- `BEDROCK_MODEL_ARN` - Bedrock model ARN (from Terraform)
- `DOCUMENTDB_ENDPOINT` - DocumentDB connection string (optional)

## Monitoring

### ECS Console

1. Go to **ECS** → **Clusters**
2. Select cluster: `conde-nast-fe-dev` or `conde-nast-be-dev`
3. View:
   - **Services** - Current tasks and desired count
   - **Task** - Health status and logs
   - **CloudWatch Logs** - `/ecs/conde-nast-fe-dev` or `/ecs/conde-nast-be-dev`

### CloudWatch Logs

```bash
# Frontend logs
aws logs tail /ecs/conde-nast-fe-dev --follow

# Backend logs
aws logs tail /ecs/conde-nast-be-dev --follow
```

### Check ECS Service Health

```bash
aws ecs describe-services \
  --cluster conde-nast-fe-dev \
  --services fe-service \
  --query 'services[0].[runningCount,desiredCount,status]' \
  --output text

# Example output: 3  3  ACTIVE
```

## Troubleshooting

### 1. Frontend shows "Error" when calling backend

**Cause**: Backend is not reachable from frontend containers

**Solution**:
- Check backend ECS service status: `aws ecs describe-services --cluster conde-nast-be-dev --services be-service`
- Check security group rules: Backend SG should allow port 8080 from Frontend SG
- Check internal ALB health: Go to EC2 → Load Balancers → Health checks

### 2. Images not updating in ECS

**Cause**: ECS cache is using old image

**Solution**:
```bash
# Force new deployment
aws ecs update-service \
  --cluster conde-nast-fe-dev \
  --service fe-service \
  --force-new-deployment
```

### 3. GitHub Actions workflow fails

**Check**:
- AWS IAM role has permissions: `ecr:PutImage`, `ecs:UpdateService`
- ECR repositories exist with correct names
- ECS clusters and services exist

### 4. Bedrock integration not working

**Check**:
- `bedrock_model_arn` is set in `dev.tfvars`
- Backend IAM role has `bedrock:InvokeModel` permission
- Model ARN is correct and region matches

## Useful Commands

```bash
# View Terraform outputs
cd terraform
terraform output ecr_frontend_repository_url
terraform output ecr_backend_repository_url
terraform output external_alb_dns_name

# Push test image to ECR manually
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com
docker tag conde-nast-frontend:latest <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/conde-nast-frontend-dev:latest
docker push <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/conde-nast-frontend-dev:latest

# Describe task definition
aws ecs describe-task-definition \
  --task-definition conde-nast-fe-service \
  --query 'taskDefinition.containerDefinitions[0].image'
```

## Next Steps

1. ✅ Deploy infrastructure: `terraform apply`
2. ✅ Push code: `git push origin main`
3. ✅ Monitor GitHub Actions workflow
4. ✅ Test frontend: `http://<EXTERNAL_ALB_DNS>`
5. ✅ Check backend: Click "Call Backend API" button
6. ✅ Monitor logs: CloudWatch console or CLI
7. ✅ Iterate: Make code changes and push to main

## Security Notes

- Frontend communicates with backend through internal ALB (no internet exposure)
- Backend only accessible from internal ALB and DocumentDB
- All images use specific tags (git SHA) for version tracking
- Environment secrets are not logged in GitHub Actions
- IAM role uses OIDC (no hardcoded AWS keys)

## Support

For issues, check:
1. ECS Task logs in CloudWatch
2. GitHub Actions workflow logs
3. ALB health checks
4. Security group rules
5. Terraform outputs
