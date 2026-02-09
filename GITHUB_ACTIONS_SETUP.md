# GitHub Actions Setup Guide

## Prerequisites

- GitHub repository with admin access
- AWS account with appropriate IAM permissions
- S3 bucket and DynamoDB table for Terraform state

## Step 1: Create S3 Bucket and DynamoDB Table

### S3 Bucket
```bash
# Create bucket
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

# Block public access
aws s3api put-public-access-block \
  --bucket your-terraform-state-bucket \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

### DynamoDB Table
```bash
aws dynamodb create-table \
  --table-name terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

## Step 2: Setup AWS OIDC Provider

### Enable GitHub OIDC in AWS
```bash
# Get the OIDC provider thumbprint
THUMBPRINT=$(curl -s https://token.actions.githubusercontent.com/.well-known/openid-configuration | jq -r '.jwks_uri' | cut -d'/' -f3 | xargs -I {} curl -s https://{}/certs | jq -r '.keys[0].x5c[0]' | openssl x509 -fingerprint -noout -inform PEM | sed 's/://g' | awk '{print $NF}')

# Create OIDC provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --thumbprint-list $THUMBPRINT \
  --client-id-list sts.amazonaws.com
```

## Step 3: Create IAM Role for GitHub Actions

### Create Trust Policy
```bash
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
```

Replace:
- `YOUR_ACCOUNT_ID`: Your AWS Account ID
- `YOUR_GITHUB_ORG`: Your GitHub organization
- `YOUR_REPO`: Your repository name

### Create IAM Role
```bash
aws iam create-role \
  --role-name github-terraform-role \
  --assume-role-policy-document file://trust-policy.json

# Record the Role ARN
aws iam get-role --role-name github-terraform-role --query 'Role.Arn' --output text
```

### Create and Attach Policy
```bash
cat > terraform-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EC2Permissions",
      "Effect": "Allow",
      "Action": [
        "ec2:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "VPCPermissions",
      "Effect": "Allow",
      "Action": [
        "ec2:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ECSPermissions",
      "Effect": "Allow",
      "Action": [
        "ecs:*",
        "ecr:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ELBPermissions",
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "DocumentDBPermissions",
      "Effect": "Allow",
      "Action": [
        "docdb:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "LogsPermissions",
      "Effect": "Allow",
      "Action": [
        "logs:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CloudWatchPermissions",
      "Effect": "Allow",
      "Action": [
        "cloudwatch:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMPermissions",
      "Effect": "Allow",
      "Action": [
        "iam:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "S3Permissions",
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "DynamoDBPermissions",
      "Effect": "Allow",
      "Action": [
        "dynamodb:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ACMPermissions",
      "Effect": "Allow",
      "Action": [
        "acm:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name github-terraform-role \
  --policy-name terraform-policy \
  --policy-document file://terraform-policy.json
```

## Step 4: Add GitHub Secrets

In your GitHub repository:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Create the following secrets:

### Required Secrets
- **AWS_ROLE_ARN**: The ARN of the IAM role created above
- **TF_STATE_BUCKET**: The S3 bucket name for Terraform state
- **TF_LOCK_TABLE**: The DynamoDB table name for state locking
- **DOCUMENTDB_PASSWORD**: A secure password for DocumentDB

### Example
```
AWS_ROLE_ARN=arn:aws:iam::123456789012:role/github-terraform-role
TF_STATE_BUCKET=my-terraform-state-bucket
TF_LOCK_TABLE=terraform-lock
DOCUMENTDB_PASSWORD=SecurePassword123!@#
```

## Step 5: Verify Setup

### Run Test Workflow
1. Go to **Actions** tab in your GitHub repository
2. Select **Terraform Validation**
3. Click **Run workflow**
4. Verify it completes successfully

### Troubleshooting Workflow

If the workflow fails:

1. **Check GitHub Secrets**: Verify all secrets are set correctly
   ```bash
   # In GitHub UI, check Settings → Secrets and variables → Actions
   ```

2. **Check AWS IAM Role**:
   ```bash
   # Verify role exists
   aws iam get-role --role-name github-terraform-role
   
   # Check attached policies
   aws iam list-attached-role-policies --role-name github-terraform-role
   ```

3. **Check OIDC Provider**:
   ```bash
   # List OIDC providers
   aws iam list-open-id-connect-providers
   ```

4. **Check S3 Bucket**:
   ```bash
   # Verify bucket exists
   aws s3 ls s3://your-terraform-state-bucket
   
   # Verify encryption
   aws s3api get-bucket-encryption --bucket your-terraform-state-bucket
   ```

5. **Check DynamoDB Table**:
   ```bash
   # Verify table exists
   aws dynamodb describe-table --table-name terraform-lock
   ```

## Step 6: Running Deployments

### Via GitHub UI (Recommended)

1. Go to **Actions** → **Terraform Plan & Apply**
2. Click **Run workflow**
3. Select environment:
   - dev
   - qa
   - stage
4. Select action:
   - **plan**: Review changes without applying
   - **apply**: Apply the changes
   - **destroy**: Destroy resources
5. Click **Run workflow**
6. Monitor the workflow execution

### Via GitHub CLI

```bash
# Plan deployment to dev
gh workflow run terraform.yml \
  -f environment=dev \
  -f action=plan

# Apply deployment to dev
gh workflow run terraform.yml \
  -f environment=dev \
  -f action=apply

# Destroy dev environment
gh workflow run terraform.yml \
  -f environment=dev \
  -f action=destroy
```

## Step 7: Monitoring

### Workflow Runs
1. Go to **Actions** tab
2. Select the workflow
3. View run history and logs
4. Download artifacts (Terraform plan files)

### Terraform State
```bash
# List all resources
aws s3 ls s3://your-terraform-state-bucket

# View specific environment state
aws s3 cp s3://your-terraform-state-bucket/dev/terraform.tfstate . --sse AES256
```

## Security Best Practices

1. **IAM Role Restrictions**:
   - Limit to only necessary permissions
   - Use resource ARNs instead of wildcards where possible
   - Review permissions quarterly

2. **Secrets Management**:
   - Never commit secrets to git
   - Rotate DocumentDB password regularly
   - Use AWS Secrets Manager for runtime secrets

3. **State Management**:
   - Enable S3 bucket versioning
   - Enable bucket encryption
   - Block public access to bucket
   - Use DynamoDB for state locking

4. **Audit Trail**:
   - Enable CloudTrail for AWS API calls
   - Review workflow logs regularly
   - Archive workflows for compliance

5. **Code Review**:
   - Require PR reviews before apply
   - Use branch protection rules
   - Require status checks to pass

## Advanced Configuration

### Custom Runners

If you need custom runners (self-hosted):

1. Create EC2 instance with GitHub Actions runner
2. Update workflow to use:
   ```yaml
   runs-on: self-hosted
   ```

### Multiple AWS Accounts

For multiple accounts, create separate IAM roles:

```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN_DEV }}  # per environment
    aws-region: us-east-1
```

### Slack Notifications

Add to workflow:

```yaml
- name: Slack Notification
  if: always()
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "text": "Terraform deployment for ${{ env.ENVIRONMENT }}: ${{ job.status }}"
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

## Cleanup

If you need to remove the GitHub Actions setup:

```bash
# Delete IAM role
aws iam delete-role-policy \
  --role-name github-terraform-role \
  --policy-name terraform-policy

aws iam delete-role --role-name github-terraform-role

# Delete OIDC provider (get ARN first)
aws iam delete-open-id-connect-provider \
  --open-id-connect-provider-arn arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com

# Delete S3 bucket (note: must be empty first)
aws s3 rm s3://your-terraform-state-bucket --recursive
aws s3 rb s3://your-terraform-state-bucket

# Delete DynamoDB table
aws dynamodb delete-table --table-name terraform-lock
```

## Support & Troubleshooting

### Common Issues

1. **"Error: Failed to assume role"**
   - Verify trust policy includes correct GitHub org and repo
   - Check OIDC provider is configured correctly
   - Verify role ARN in GitHub secret is correct

2. **"Error: Access Denied on S3"**
   - Verify S3 bucket name in secret
   - Check IAM policy has S3 permissions
   - Verify bucket exists and is accessible

3. **"Error: Unable to acquire state lock"**
   - Verify DynamoDB table exists
   - Check IAM policy has DynamoDB permissions
   - Verify table name in secret

### Getting Help

1. Check GitHub Actions logs
2. Review AWS CloudTrail logs
3. Verify all prerequisites are met
4. Check Terraform documentation

For issues specific to GitHub Actions:
- https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect

For issues specific to AWS:
- https://aws.amazon.com/support/
