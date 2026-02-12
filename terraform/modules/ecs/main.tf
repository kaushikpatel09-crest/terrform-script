terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# CloudWatch Log Group for ECS
resource "aws_cloudwatch_log_group" "ecs" {
  name              = var.log_group_name
  retention_in_days = 7

  tags = {
    Name = var.log_group_name
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "disabled"
    # value = "enabled"
  }

  tags = {
    Name = var.cluster_name
  }
}

# ECS Cluster Capacity Providers
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "main" {
  family                   = "${var.project_name}-${var.service_name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([{
    name      = var.container_name
    image     = "${var.container_image}:${var.container_image_tag}"
    essential = true
    portMappings = [{
      containerPort = var.container_port
      hostPort      = var.container_port
      protocol      = "tcp"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = var.container_name
      }
    }
    environment = concat(
      [
        {
          name  = "ENVIRONMENT"
          value = var.environment
        }
      ],
      [
        for key, value in var.environment_variables : {
          name  = key
          value = value
        }
      ]
    )
  }])

  tags = {
    Name = "${var.project_name}-${var.service_name}-task"
  }
}

# ECS Service
resource "aws_ecs_service" "main" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = var.load_balancer_target_group_arn != "" ? [var.load_balancer_target_group_arn] : []
    content {
      target_group_arn = load_balancer.value
      container_name   = var.container_name
      container_port   = var.container_port
    }
  }

  depends_on = [aws_ecs_task_definition.main]

  tags = {
    Name = var.service_name
  }
}

# Auto Scaling Target
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policy - Scale Up (CPU)
resource "aws_appautoscaling_policy" "ecs_policy_up" {
  name               = "${var.service_name}-scale-up"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# Auto Scaling Policy - Scale Up (Memory)
resource "aws_appautoscaling_policy" "ecs_policy_memory" {
  name               = "${var.service_name}-scale-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 80.0
  }
}

# IAM Role for ECS Task Execution
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

# IAM Role Policy for ECS Task Execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Inline policy to allow pulling images from ECR
resource "aws_iam_role_policy" "ecs_ecr_pull" {
  name = "${var.project_name}-ecs-ecr-pull-${var.service_name}-${var.environment}"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Role for ECS Task
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

# Optional inline policy granting permission to invoke a specific Bedrock model
resource "aws_iam_role_policy" "ecs_bedrock_invoke" {
  count = var.bedrock_model_arn != "" ? 1 : 0

  name = "${var.project_name}-ecs-bedrock-invoke-${var.service_name}-${var.environment}"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ],
        Resource = var.bedrock_model_arn
      }
    ]
  })
}

# Optional inline policy granting S3 CRUD access to specified buckets
resource "aws_iam_role_policy" "ecs_s3_access" {
  count = var.enable_s3_access && length(var.s3_bucket_arns) > 0 ? 1 : 0

  name = "${var.project_name}-ecs-s3-access-${var.service_name}-${var.environment}"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
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

# Optional inline policy granting ECR repository access
#resource "aws_iam_role_policy" "ecs_ecr_access" {
#  count = var.ecr_repository_arn != "" ? 1 : 0

#   name = "${var.project_name}-ecs-ecr-access-${var.service_name}-${var.environment}"
#  role = aws_iam_role.ecs_task_role.id

#  policy = jsonencode({
#    Version = "2012-10-17",
#    Statement = [
#      {
#        Effect = "Allow",
#        Action = [
#          "ecr:GetDownloadUrlForLayer",
#          "ecr:BatchGetImage",
#          "ecr:DescribeImages"
#        ],
#        Resource = var.ecr_repository_arn
#      }
#    ]
#  })
#}

# Optional inline policy granting SQS queue access
resource "aws_iam_role_policy" "ecs_sqs_access" {
  count = var.enable_sqs_access ? 1 : 0

  name = "${var.project_name}-ecs-sqs-access-${var.service_name}-${var.environment}"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ],
        Resource = var.sqs_queue_arn
      }
    ]
  })
}

# Data source to get current AWS region
data "aws_region" "current" {}
