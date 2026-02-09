# GitHub Pipeline Setup - Quick Reference Card

## 📝 All Commands You Need (Copy & Paste)

### Step 1: Get Your AWS Account ID
```bash
aws sts get-caller-identity --query Account --output text
```
**Save this number!** You'll need it in the next steps.

---

### Step 2: Create S3 Bucket
```bash
aws s3 mb s3://conde-nast-terraform-state --region us-east-1

aws s3api put-bucket-versioning \
  --bucket conde-nast-terraform-state \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket conde-nast-terraform-state \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws s3api put-public-access-block \
  --bucket conde-nast-terraform-state \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

---

### Step 3: Create DynamoDB Table
```bash
aws dynamodb create-table \
  --table-name terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

---

### Step 4: Create OIDC Provider
```bash
THUMBPRINT=$(curl -s https://token.actions.githubusercontent.com/.well-known/openid-configuration | jq -r '.jwks_uri' | cut -d'/' -f3 | xargs -I {} curl -s https://{}/certs | jq -r '.keys[0].x5c[0]' | openssl x509 -fingerprint -noout -inform PEM | sed 's/://g' | awk '{print $NF}')

aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --thumbprint-list $THUMBPRINT \
  --client-id-list sts.amazonaws.com
```

---

### Step 5: Create Trust Policy File

Create a file named `trust-policy.json` with this content:

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

**Replace these values:**
- `YOUR_ACCOUNT_ID` → The number you saved in Step 1
- `YOUR_GITHUB_ORG` → Your GitHub organization (e.g., `kaushikpatel09-crest`)
- `YOUR_REPO` → Your repo name (e.g., `terrform-script`)

---

### Step 6: Create IAM Role

```bash
aws iam create-role \
  --role-name github-terraform-role \
  --assume-role-policy-document file://trust-policy.json
```

**Save the Role ARN that appears!** You'll need it for GitHub secrets.

---

### Step 7: Create Terraform Policy File

Create a file named `terraform-policy.json` with this content:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EC2",
      "Effect": "Allow",
      "Action": ["ec2:*"],
      "Resource": "*"
    },
    {
      "Sid": "ECS",
      "Effect": "Allow",
      "Action": ["ecs:*", "ecr:*"],
      "Resource": "*"
    },
    {
      "Sid": "ELB",
      "Effect": "Allow",
      "Action": ["elasticloadbalancing:*"],
      "Resource": "*"
    },
    {
      "Sid": "DocumentDB",
      "Effect": "Allow",
      "Action": ["docdb:*"],
      "Resource": "*"
    },
    {
      "Sid": "Logs",
      "Effect": "Allow",
      "Action": ["logs:*"],
      "Resource": "*"
    },
    {
      "Sid": "CloudWatch",
      "Effect": "Allow",
      "Action": ["cloudwatch:*"],
      "Resource": "*"
    },
    {
      "Sid": "IAM",
      "Effect": "Allow",
      "Action": ["iam:*"],
      "Resource": "*"
    },
    {
      "Sid": "S3",
      "Effect": "Allow",
      "Action": ["s3:*"],
      "Resource": "*"
    },
    {
      "Sid": "DynamoDB",
      "Effect": "Allow",
      "Action": ["dynamodb:*"],
      "Resource": "*"
    },
    {
      "Sid": "ACM",
      "Effect": "Allow",
      "Action": ["acm:*"],
      "Resource": "*"
    }
  ]
}
```

---

### Step 8: Attach Policy to Role

```bash
aws iam put-role-policy \
  --role-name github-terraform-role \
  --policy-name terraform-policy \
  --policy-document file://terraform-policy.json
```

---

### Step 9: Get Role ARN for GitHub

```bash
aws iam get-role --role-name github-terraform-role --query 'Role.Arn' --output text
```

**Copy the output!** It should look like: `arn:aws:iam::123456789012:role/github-terraform-role`

---

## 🔐 GitHub Secrets to Add

Go to GitHub → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add these 4 secrets:

| Secret Name | Value |
|------------|-------|
| `AWS_ROLE_ARN` | (From Step 9) e.g., `arn:aws:iam::123456789012:role/github-terraform-role` |
| `TF_STATE_BUCKET` | `conde-nast-terraform-state` |
| `TF_LOCK_TABLE` | `terraform-lock` |
| `DOCUMENTDB_PASSWORD` | Your secure password (min 8 chars with uppercase, lowercase, numbers, special chars) |

---

## ✅ Verification Commands

Run these to verify everything is set up correctly:

```bash
# Check S3 bucket
aws s3 ls | grep conde-nast-terraform-state

# Check DynamoDB table
aws dynamodb list-tables | grep terraform-lock

# Check OIDC provider
aws iam list-open-id-connect-providers

# Check IAM role
aws iam get-role --role-name github-terraform-role

# Check role policy
aws iam get-role-policy --role-name github-terraform-role --policy-name terraform-policy
```

---

## 🚀 Run Pipeline from GitHub

1. Go to GitHub → **Actions** tab
2. Select **Terraform Plan & Apply**
3. Click **Run workflow**
4. Select:
   - Environment: `dev` (for first test)
   - Action: `plan`
5. Click **Run workflow**
6. Wait for completion and review plan

---

## 📊 What Gets Created

### AWS Resources Created:
- **S3 Bucket**: `conde-nast-terraform-state` (stores Terraform state)
- **DynamoDB Table**: `terraform-lock` (prevents concurrent changes)
- **OIDC Provider**: For GitHub authentication
- **IAM Role**: `github-terraform-role` (GitHub assumes this)
- **IAM Policy**: `terraform-policy` (allows GitHub to manage AWS resources)

### Infrastructure Deployed (via Pipeline):
- VPC with 1 public and 3 private subnets
- NAT Gateway
- ECS clusters (Frontend + Backend)
- Load Balancers (External + Internal)
- DocumentDB cluster
- CloudWatch logs
- Security groups
- Auto-scaling groups

---

## 💡 Tips

- **S3 bucket name must be globally unique** - If `conde-nast-terraform-state` is taken, add a suffix like `-yourname`
- **DocumentDB password requirements**:
  - Minimum 8 characters
  - Must contain: uppercase, lowercase, numbers, special characters
  - Example: `TerraForm123!@#`
- **GitHub secrets are encrypted** - You can't see them after creation
- **OIDC is more secure than access keys** - No AWS keys stored in GitHub
- **State locking prevents corruption** - DynamoDB prevents two people deploying at same time

---

## 🔄 Once Configured

You won't need to do this again! Just:
1. Go to Actions in GitHub
2. Select Terraform workflow
3. Choose environment (dev/qa/stage)
4. Choose action (plan/apply/destroy)
5. Watch it deploy!

---

**That's it! You're all set up!** 🎉
