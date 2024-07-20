

locals {

  az_alphabets = ["a", "c", "d"]

  azs = [for n in range(var.number_of_azs) : "${var.region}${local.az_alphabets[n]}"]

}



// DB 서브넷 그룹
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-subnet-group"
  subnet_ids = var.db_private_subnet_ids
}

// DB 보안 그룹
resource "aws_security_group" "db" {
  name   = "${var.project_name}-db-sg"
  vpc_id = var.vpc_id

  ingress {
    protocol    = "TCP"
    from_port   = 3306
    to_port     = 3306
    cidr_blocks = [var.cidr_block]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]

  }

  tags = {
    Name = "${var.project_name}-db-sg"
  }


}

resource "aws_db_parameter_group" "main" {
  name   = "${var.project_name}-aurora-mysql-pg"
  family = "aurora-mysql5.7"


  parameter {
    name  = "max_execution_time"
    value = 120000
  }

  parameter {
    name  = "max_connections"
    value = var.max_connections
  }

  parameter {
    name  = "wait_timeout"
    value = var.wait_timeout
  }

}



// DB Cluster
resource "aws_rds_cluster" "main" {
  cluster_identifier   = "${var.project_name}-db-cluster"
  availability_zones   = local.azs
  engine               = "aurora-mysql"
  engine_version       = "5.7.mysql_aurora.2.11.1"
  database_name        = var.db_name
  storage_encrypted    = true
  db_subnet_group_name = aws_db_subnet_group.main.name
  vpc_security_group_ids = [
    aws_security_group.db.id
  ]

  skip_final_snapshot         = true
  apply_immediately           = true
  manage_master_user_password = true
  master_username             = "master"
}

// DB Instance
resource "aws_rds_cluster_instance" "main" {
  count                   = var.number_of_azs
  identifier              = "${var.project_name}-db-${count.index}"
  cluster_identifier      = aws_rds_cluster.main.id
  instance_class          = var.db_instance_class
  db_parameter_group_name = aws_db_parameter_group.main.name
  apply_immediately       = true
  engine                  = aws_rds_cluster.main.engine
  engine_version          = aws_rds_cluster.main.engine_version
}







