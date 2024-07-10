data "aws_region" "current" {

}


locals {
  azs = [
    "${data.aws_region.current.name}a",
    "${data.aws_region.current.name}c",
    "${data.aws_region.current.name}d",
  ]
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




resource "aws_rds_cluster" "main" {
  cluster_identifier        = "${var.project_name}-db-cluster"
  availability_zones        = local.azs
  engine                    = "mysql"
  db_cluster_instance_class = "db.m5d.large"
  storage_type              = "io1"
  allocated_storage         = 100
  iops                      = 1000
  storage_encrypted = true
  db_subnet_group_name = aws_db_subnet_group.main.name
  vpc_security_group_ids = [
    aws_security_group.db.id
  ]
  skip_final_snapshot = true
  apply_immediately = true
  manage_master_user_password = true
  master_username           = "master"
}
