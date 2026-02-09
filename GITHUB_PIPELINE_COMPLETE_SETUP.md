# Complete GitHub Pipeline Setup Summary

## ⚡ TL;DR - What You Need to Do

### Manual AWS Setup (One Time)
1. ✅ Create S3 bucket: `conde-nast-terraform-state`
2. ✅ Create DynamoDB table: `terraform-lock`
3. ✅ Create AWS OIDC provider
4. ✅ Create IAM role: `github-terraform-role`
5. ✅ Attach IAM policy

### GitHub Secrets (One Time)
Add 4 secrets to your GitHub repository:
- `AWS_ROLE_ARN` = Your IAM role ARN
- `TF_STATE_BUCKET` = `conde-nast-terraform-state`
- `TF_LOCK_TABLE` = `terraform-lock`
- `DOCUMENTDB_PASSWORD` = Your chosen secure password

### Then You're Done!
Use GitHub Actions anytime to deploy.

---

## 📋 Detailed Step-by-Step

### Phase 1: AWS Setup (15 minutes)

**1. Get your AWS Account ID:**
```bash
aws sts get-caller-identity --query Account --output text
```
Save this 12-digit number.

**2. Create S3 Bucket for state:**
```bash
aws s3 mb s3://conde-nast-terraform-state --region us-east-1
aws s3api put-bucket-versioning --bucket conde-nast-terraform-state --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket conde-nast-terraform-state --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-public-access-block --bucket conde-nast-terraform-state --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

**3. Create DynamoDB Table for locking:**
```bash
aws dynamodb create-table --table-name terraform-lock --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST --region us-east-1
```

**4. Create OIDC Provider:**
```bash
THUMBPRINT=$(curl -s https://token.actions.githubusercontent.com/.well-known/openid-configuration | jq -r '.jwks_uri' | cut -d'/' -f3 | xargs -I {} curl -s https://{}/certs | jq -r '.keys[0].x5c[0]' | openssl x509 -fingerprint -noout -inform PEM | sed 's/://g' | awk '{print $NF}')
aws iam create-open-id-connect-provider --url https://token.actions.githubusercontent.com --thumbprint-list $THUMBPRINT --client-id-list sts.amazonaws.com
```

**5. Create Trust Policy file (`trust-policy.json`):**

Replace these:
- `YOUR_ACCOUNT_ID` with the number from step 1
- `YOUR_GITHUB_ORG` with your GitHub org (e.g., `kaushikpatel09-crest`)
- `YOUR_REPO` with your repo name (e.g., `terrform-script`)

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

**6. Create IAM Role:**
```bash
aws iam create-role --role-name github-terraform-role --assume-role-policy-document file://trust-policy.json
```

**7. Create Terraform Policy file (`terraform-policy.json`):**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {"Sid": "EC2", "Effect": "Allow", "Action": ["ec2:*"], "Resource": "*"},
    {"Sid": "ECS", "Effect": "Allow", "Action": ["ecs:*", "ecr:*"], "Resource": "*"},
    {"Sid": "ELB", "Effect": "Allow", "Action": ["elasticloadbalancing:*"], "Resource": "*"},
    {"Sid": "DocumentDB", "Effect": "Allow", "Action": ["docdb:*"], "Resource": "*"},
    {"Sid": "Logs", "Effect": "Allow", "Action": ["logs:*"], "Resource": "*"},
    {"Sid": "CloudWatch", "Effect": "Allow", "Action": ["cloudwatch:*"], "Resource": "*"},
    {"Sid": "IAM", "Effect": "Allow", "Action": ["iam:*"], "Resource": "*"},
    {"Sid": "S3", "Effect": "Allow", "Action": ["s3:*"], "Resource": "*"},
    {"Sid": "DynamoDB", "Effect": "Allow", "Action": ["dynamodb:*"], "Resource": "*"},
    {"Sid": "ACM", "Effect": "Allow", "Action": ["acm:*"], "Resource": "*"}
  ]
}
```

**8. Attach Policy to Role:**
```bash
aws iam put-role-policy --role-name github-terraform-role --policy-name terraform-policy --policy-document file://terraform-policy.json
```

**9. Get Role ARN (SAVE THIS!):**
```bash
aws iam get-role --role-name github-terraform-role --query 'Role.Arn' --output text
```

Output should be like: `arn:aws:iam::123456789012:role/github-terraform-role`

---

### Phase 2: GitHub Setup (10 minutes)

**Steps:**
1. Open your GitHub repository
2. Go to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** for each:

| Secret Name | Value |
|------------|-------|
| `AWS_ROLE_ARN` | Paste the ARN from Phase 1, Step 9 |
| `TF_STATE_BUCKET` | `conde-nast-terraform-state` |
| `TF_LOCK_TABLE` | `terraform-lock` |
| `DOCUMENTDB_PASSWORD` | Create a password (min 8 chars, needs uppercase, lowercase, numbers, special chars) |

---

## 🔍 Verification Checklist

Run these to verify everything works:

```bash
# Verify S3 bucket exists and is encrypted
aws s3 ls | grep conde-nast-terraform-state
aws s3api get-bucket-encryption --bucket conde-nast-terraform-state

# Verify DynamoDB table exists
aws dynamodb list-tables | grep terraform-lock
aws dynamodb describe-table --table-name terraform-lock

# Verify OIDC provider exists
aws iam list-open-id-connect-providers

# Verify IAM role and policy
aws iam get-role --role-name github-terraform-role
aws iam get-role-policy --role-name github-terraform-role --policy-name terraform-policy

# Verify GitHub secrets are set (should show 4 secrets)
# Go to GitHub UI: Settings → Secrets and variables → Actions
```

---

## 🚀 Test the Pipeline

**Test 1: Run Validation Workflow**
1. Go to GitHub → **Actions**
2. Click **Terraform Validation**
3. Click **Run workflow**
4. Should pass (validates code)

**Test 2: Run Plan Workflow**
1. Go to GitHub → **Actions**
2. Click **Terraform Plan & Apply**
3. Click **Run workflow**
4. Select Environment: `dev`
5. Select Action: `plan`
6. Click **Run workflow**
7. Should show plan (no changes made to AWS)

**Test 3: Run Apply Workflow (CREATES RESOURCES)**
1. Go to GitHub → **Actions**
2. Click **Terraform Plan & Apply**
3. Click **Run workflow**
4. Select Environment: `dev`
5. Select Action: `apply`
6. Click **Run workflow**
7. Should create ~60 AWS resources
8. Check AWS Console to verify

---

## 📊 Summary Table

### AWS Resources You're Creating

| Resource | Name | Purpose |
|----------|------|---------|
| S3 Bucket | `conde-nast-terraform-state` | Stores Terraform state |
| DynamoDB Table | `terraform-lock` | Prevents concurrent changes |
| OIDC Provider | `token.actions.githubusercontent.com` | Authenticates GitHub to AWS |
| IAM Role | `github-terraform-role` | GitHub assumes this role |
| IAM Policy | `terraform-policy` | Allows GitHub to manage AWS |

### GitHub Secrets You're Storing

| Secret | Example | Used For |
|--------|---------|----------|
| `AWS_ROLE_ARN` | `arn:aws:iam::123456789012:role/github-terraform-role` | Authentication |
| `TF_STATE_BUCKET` | `conde-nast-terraform-state` | State storage location |
| `TF_LOCK_TABLE` | `terraform-lock` | Lock table location |
| `DOCUMENTDB_PASSWORD` | `MyPass123!@#` | Database password |

---

## 💡 Important Notes

1. **S3 bucket names are globally unique** - If someone else already created `conde-nast-terraform-state`, you need a different name like `conde-nast-terraform-state-yourcompany`

2. **DocumentDB password requirements**:
   - Minimum 8 characters
   - Must include: uppercase (A-Z), lowercase (a-z), numbers (0-9), special chars (!@#$%)
   - Example: `TerraForm123!@#`

3. **GitHub Secrets are secure** - Once saved, you can't see them again. Save them somewhere safe!

4. **OIDC is more secure than access keys** - No AWS credentials are stored in GitHub

5. **State locking prevents corruption** - DynamoDB ensures only one person can deploy at a time

---

## 🔄 Using the Pipeline (After Setup)

Once configured, you'll just:
1. Go to GitHub → **Actions**
2. Select **Terraform Plan & Apply**
3. Click **Run workflow**
4. Choose environment (dev/qa/stage)
5. Choose action (plan/apply/destroy)
6. Watch it deploy!

No more manual commands needed!

---

## 📞 Troubleshooting

| Problem | Solution |
|---------|----------|
| "Failed to assume role" | Check AWS_ROLE_ARN secret value is correct |
| "Access Denied on S3" | Verify bucket name in TF_STATE_BUCKET secret |
| "Unable to acquire lock" | Verify DynamoDB table exists: `aws dynamodb list-tables` |
| "Invalid DocumentDB password" | Must be 8+ chars with uppercase, lowercase, numbers, special chars |
| "OIDC provider not found" | Re-run the OIDC creation command in Phase 1 |

---

## ✅ Checklist Before First Deploy

- [ ] Completed Phase 1 AWS Setup
- [ ] Completed Phase 2 GitHub Secrets
- [ ] Verified all AWS resources exist
- [ ] Verified all 4 GitHub secrets are set
- [ ] Ran Terraform Validation workflow (passed)
- [ ] Ran Terraform Plan workflow (reviewed plan)
- [ ] Ready to run Apply workflow

---

**You're all set! Ready to deploy via GitHub Actions!** 🎉

For detailed guides, see:
- `GITHUB_PIPELINE_SETUP.md` - Complete setup guide
- `PIPELINE_QUICK_SETUP.md` - Quick reference with all commands
