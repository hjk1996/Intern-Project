

locals {

  az_alphabets = ["a", "c", "d"]

  azs = [for n in range(var.number_of_azs) : "${var.region}${local.az_alphabets[n]}"]

}


resource "aws_vpc" "main" {
  cidr_block = var.cidr_block
  tags = {
    Name = "${var.project_name}-vpc"
  }

  // Amazon 제공 DNS 서버에 대한 쿼리 여부
  enable_dns_support = true
  // public ip가 있는 host에 대해 public dns hostname을 허용할 것인지 여부
  enable_dns_hostnames = true
}



//subnets
resource "aws_subnet" "public" {
  count             = var.number_of_azs
  vpc_id            = aws_vpc.main.id
  availability_zone = local.azs[count.index]
  cidr_block        = cidrsubnet(var.cidr_block, 8, count.index)



  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
  }
}




resource "aws_subnet" "private_app" {
  count             = var.number_of_azs
  vpc_id            = aws_vpc.main.id
  availability_zone = local.azs[count.index]
  cidr_block        = cidrsubnet(var.cidr_block, 8, 100 + count.index)
  tags = {
    Name = "${var.project_name}-private-app-subnet-${count.index + 1}"
  }
}


resource "aws_subnet" "interface_endpoint" {
  count             = var.enable_vpc_interface_endpoint ? 1 : 0
  vpc_id            = aws_vpc.main.id
  availability_zone = local.azs[0]
  cidr_block        = cidrsubnet(var.cidr_block, 8, 100 + length(local.azs))
  tags = {
    Name = "${var.project_name}-interface-endpoint-subnet"
  }
}




resource "aws_subnet" "private_db" {
  count             = var.number_of_azs
  vpc_id            = aws_vpc.main.id
  availability_zone = local.azs[count.index]
  cidr_block        = cidrsubnet(var.cidr_block, 8, 200 + count.index)
  tags = {
    Name = "${var.project_name}-private-db-subnet-${count.index + 1}"
  }
}

//igw
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }

}

// NAT Gateway EIP
resource "aws_eip" "nat" {
  count = var.number_of_azs

  lifecycle {
    create_before_destroy = true
  }

}


// nat gateways
resource "aws_nat_gateway" "main" {
  count         = var.number_of_azs
  allocation_id = element(aws_eip.nat.*.id, count.index)
  subnet_id     = element(aws_subnet.public.*.id, count.index)

  tags = {
    Name = "${var.project_name}-ngw-${count.index + 1}"
  }
  depends_on = [aws_eip.nat]
}



// route tables and route table associations
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }


  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = var.number_of_azs
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public[count.index].id
}

resource "aws_route_table" "private" {
  count  = var.number_of_azs
  vpc_id = aws_vpc.main.id


  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = element(aws_nat_gateway.main.*.id, count.index)
  }


  tags = {
    Name = "${var.project_name}-private-rt-${count.index + 1}"
  }

}

resource "aws_route_table_association" "app" {
  count          = length(aws_subnet.private_app.*.id)
  route_table_id = element(aws_route_table.private.*.id, count.index)
  subnet_id      = aws_subnet.private_app[count.index].id

}

resource "aws_route_table_association" "db" {
  count          = length(aws_subnet.private_db.*.id)
  route_table_id = element(aws_route_table.private.*.id, count.index)
  subnet_id      = aws_subnet.private_db[count.index].id
}


// 엔드포인트 관련 -----------------



// VPC Interface Endpoint

resource "aws_security_group" "interface_endpoint" {
  count  = var.enable_vpc_interface_endpoint ? 1 : 0
  name   = "${var.project_name}-interface-endpoint-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "TCP"

    cidr_blocks = [
      aws_vpc.main.cidr_block
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.main.cidr_block]
    description = "Internal outbound any traffic"
  }

  tags = {
    Name = "${var.project_name}-interface-endpoint-sg"
  }
}


resource "aws_vpc_endpoint" "main" {
  for_each          = var.enable_vpc_interface_endpoint ? toset(var.interface_endpoint_service_names) : toset([])
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.interface_endpoint[0].id
  ]

  private_dns_enabled = true
  auto_accept         = true

  tags = {
    Name = "${var.project_name}-${each.key}-interface-endpoint"
  }
}

resource "aws_vpc_endpoint_subnet_association" "cloudwatch" {
  for_each        = var.enable_vpc_interface_endpoint ? toset(var.interface_endpoint_service_names) : toset([])
  vpc_endpoint_id = aws_vpc_endpoint.main[each.key].id
  subnet_id       = aws_subnet.interface_endpoint[0].id
}








resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  vpc_endpoint_type = "Gateway"
  service_name      = "com.amazonaws.${var.region}.s3"
  route_table_ids   = aws_route_table.private.*.id

  tags = {
    Name = "${var.project_name}-s3-vpc-gateway-endpoint"
  }
}

