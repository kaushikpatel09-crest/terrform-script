# 📝 GitHub Pipeline Setup - Visual Summary

## What You Need to Create (Manual AWS Setup)

```
┌─────────────────────────────────────────────────────────────────┐
│                     AWS SETUP (DO MANUALLY)                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. S3 BUCKET (Terraform State Storage)                        │
│     └─ Name: conde-nast-terraform-state                        │
│     └─ Encryption: AES256 (enabled)                            │
│     └─ Versioning: Enabled                                     │
│     └─ Public Access: Blocked                                  │
│                                                                 │
│  2. DYNAMODB TABLE (State Locking)                             │
│     └─ Name: terraform-lock                                    │
│     └─ Primary Key: LockID                                     │
│     └─ Billing: Pay-per-request                                │
│                                                                 │
│  3. OIDC PROVIDER (GitHub Authentication)                      │
│     └─ URL: token.actions.githubusercontent.com               │
│     └─ Client ID: sts.amazonaws.com                            │
│                                                                 │
│  4. IAM ROLE (GitHub Permission)                               │
│     └─ Name: github-terraform-role                             │
│     └─ Trust: GitHub OIDC Provider                             │
│     └─ Policy: Full access to AWS services                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## GitHub Secrets to Store (Configure in GitHub UI)

```
┌──────────────────────────────────────────────────────────────────┐
│           GITHUB SECRETS (Settings → Secrets)                    │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  SECRET 1: AWS_ROLE_ARN                                         │
│  ├─ Value: arn:aws:iam::123456789012:role/github-terraform-role│
│  └─ From: AWS IAM Role created above                            │
│                                                                  │
│  SECRET 2: TF_STATE_BUCKET                                      │
│  ├─ Value: conde-nast-terraform-state                           │
│  └─ From: S3 Bucket created above                               │
│                                                                  │
│  SECRET 3: TF_LOCK_TABLE                                        │
│  ├─ Value: terraform-lock                                       │
│  └─ From: DynamoDB Table created above                          │
│                                                                  │
│  SECRET 4: DOCUMENTDB_PASSWORD                                  │
│  ├─ Value: YourSecurePassword123!                               │
│  ├─ Requirements:                                               │
│  │  - Minimum 8 characters                                      │
│  │  - Uppercase letter (A-Z)                                    │
│  │  - Lowercase letter (a-z)                                    │
│  │  - Number (0-9)                                              │
│  │  - Special character (!@#$%^&*)                              │
│  └─ Example: MyTerraform123!@#                                  │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

## Data Flow Diagram

```
                    ┌─────────────┐
                    │   GitHub    │
                    │  Repository │
                    └──────┬──────┘
                           │
                           │ Push/Run Workflow
                           ▼
                    ┌─────────────────┐
                    │  GitHub Actions │
                    │    Workflow     │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  Assume AWS IAM │
                    │ Role (via OIDC)  │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
    ┌─────────┐         ┌─────────┐        ┌────────────┐
    │    S3   │         │DynamoDB │        │   AWS API  │
    │ Bucket  │         │  Table  │        │  (Create   │
    │(State)  │         │(Locking)│        │Resources)  │
    └─────────┘         └─────────┘        └────────────┘
```

## Setup Process Flow

```
START HERE
    │
    ├─→ Step 1: Get AWS Account ID
    │   └─→ Save 12-digit number
    │
    ├─→ Step 2: Create S3 Bucket
    │   └─→ For Terraform state storage
    │
    ├─→ Step 3: Create DynamoDB Table
    │   └─→ For state locking
    │
    ├─→ Step 4: Create OIDC Provider
    │   └─→ For GitHub authentication
    │
    ├─→ Step 5: Create Trust Policy File
    │   └─→ With AWS Account ID, GitHub Org, Repo Name
    │
    ├─→ Step 6: Create IAM Role
    │   └─→ Save the Role ARN
    │
    ├─→ Step 7: Create IAM Policy File
    │   └─→ With all AWS permissions
    │
    ├─→ Step 8: Attach Policy to Role
    │   └─→ Linking policy to role
    │
    ├─→ Step 9: Get Role ARN
    │   └─→ For GitHub secret
    │
    ├─→ Step 10: Add 4 Secrets to GitHub
    │   ├─→ AWS_ROLE_ARN
    │   ├─→ TF_STATE_BUCKET
    │   ├─→ TF_LOCK_TABLE
    │   └─→ DOCUMENTDB_PASSWORD
    │
    └─→ Step 11: Test Pipeline
        └─→ Run validation workflow
        └─→ Run plan workflow
        └─→ Ready to deploy!
```

## AWS Resources Created

```
AWS ACCOUNT
│
├─ S3 BUCKET: conde-nast-terraform-state
│  ├─ Versioning: Enabled
│  ├─ Encryption: AES256
│  ├─ Public Access: Blocked
│  └─ Purpose: Store Terraform state files
│
├─ DYNAMODB TABLE: terraform-lock
│  ├─ Primary Key: LockID
│  ├─ Billing: Pay-per-request
│  └─ Purpose: Lock state during deployments
│
├─ IAM OIDC PROVIDER
│  ├─ URL: token.actions.githubusercontent.com
│  └─ Purpose: Allow GitHub to authenticate
│
└─ IAM ROLE: github-terraform-role
   ├─ Trust Policy: GitHub OIDC
   ├─ Permissions: Full AWS access
   └─ Purpose: GitHub Actions can manage AWS
```

## GitHub Configuration

```
GITHUB REPOSITORY
│
└─ Settings
   │
   └─ Secrets and variables
      │
      └─ Actions
         │
         ├─ AWS_ROLE_ARN
         │  └─ arn:aws:iam::123456789012:role/github-terraform-role
         │
         ├─ TF_STATE_BUCKET
         │  └─ conde-nast-terraform-state
         │
         ├─ TF_LOCK_TABLE
         │  └─ terraform-lock
         │
         └─ DOCUMENTDB_PASSWORD
            └─ MyTerraform123!@#
```

## Workflow Execution Flow

```
GitHub Actions Workflow Triggered
           │
           ├─→ Read Secrets from GitHub
           │
           ├─→ Configure AWS Credentials
           │   └─→ Assume github-terraform-role
           │
           ├─→ Setup Terraform
           │
           ├─→ Initialize Terraform Backend
           │   └─→ Connect to S3 bucket
           │   └─→ Enable DynamoDB locking
           │
           ├─→ Validate Terraform Code
           │
           ├─→ Create/Review Plan
           │   └─→ OR Apply Changes
           │   └─→ OR Destroy Resources
           │
           └─→ Report Results to GitHub
```

## Quick Reference Card

```
┌────────────────────────────────────────────────────────────┐
│             WHAT TO STORE WHERE                            │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  AWS RESOURCES (Create Once)                              │
│  ├─ S3 Bucket: conde-nast-terraform-state                 │
│  ├─ DynamoDB Table: terraform-lock                        │
│  ├─ OIDC Provider: token.actions.githubusercontent.com     │
│  └─ IAM Role: github-terraform-role                       │
│                                                            │
│  GITHUB SECRETS (Store 4 Values)                          │
│  ├─ AWS_ROLE_ARN: (from IAM role)                         │
│  ├─ TF_STATE_BUCKET: conde-nast-terraform-state           │
│  ├─ TF_LOCK_TABLE: terraform-lock                         │
│  └─ DOCUMENTDB_PASSWORD: (your password)                  │
│                                                            │
│  DON'T STORE IN CODE                                      │
│  ├─ AWS credentials (Access Key/Secret Key)               │
│  ├─ Passwords (except via secrets)                        │
│  ├─ Private keys                                          │
│  └─ API tokens                                            │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

## Timeline

```
Total Setup Time: ~25-30 minutes

Phase 1: AWS Setup (15 minutes)
├─ Step 1: Get Account ID (1 min)
├─ Step 2: Create S3 bucket (2 min)
├─ Step 3: Create DynamoDB table (2 min)
├─ Step 4: Create OIDC provider (3 min)
├─ Step 5-6: Create files and IAM role (3 min)
├─ Step 7-8: Create policy and attach (2 min)
└─ Step 9: Get Role ARN (1 min)

Phase 2: GitHub Setup (10 minutes)
└─ Add 4 secrets to GitHub (10 min)

Phase 3: Testing (5 minutes)
├─ Run validation workflow (2 min)
├─ Run plan workflow (2 min)
└─ Verify success (1 min)

TOTAL: ~30 minutes ⏱️
```

## Success Criteria

```
✅ AWS Resources Created
   ├─ S3 bucket exists
   ├─ DynamoDB table exists
   ├─ OIDC provider exists
   └─ IAM role has policy attached

✅ GitHub Secrets Stored
   ├─ AWS_ROLE_ARN set
   ├─ TF_STATE_BUCKET set
   ├─ TF_LOCK_TABLE set
   └─ DOCUMENTDB_PASSWORD set

✅ Workflows Pass
   ├─ Terraform Validation workflow passes
   ├─ Terraform Plan workflow shows plan
   └─ Terraform Apply workflow creates resources

✅ Ready to Deploy
   └─ Now use GitHub Actions for all deployments!
```

## Next Steps After Setup

```
1. Run Validation Workflow
   GitHub → Actions → Terraform Validation → Run workflow
   └─ Should pass validation

2. Run Plan for Dev
   GitHub → Actions → Terraform Plan & Apply
   → Select: dev + plan
   → Review the plan output

3. Run Apply for Dev
   GitHub → Actions → Terraform Plan & Apply
   → Select: dev + apply
   → Wait 20-30 minutes for deployment

4. Verify in AWS
   ✅ Check VPC created
   ✅ Check ECS clusters running
   ✅ Check Load Balancers
   ✅ Check DocumentDB online

5. Test Application
   ✅ Get External ALB DNS name
   ✅ Test HTTP endpoint
   ✅ Check CloudWatch logs
```

---

**See these files for detailed setup:**
- `GITHUB_PIPELINE_COMPLETE_SETUP.md` - Full step-by-step
- `PIPELINE_QUICK_SETUP.md` - All commands to copy/paste
- `GITHUB_PIPELINE_SETUP.md` - Troubleshooting and Q&A
