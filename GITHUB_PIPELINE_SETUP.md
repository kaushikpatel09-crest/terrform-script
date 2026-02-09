# GitHub Pipeline Setup - Complete Guide

## Overview

This guide provides everything you need to set up the GitHub Actions pipeline for Terraform deployments.

## 📋 What You Need to Create (Manual Setup)

### 1. AWS S3 Bucket (for Terraform State)

```bash
# Create S3 bucket
aws s3 mb s3://conde-nast-terraform-state --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket conde-nast-terraform-state \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket conde-nast-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket conde-nast-terraform-state \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

**Bucket Name to Remember**: `conde-nast-terraform-state`

### 2. DynamoDB Table (for State Locking)

```bash
# Create DynamoDB table
aws dynamodb create-table \
  --table-name terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

**Table Name to Remember**: `terraform-lock`

### 3. AWS OIDC Provider (for GitHub)

```bash
# Get thumbprint
THUMBPRINT=$(curl -s https://token.actions.githubusercontent.com/.well-known/openid-configuration | jq -r '.jwks_uri' | cut -d'/' -f3 | xargs -I {} curl -s https://{}/certs | jq -r '.keys[0].x5c[0]' | openssl x509 -fingerprint -noout -inform PEM | sed 's/://g' | awk '{print $NF}')

# Create OIDC provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --thumbprint-list $THUMBPRINT \
  --client-id-list sts.amazonaws.com
```

### 4. AWS IAM Role (for GitHub Actions)

**Step A: Create Trust Policy File** (`trust-policy.json`)

Replace:
- `YOUR_ACCOUNT_ID` - Get from: `aws sts get-caller-identity --query Account --output text`
- `YOUR_GITHUB_ORG` - Your GitHub organization or username
- `YOUR_REPO` - Your repository name

```json
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
```

**Example** (if your GitHub org is `kaushikpatel09-crest` and repo is `terrform-script`):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:kaushikpatel09-crest/terrform-script:*"
        }
      }
    }
  ]
}
```

**Step B: Create IAM Role**

```bash
# Create role
aws iam create-role \
  --role-name github-terraform-role \
  --assume-role-policy-document file://trust-policy.json

# Get role ARN (save this!)
aws iam get-role --role-name github-terraform-role --query 'Role.Arn' --output text
```

**Role Name to Remember**: `github-terraform-role`

**Step C: Create IAM Policy** (`terraform-policy.json`)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EC2",
      "Effect": "Allow",
      "Action": [
        "ec2:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ECS",
      "Effect": "Allow",
      "Action": [
        "ecs:*",
        "ecr:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ELB",
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "DocumentDB",
      "Effect": "Allow",
      "Action": [
        "docdb:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Logs",
      "Effect": "Allow",
      "Action": [
        "logs:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CloudWatch",
      "Effect": "Allow",
      "Action": [
        "cloudwatch:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAM",
      "Effect": "Allow",
      "Action": [
        "iam:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "S3",
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "DynamoDB",
      "Effect": "Allow",
      "Action": [
        "dynamodb:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ACM",
      "Effect": "Allow",
      "Action": [
        "acm:*"
      ],
      "Resource": "*"
    }
  ]
}
```

**Step D: Attach Policy to Role**

```bash
# Attach policy
aws iam put-role-policy \
  --role-name github-terraform-role \
  --policy-name terraform-policy \
  --policy-document file://terraform-policy.json

# Verify
aws iam list-attached-role-policies --role-name github-terraform-role
```

---

## 🔐 GitHub Secrets to Configure

Go to your GitHub repository → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

### Required Secrets

Add these 4 secrets exactly as shown:

| Secret Name | Value | Example |
|------------|-------|---------|
| `AWS_ROLE_ARN` | IAM role ARN from step 4B | `arn:aws:iam::123456789012:role/github-terraform-role` |
| `TF_STATE_BUCKET` | S3 bucket name from step 1 | `conde-nast-terraform-state` |
| `TF_LOCK_TABLE` | DynamoDB table name from step 2 | `terraform-lock` |
| `DOCUMENTDB_PASSWORD` | Secure password for DocumentDB | `MySecurePassword123!@#` (minimum 8 chars) |

### How to Add Secrets in GitHub UI

1. Go to: GitHub Repo → **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Enter the secret name (e.g., `AWS_ROLE_ARN`)
4. Enter the secret value
5. Click **Add secret**
6. Repeat for all 4 secrets

---

## 📝 Quick Reference Table

### Manual Setup (Create in AWS)

| Item | Type | Create Command | Value |
|------|------|----------------|-------|
| S3 Bucket | AWS | `aws s3 mb s3://conde-nast-terraform-state` | `conde-nast-terraform-state` |
| DynamoDB Table | AWS | `aws dynamodb create-table ...` | `terraform-lock` |
| OIDC Provider | AWS | `aws iam create-open-id-connect-provider` | `token.actions.githubusercontent.com` |
| IAM Role | AWS | `aws iam create-role ...` | `github-terraform-role` |

### GitHub Secrets (Configure in GitHub UI)

| Secret Name | Where to Get | Store As |
|------------|-------------|----------|
| `AWS_ROLE_ARN` | From IAM role ARN | Full ARN string |
| `TF_STATE_BUCKET` | S3 bucket name | `conde-nast-terraform-state` |
| `TF_LOCK_TABLE` | DynamoDB table name | `terraform-lock` |
| `DOCUMENTDB_PASSWORD` | Create yourself | Your chosen secure password |

---

## 🧪 Testing the Pipeline

### Step 1: Verify Setup

```bash
# Verify S3 bucket exists
aws s3 ls | grep conde-nast-terraform-state

# Verify DynamoDB table exists
aws dynamodb list-tables | grep terraform-lock

# Verify OIDC provider
aws iam list-open-id-connect-providers

# Verify IAM role
aws iam get-role --role-name github-terraform-role
```

### Step 2: Test Workflow

1. Go to GitHub → **Actions** tab
2. Select **Terraform Validation** workflow
3. Click **Run workflow**
4. Wait for completion (should pass validation, formatting, and security checks)

### Step 3: Test Plan

1. Go to GitHub → **Actions** tab
2. Select **Terraform Plan & Apply**
3. Click **Run workflow**
4. Select environment: `dev`
5. Select action: `plan`
6. Click **Run workflow**
7. Monitor the execution and review the plan

---

## 📊 Step-by-Step Setup Summary

### Phase 1: AWS Setup (15 minutes)

```bash
# 1. Get your AWS Account ID
aws sts get-caller-identity --query Account --output text

# 2. Create S3 bucket
aws s3 mb s3://conde-nast-terraform-state --region us-east-1

# 3. Create DynamoDB table
aws dynamodb create-table \
  --table-name terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

# 4. Create OIDC provider
THUMBPRINT=$(curl -s https://token.actions.githubusercontent.com/.well-known/openid-configuration | jq -r '.jwks_uri' | cut -d'/' -f3 | xargs -I {} curl -s https://{}/certs | jq -r '.keys[0].x5c[0]' | openssl x509 -fingerprint -noout -inform PEM | sed 's/://g' | awk '{print $NF}')

aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --thumbprint-list $THUMBPRINT \
  --client-id-list sts.amazonaws.com

# 5. Create IAM role (with trust-policy.json)
aws iam create-role \
  --role-name github-terraform-role \
  --assume-role-policy-document file://trust-policy.json

# 6. Attach policy (with terraform-policy.json)
aws iam put-role-policy \
  --role-name github-terraform-role \
  --policy-name terraform-policy \
  --policy-document file://terraform-policy.json

# 7. Get role ARN (copy this!)
aws iam get-role --role-name github-terraform-role --query 'Role.Arn' --output text
```

### Phase 2: GitHub Setup (10 minutes)

1. Open GitHub repository settings
2. Go to **Secrets and variables** → **Actions**
3. Add 4 secrets:
   - `AWS_ROLE_ARN` = (ARN from step 7 above)
   - `TF_STATE_BUCKET` = `conde-nast-terraform-state`
   - `TF_LOCK_TABLE` = `terraform-lock`
   - `DOCUMENTDB_PASSWORD` = (Your secure password)

### Phase 3: Testing (10 minutes)

1. Run **Terraform Validation** workflow (should pass)
2. Run **Terraform Plan** for dev (should show plan output)
3. You're done! 🎉

---

## 🔍 What Each Secret/Variable Does

### `AWS_ROLE_ARN`
- **Purpose**: Tells GitHub which AWS IAM role to assume
- **Used by**: GitHub Actions OIDC authentication
- **Example**: `arn:aws:iam::123456789012:role/github-terraform-role`
- **Why needed**: Secure authentication without hardcoded AWS keys

### `TF_STATE_BUCKET`
- **Purpose**: S3 bucket to store Terraform state
- **Used by**: Terraform backend configuration
- **Example**: `conde-nast-terraform-state`
- **Why needed**: Persistent infrastructure state across deployments

### `TF_LOCK_TABLE`
- **Purpose**: DynamoDB table for state locking
- **Used by**: Terraform to prevent concurrent modifications
- **Example**: `terraform-lock`
- **Why needed**: Prevents corruption when multiple people deploy simultaneously

### `DOCUMENTDB_PASSWORD`
- **Purpose**: Master password for DocumentDB cluster
- **Used by**: Terraform to create DocumentDB
- **Example**: `MySecurePassword123!@#`
- **Why needed**: Required for DocumentDB cluster initialization
- **Requirements**: 
  - Minimum 8 characters
  - Must contain letters, numbers, and special characters
  - Cannot contain certain special characters like quotes

---

## 🐛 Troubleshooting

### Error: "Failed to assume role"

**Cause**: AWS_ROLE_ARN is incorrect or OIDC provider not configured
**Solution**: 
```bash
# Verify OIDC provider exists
aws iam list-open-id-connect-providers

# Verify role exists
aws iam get-role --role-name github-terraform-role

# Check role trust policy
aws iam get-role --role-name github-terraform-role --query 'Role.AssumeRolePolicyDocument'
```

### Error: "Access Denied on S3"

**Cause**: IAM policy missing S3 permissions or bucket name wrong
**Solution**:
```bash
# Verify bucket exists
aws s3 ls | grep conde-nast-terraform-state

# Check IAM policy has S3 permissions
aws iam get-role-policy --role-name github-terraform-role --policy-name terraform-policy
```

### Error: "Unable to acquire state lock"

**Cause**: DynamoDB table doesn't exist or wrong table name
**Solution**:
```bash
# Verify table exists
aws dynamodb list-tables | grep terraform-lock

# Check table structure
aws dynamodb describe-table --table-name terraform-lock
```

### Error: "Invalid DocumentDB password"

**Cause**: Password doesn't meet requirements
**Solution**: Password must:
- Be at least 8 characters long
- Contain uppercase letters (A-Z)
- Contain lowercase letters (a-z)
- Contain numbers (0-9)
- Contain special characters (!@#$%^&*)

Example: `MySecurePass123!`

---

## 🔄 Running the Pipeline

### From GitHub UI

1. **Go to Actions tab** in your GitHub repository
2. **Select workflow**: "Terraform Plan & Apply"
3. **Click "Run workflow"**
4. **Select inputs**:
   - Environment: `dev`, `qa`, or `stage`
   - Action: `plan`, `apply`, or `destroy`
5. **Click "Run workflow"**
6. **Monitor execution** in the workflow logs

### Environment Dropdown Options

- **dev**: Development environment (minimal resources, ~$155/month)
- **qa**: QA environment (medium resources, ~$305/month)
- **stage**: Stage environment (production resources, ~$365/month)

### Action Dropdown Options

- **plan**: Create and review the plan (no changes to AWS)
- **apply**: Apply the plan (creates/updates AWS resources)
- **destroy**: Destroy all resources (deletes everything!)

---

## 📋 Checklist

Before running the pipeline, verify:

- [ ] S3 bucket created: `conde-nast-terraform-state`
- [ ] DynamoDB table created: `terraform-lock`
- [ ] OIDC provider created in AWS IAM
- [ ] IAM role created: `github-terraform-role`
- [ ] IAM policy attached to role
- [ ] GitHub secret `AWS_ROLE_ARN` added (with correct value)
- [ ] GitHub secret `TF_STATE_BUCKET` added (= `conde-nast-terraform-state`)
- [ ] GitHub secret `TF_LOCK_TABLE` added (= `terraform-lock`)
- [ ] GitHub secret `DOCUMENTDB_PASSWORD` added (secure password)
- [ ] Validation workflow passed
- [ ] Ready to run plan/apply workflows

---

## 🎯 Next Steps

1. **Run AWS setup commands** (Phase 1 above)
2. **Add GitHub secrets** (Phase 2 above)
3. **Test validation workflow** (Phase 3 above)
4. **Run plan for dev environment**
5. **Review plan output**
6. **Run apply to deploy infrastructure**
7. **Monitor CloudWatch logs**
8. **Test deployed application**

---

## 📞 Common Questions

**Q: Do I need to store AWS access keys?**
A: No! We use OIDC authentication, which is more secure.

**Q: Can I use different S3 bucket/DynamoDB names?**
A: Yes, just make sure the GitHub secret values match the AWS resource names.

**Q: What if I forget the DocumentDB password?**
A: You'll need to destroy the DocumentDB cluster and redeploy, or manually change it in AWS.

**Q: Can multiple people deploy at the same time?**
A: No, DynamoDB locking prevents concurrent modifications. One person's workflow blocks others.

**Q: How long does deployment take?**
A: First deployment: 20-30 minutes. Updates: 5-10 minutes.

---

**Setup Complete!** You're now ready to deploy infrastructure via GitHub Actions. 🚀
