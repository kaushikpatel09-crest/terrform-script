terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# DocumentDB Subnet Group
resource "aws_docdb_subnet_group" "main" {
  name_prefix     = "${var.project_name}-"
  subnet_ids      = var.subnet_ids
  skip_destroying = true

  tags = {
    Name = "${var.project_name}-docdb-subnet-group-${var.environment}"
  }
}

# DocumentDB Cluster
resource "aws_docdb_cluster" "main" {
  cluster_identifier              = var.cluster_identifier
  engine                          = "docdb"
  master_username                 = var.master_username
  master_password                 = var.master_password
  backup_retention_period         = var.backup_retention_days
  preferred_backup_window         = "03:00-04:00"
  preferred_maintenance_window    = "sun:04:00-sun:05:00"
  db_subnet_group_name            = aws_docdb_subnet_group.main.name
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.main.name
  vpc_security_group_ids          = var.security_group_ids
  storage_encrypted               = true
  skip_final_snapshot             = var.skip_final_snapshot
  final_snapshot_identifier       = var.skip_final_snapshot ? null : "${var.cluster_identifier}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]
  engine_version                  = var.engine_version

  tags = {
    Name = var.cluster_identifier
  }
}

# DocumentDB Cluster Parameter Group
resource "aws_docdb_cluster_parameter_group" "main" {
  name_prefix = "${var.project_name}-"
  family      = "docdb4.0"
  description = "Parameter group for ${var.cluster_identifier}"

  parameter {
    name  = "tls"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_name}-docdb-cluster-pg-${var.environment}"
  }
}

# DocumentDB Cluster Instances
resource "aws_docdb_cluster_instance" "main" {
  count              = var.num_instances
  cluster_identifier = aws_docdb_cluster.main.id
  instance_class     = var.instance_class
  engine              = "docdb"

  tags = {
    Name = "${var.project_name}-docdb-instance-${count.index + 1}-${var.environment}"
  }
}

# CloudWatch Log Group for DocumentDB
resource "aws_cloudwatch_log_group" "docdb" {
  name              = "/aws/docdb/${var.cluster_identifier}"
  retention_in_days = 7

  tags = {
    Name = "${var.cluster_identifier}-logs"
  }
}
