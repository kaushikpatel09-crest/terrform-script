# OIDC Token Audience Error - Troubleshooting

## Problem
```
Error: Could not assume role with OIDC: Incorrect token audience
```

## Solution Applied
Updated GitHub Actions workflow with proper OIDC configuration:
```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: ${{ env.AWS_REGION }}
    token-format: 'sts'           # ✅ Added
    duration-seconds: 3600         # ✅ Added
```

## Verification Steps

### 1. Verify OIDC Provider Exists in AWS
```powershell
aws iam list-open-id-connect-providers
```

Expected output:
```
{
    "OpenIDConnectProviderList": [
        {
            "Arn": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
        }
    ]
}
```

### 2. Verify OIDC Provider Thumbprint
```powershell
aws iam get-open-id-connect-provider `
  --open-id-connect-provider-arn "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
```

Expected output should include:
```
"ThumbprintList": [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
]
```

If thumbprint is wrong, run:
```powershell
aws iam update-open-id-connect-provider-thumbprint `
  --open-id-connect-provider-arn "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com" `
  --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1"
```

### 3. Verify IAM Role Trust Policy

Run this command with YOUR_ACCOUNT_ID and YOUR_GITHUB_ORG/REPO replaced:
```powershell
aws iam get-role --role-name github-terraform-role
```

Look for the trust policy section. It should allow:
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
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_ORG/YOUR_REPO:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

### 4. Check Trust Policy Details

The trust policy MUST have:
- ✅ `"aud": "sts.amazonaws.com"` (this is the token audience GitHub sends)
- ✅ Correct GitHub org and repo name in the `sub` condition
- ✅ The OIDC provider ARN correctly formatted

### 5. If Trust Policy is Wrong

Get your GitHub organization and repository:
```powershell
# These values come from your GitHub repository URL
# Example: https://github.com/kaushikpatel09-crest/terrform-script
$GITHUB_ORG = "kaushikpatel09-crest"
$REPO_NAME = "terrform-script"
$AWS_ACCOUNT_ID = "123456789012"  # Replace with your account ID
```

Update the trust policy:
```powershell
$TRUST_POLICY = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::$AWS_ACCOUNT_ID`:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:$GITHUB_ORG/$REPO_NAME`:ref:refs/heads/main"
        }
      }
    }
  ]
}
"@

aws iam update-assume-role-policy `
  --role-name github-terraform-role `
  --policy-document $TRUST_POLICY
```

### 6. Test Connection

Push a change to your main branch to trigger the validation workflow, or manually run:
```
GitHub → Actions → Terraform Validation → Run workflow
```

## Common Issues

| Issue | Solution |
|-------|----------|
| `Incorrect token audience` | Add `token-format: 'sts'` to workflow |
| `Provider not found` | Create OIDC provider using provided script |
| `Role not found` | Check role name matches `AWS_ROLE_ARN` secret |
| `Access Denied` | Verify IAM policy allows required actions |
| `Wrong thumbprint` | Update OIDC provider thumbprint |

## References

- [AWS OIDC Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [GitHub OIDC in AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [AWS Actions Configure Credentials](https://github.com/aws-actions/configure-aws-credentials#oidc)

## Next Steps

1. ✅ Workflow updated with `token-format: 'sts'` and `duration-seconds: 3600`
2. Run verification steps 1-4 above to check AWS setup
3. If any issues found, run fix commands in step 5
4. Push to main branch to trigger validation workflow
5. Check workflow logs for success

If issues persist after verification, ensure:
- GitHub org and repo name in trust policy match your actual repo
- AWS account ID is correct
- OIDC provider thumbprint is the latest version
