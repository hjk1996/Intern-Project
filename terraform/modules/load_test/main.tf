
resource "aws_vpc" "main" {
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
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "$k6-igw"
  }

}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }


  tags = {
    Name = "k6-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.main.id
}




resource "aws_subnet" "main" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "172.168.1.0/24"
  availability_zone = "${var.region}a"

  tags = {
    Name = "k6-subnet"
  }
}

resource "aws_security_group" "k6_sg" {
  vpc_id = aws_vpc.main.id

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
  algorithm = "RSA"
  rsa_bits  = 4096
}

// 생성한 key local에 저장
resource "local_file" "k6_key" {
  content  = tls_private_key.k6_key.private_key_pem
  filename = var.k6_key_path

  provisioner "local-exec" {
    command = "chmod 400 ${var.k6_key_path}"
  }
}



resource "aws_key_pair" "k6_key" {
  key_name   = "k6-key-pair"
  public_key = tls_private_key.k6_key.public_key_openssh
}




resource "aws_instance" "k6" {
  ami               = "ami-062cf18d655c0b1e8" # Ubuntu
  instance_type     = "t3.medium"
  availability_zone = "${var.region}a"
  subnet_id         = aws_subnet.main.id
  vpc_security_group_ids = [
    aws_security_group.k6_sg.id
  ]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.k6_key.key_name
  user_data                   = <<-EOF
              #!/bin/bash
              sudo gpg -k
              sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
              echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
              sudo apt-get update
              sudo apt-get install k6
              echo "good"
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
      host        = aws_instance.k6.public_ip
    }
  }


  provisioner "file" {
    source      = "${path.module}/spike_test.js"
    destination = "/home/ubuntu/spike_test.js"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.k6_key_path)
      host        = aws_instance.k6.public_ip
    }
  }

  # provisioner "remote-exec" {
  #   inline = [
  #     "echo export TARGET_URL=http://${var.lb_dns} >> etc/profile",
  #   ]

  #   connection {
  #     type        = "ssh"
  #     user        = "ubuntu"
  #     private_key = file(var.k6_key_path)
  #     host        = aws_instance.k6.public_ip
  #   }
  # }
}
