// bastion 보안 그룹
resource "aws_security_group" "bastion" {
  count  = var.enable_bastion ? 1 : 0
  name   = "${var.project_name}-bastion-sg"
  vpc_id = var.vpc_id

  ingress {
    protocol    = "TCP"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]

  }


  tags = {
    Name = "${var.project_name}-bastion-sg"
  }

}

# ssh key
resource "tls_private_key" "bastion_key" {
  count     = var.enable_bastion ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

// 생성한 key local에 저장
resource "local_file" "bastion_key" {
  count    = var.enable_bastion ? 1 : 0
  content  = tls_private_key.bastion_key[0].private_key_pem
  filename = var.bastion_key_path

  provisioner "local-exec" {
    command = "chmod 400 ${var.bastion_key_path}"
  }
}



resource "aws_key_pair" "bastion_key" {
  count      = var.enable_bastion ? 1 : 0
  key_name   = "${var.project_name}-bastion-key-pair"
  public_key = tls_private_key.bastion_key[0].public_key_openssh
}



resource "aws_instance" "bastion" {
  count             = var.enable_bastion ? 1 : 0
  availability_zone = "${var.region}a"
  instance_type     = "t3.micro"
  vpc_security_group_ids = [
    aws_security_group.bastion[0].id
  ]
  key_name  = aws_key_pair.bastion_key[0].key_name
  subnet_id = var.subnet_id
  ami       = "ami-062cf18d655c0b1e8"
  // public ip 부여
  associate_public_ip_address = true

  user_data = <<EOF
#!/bin/bash
sudo apt update
sudo apt install unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
sudo apt install -y mysql-client
EOF

  tags = {
    Name = "${var.project_name}-bastion"
  }

}


