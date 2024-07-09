// DB 서브넷 그룹
resource "aws_db_subnet_group" "main" {
    name = "${var.project_name}-subnet-group"
    subnet_ids = var.db_private_subnet_ids  
}

// DB 보안 그룹
resource "aws_security_group" "db" {
    name = "${var.project_name}-db-sg"
    vpc_id = var.vpc_id

    ingress {
        protocol = "TCP"
        from_port = 3306
        to_port = 3306
        cidr_blocks = [var.cidr_block]
    }

    egress {
        protocol = "-1"
        from_port = 0
        to_port = 0
        cidr_blocks = ["0.0.0.0/0"]

    }

    tags = {
      Name = "${var.project_name}-db-sg"
    }

  
}


