terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc-${var.environment}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw-${var.environment}"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${var.project_name}-eip-nat-${var.environment}"
  }
}

# Public Subnets (distribute across AZs)
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index % length(var.availability_zones)]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}-${var.environment}"
  }
}

# NAT Gateway (in first public subnet)
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${var.project_name}-nat-gw-${var.environment}"
  }
}

# Private Subnets (3 subnets)
resource "aws_subnet" "private" {
  count                   = 3
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index % length(var.availability_zones)]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}-${var.environment}"
  }
}

# Route Table for Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt-${var.environment}"
  }
}

# Route Table Association for Public Subnets
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route Table for Private Subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-private-rt-${var.environment}"
  }
}

# Route Table Associations for Private Subnets
resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Security Group for ALB (Public)
resource "aws_security_group" "alb_public" {
  name        = "${var.project_name}-alb-public-sg-${var.environment}"
  description = "Security group for public ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-public-sg-${var.environment}"
  }
}

# Security Group for ALB (Internal)
resource "aws_security_group" "alb_internal" {
  name        = "${var.project_name}-alb-internal-sg-${var.environment}"
  description = "Security group for internal ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_frontend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-internal-sg-${var.environment}"
  }
}

# Security Group for ECS Frontend
resource "aws_security_group" "ecs_frontend" {
  name        = "${var.project_name}-ecs-fe-sg-${var.environment}"
  description = "Security group for ECS Frontend tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_public.id]
  }

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_public.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ecs-fe-sg-${var.environment}"
  }
}

# Security Group for ECS Backend
resource "aws_security_group" "ecs_backend" {
  name        = "${var.project_name}-ecs-be-sg-${var.environment}"
  description = "Security group for ECS Backend tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_internal.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ecs-be-sg-${var.environment}"
  }
}

# Security Group for DocumentDB
resource "aws_security_group" "documentdb" {
  name        = "${var.project_name}-documentdb-sg-${var.environment}"
  description = "Security group for DocumentDB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_backend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-documentdb-sg-${var.environment}"
  }
}

# VPC Flow Logs (optional but recommended)
# resource "aws_flow_log" "main" {
#   iam_role_arn    = aws_iam_role.flow_logs.arn
#   log_destination = aws_cloudwatch_log_group.flow_logs.arn
#   traffic_type    = "ALL"
#   vpc_id          = aws_vpc.main.id
#
#   tags = {
#     Name = "${var.project_name}-flow-logs-${var.environment}"
#   }
# }

# resource "aws_cloudwatch_log_group" "flow_logs" {
#   name              = "/aws/vpc/flowlogs/${var.project_name}-${var.environment}"
#   retention_in_days = 7
#
#   tags = {
#     Name = "${var.project_name}-flow-logs-${var.environment}"
#   }
# }

# resource "aws_iam_role" "flow_logs" {
#   name_prefix = "${var.project_name}-flow-logs-"
#
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Action = "sts:AssumeRole"
#       Effect = "Allow"
#       Principal = {
#         Service = "vpc-flow-logs.amazonaws.com"
#       }
#     }]
#   })
#
#   tags = {
#     Name = "${var.project_name}-flow-logs-role-${var.environment}"
#   }
# }

# resource "aws_iam_role_policy" "flow_logs" {
#   name_prefix = "${var.project_name}-flow-logs-"
#   role        = aws_iam_role.flow_logs.id
#
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Action = [
#         "logs:CreateLogGroup",
#         "logs:CreateLogStream",
#         "logs:PutLogEvents",
#         "logs:DescribeLogGroups",
#         "logs:DescribeLogStreams"
#       ]
#       Effect   = "Allow"
#       Resource = "*"
#     }]
#   })
# }
