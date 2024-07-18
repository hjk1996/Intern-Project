
resource "aws_vpc" "main" {
  count      = var.enable_load_test ? 1 : 0
  cidr_block = "172.168.0.0/16"
  // Amazon 제공 DNS 서버에 대한 쿼리 여부
  enable_dns_support = true
  // public ip가 있는 host에 대해 public dns hostname을 허용할 것인지 여부
  enable_dns_hostnames = true

  tags = {
    Name = "k6-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  count  = var.enable_load_test ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  tags = {
    Name = "$k6-igw"
  }

}
resource "aws_route_table" "public" {
  count = var.enable_load_test ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }


  tags = {
    Name = "k6-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = var.enable_load_test ? 1 : 0

  route_table_id = aws_route_table.public[0].id
  subnet_id      = aws_subnet.main[0].id
}




resource "aws_subnet" "main" {
  count = var.enable_load_test ? 1 : 0

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = "172.168.1.0/24"
  availability_zone = "${var.region}a"

  tags = {
    Name = "k6-subnet"
  }
}

resource "aws_security_group" "k6_sg" {
  count = var.enable_load_test ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5665
    to_port     = 5665
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
    Name = "k6-sg"
  }
}


# ssh key
resource "tls_private_key" "k6_key" {
  count     = var.enable_load_test ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

// 생성한 key local에 저장
resource "local_file" "k6_key" {
  count = var.enable_load_test ? 1 : 0

  content  = tls_private_key.k6_key[0].private_key_pem
  filename = var.k6_key_path

  provisioner "local-exec" {
    command = "chmod 400 ${var.k6_key_path}"
  }
}



resource "aws_key_pair" "k6_key" {
  count      = var.enable_load_test ? 1 : 0
  key_name   = "k6-key-pair"
  public_key = tls_private_key.k6_key[0].public_key_openssh
}

resource "aws_iam_role" "k6" {
  count = var.enable_load_test ? 1 : 0
  name  = "${var.project_name}-load-test-role"
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow"
          "Action" : "sts:AssumeRole"
          "Sid" : ""
          "Principal" : {
            "Service" : "ec2.amazonaws.com"
          }
        },
      ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  count      = var.enable_load_test ? 1 : 0
  role       = aws_iam_role.k6[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}



resource "aws_iam_instance_profile" "k6" {
  count = var.enable_load_test ? 1 : 0
  name  = "${var.project_name}-k6-profile"
  role  = aws_iam_role.k6[0].name
}


resource "aws_instance" "k6" {
  count                = var.enable_load_test ? 1 : 0
  ami                  = "ami-062cf18d655c0b1e8" # Ubuntu
  instance_type        = "t3.large"
  availability_zone    = "${var.region}a"
  subnet_id            = aws_subnet.main[0].id
  iam_instance_profile = aws_iam_instance_profile.k6[0].name
  vpc_security_group_ids = [
    aws_security_group.k6_sg[0].id
  ]

  root_block_device {
    volume_size = 100
  }


  associate_public_ip_address = true
  key_name                    = aws_key_pair.k6_key[0].key_name
  user_data                   = <<-EOF
              #!/bin/bash
              sudo gpg -k
              sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
              echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
              sudo apt-get update
              sudo apt-get install k6
              sudo echo "export TARGET_URL=https://madang.${var.zone_name}" >> /home/ubuntu/.bashrc
              EOF


  provisioner "file" {
    source      = "${path.module}/stress_test.js"
    destination = "/home/ubuntu/stress_test.js"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.k6_key_path)
      host        = self.public_ip
    }
  }

  provisioner "file" {
    source      = "${path.module}/spike_test.js"
    destination = "/home/ubuntu/spike_test.js"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.k6_key_path)
      host        = self.public_ip
    }
  }




  provisioner "remote-exec" {
    inline = [
      "export TARGET_URL=${var.lb_dns}",
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.k6_key_path)
      host        = self.public_ip
    }
  }


  tags = {
    Name = "k6-instance"
  }
}

resource "null_resource" "load_test_file" {
  count = var.enable_load_test ? 1 : 0
  triggers = {
    file_md5_1 = md5(file("${path.module}/stress_test.js"))
    file_md5_2 = md5(file("${path.module}/spike_test.js"))
  }

  provisioner "file" {
    source      = "${path.module}/stress_test.js"
    destination = "/home/ubuntu/stress_test.js"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.k6_key_path)
      host        = aws_instance.k6[0].public_ip
    }
  }


  provisioner "file" {
    source      = "${path.module}/spike_test.js"
    destination = "/home/ubuntu/spike_test.js"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.k6_key_path)
      host        = aws_instance.k6[0].public_ip
    }
  }


}
