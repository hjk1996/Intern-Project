

locals {
  azs = [
    "${var.region}a",
    "${var.region}c",
    "${var.region}d",
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
resource "aws_rds_cluster_instance" "cluster_instances" {
  count              = length(local.azs)
  identifier         = "${var.project_name}-db-${count.index}"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.t3.medium"
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version
}



# resource "aws_iam_role" "db_populator" {
#   name = "${var.project_name}-db-populator-role"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Action = "sts:AssumeRole",
#         Effect = "Allow",
#         Principal = {
#           Service = "lambda.amazonaws.com",
#         },
#       },
#     ],
#   })
# }

# resource "aws_iam_role_policy_attachment" "lambda_policy" {
#   role       = aws_iam_role.db_populator.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
# }




