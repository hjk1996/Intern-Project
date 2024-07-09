data "aws_region" "current" {
  
}
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



// AZ 명시적으로 지정해주면 왜 자꾸 replaced되지?
resource "aws_db_instance" "main" {
    allocated_storage = 50
    identifier = "${var.project_name}-db"
    db_name = "app"
    db_subnet_group_name = aws_db_subnet_group.main.name
    engine = "mysql"
    engine_version = "8.0.35"
    instance_class = "db.t3.micro"
    username = "master"
    manage_master_user_password = true
    vpc_security_group_ids = [
        aws_security_group.db.id
    ]
    storage_encrypted = true
    // db를 삭제하기 전에 스냅샷을 저장할 것인지 여부
    skip_final_snapshot = true
    // db parameter에 대한 변경은 다음 maintenance window에 반영되는데, 이걸 설정하면 바로 반영됨 (다운타임 있음)
    apply_immediately = true
}





