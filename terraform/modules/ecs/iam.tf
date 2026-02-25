# =============================================================================
# ECS IAM Roles & Policies
# =============================================================================


resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-task-execution-${var.service_name}-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-ecs-task-execution-${var.service_name}-${var.environment}"
  }
}

# AWS Managed policy — baseline ECS task execution permissions
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECR image pull policy — split into two statements per AWS requirement:
#   - ecr:GetAuthorizationToken is account-level and MUST use Resource="*"
#   - Image pull actions are scoped to the specific repository ARN
resource "aws_iam_role_policy" "ecs_ecr_pull" {
  name = "${var.project_name}-ecs-ecr-pull-${var.service_name}-${var.environment}"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuthToken"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        # GetAuthorizationToken is account-scoped — AWS does not support restricting it to a specific resource
        Resource = "*" #checkov:skip=CKV_AWS_355:ecr:GetAuthorizationToken is account-scoped and cannot be restricted to a specific resource
      },
      {
        Sid    = "ECRImagePull"
        Effect = "Allow"
        Action = [
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = var.ecr_repository_arn
      }
    ]
  })
}

# Secrets Manager read policy — grants execution role access to read container secrets
resource "aws_iam_role_policy" "ecs_secrets_access" {
  count = length(var.container_secrets) > 0 ? 1 : 0

  name = "${var.project_name}-ecs-secrets-${var.service_name}-${var.environment}"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowSecretsRead"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = values(var.container_secrets)
      }
    ]
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# TASK ROLE
# Used by the application running inside the container.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-role-${var.service_name}-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-ecs-task-role-${var.service_name}-${var.environment}"
  }
}

# Bedrock invoke policy — grants the task role permission to call Bedrock inference APIs
resource "aws_iam_role_policy" "ecs_bedrock_invoke" {
  count = var.bedrock_model_arn != "" ? 1 : 0

  name = "${var.project_name}-ecs-bedrock-invoke-${var.service_name}-${var.environment}"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "BedrockInvokeModel"
        Effect = "Allow",
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:StartAsyncInvoke",
          "bedrock:GetAsyncInvoke",
          "bedrock:ListAsyncInvokes"
        ],
        Resource = [
          var.bedrock_model_arn,
          "arn:aws:bedrock:*:${data.aws_caller_identity.current.account_id}:async-invoke/*",
          "arn:aws:bedrock:*::foundation-model/twelvelabs.marengo-embed-3-0-v1:0"
        ]
      }
    ]
  })
}

# S3 access policy — grants CRUD access to specified S3 buckets
resource "aws_iam_role_policy" "ecs_s3_access" {
  count = var.enable_s3_access && length(var.s3_bucket_arns) > 0 ? 1 : 0

  name = "${var.project_name}-ecs-s3-access-${var.service_name}-${var.environment}"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "S3BucketAccess"
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ],
        Resource = concat(
          var.s3_bucket_arns,
          [for arn in var.s3_bucket_arns : "${arn}/*"]
        )
      }
    ]
  })
}

# SQS access policy — grants the task role permission to consume messages from an SQS queue
resource "aws_iam_role_policy" "ecs_sqs_access" {
  count = var.enable_sqs_access ? 1 : 0

  name = "${var.project_name}-ecs-sqs-access-${var.service_name}-${var.environment}"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "SQSQueueAccess"
        Effect = "Allow",
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ],
        Resource = var.sqs_queue_arn
      }
    ]
  })
}

# OpenSearch Serverless access policy — grants the task role permission to query the collection
resource "aws_iam_role_policy" "ecs_opensearch_access" {
  # count must only use values known at plan time (static vars/locals).
  # Computed resource attributes like module outputs cannot be used in count.
  count = var.enable_ecs_opensearch_access ? 1 : 0

  name = "${var.project_name}-ecs-aoss-access-${var.service_name}-${var.environment}"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid      = "OpenSearchCollectionAccess"
        Effect   = "Allow",
        Action   = ["aoss:APIAccessAll"],
        Resource = var.opensearch_collection_arn
      }
    ]
  })
}
