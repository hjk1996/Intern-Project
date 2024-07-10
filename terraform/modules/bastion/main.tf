data "aws_region" "current" {

}

// bastion 보안 그룹
resource "aws_security_group" "bastion" {
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
  algorithm = "RSA"
  rsa_bits  = 4096
}

// 생성한 key local에 저장
resource "local_file" "bastion_key" {
  content  = tls_private_key.bastion_key.private_key_pem
  filename = var.ssh_key_path
}

resource "aws_key_pair" "bastion_key" {
  key_name   = "${var.project_name}-bastion-key-pair"
  public_key = tls_private_key.bastion_key.public_key_openssh
}


data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}


resource "aws_instance" "bastion" {
  availability_zone = "${data.aws_region.current.name}a"
  instance_type     = "t3.micro"
  vpc_security_group_ids = [
    aws_security_group.bastion.id
  ]
  key_name  = aws_key_pair.bastion_key.key_name
  subnet_id = var.subnet_id
  ami       = data.aws_ami.ubuntu.id
  // public ip 부여
  associate_public_ip_address = true

  user_data = <<EOF
    sudo apt update
    sudo apt install -y mysql-client
    EOF


  tags = {
    Name = "${var.project_name}-bastion"
  }

}


