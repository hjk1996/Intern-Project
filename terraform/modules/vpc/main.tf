

data "aws_region" "current" {

}

locals {
  azs = [
    "${data.aws_region.current.name}a",
    "${data.aws_region.current.name}c",
    "${data.aws_region.current.name}d",
  ]
}




resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

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
  count             = length(local.azs)
  vpc_id            = aws_vpc.main.id
  availability_zone = local.azs[count.index]
  cidr_block        = cidrsubnet(var.cidr_block, 8, count.index)



  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private_app" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.main.id
  availability_zone = local.azs[count.index]
  cidr_block        = cidrsubnet(var.cidr_block, 8, 100 + count.index)
  tags = {
    Name = "${var.project_name}-private-app-subnet-${count.index + 1}"
  }
}


resource "aws_subnet" "cloudwatch_endpoint" {
  vpc_id            = aws_vpc.main.id
  availability_zone = local.azs[0]
  cidr_block        = cidrsubnet(var.cidr_block, 8, 100 + length(local.azs))
  tags = {
    Name = "${var.project_name}-cloudwatch-endpoint-subnet"
  }
}




resource "aws_subnet" "private_db" {
  count             = length(local.azs)
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

// eip
// nat gateway에 public ip 부여를 위해서 필요함
resource "aws_eip" "nat" {
  count = length(aws_subnet.public.*.id)
  vpc   = true

  lifecycle {
    create_before_destroy = true
  }

}


// nat gateways
resource "aws_nat_gateway" "main" {
  count         = length(aws_subnet.public.*.id)
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
  count          = length(aws_subnet.public.*.id)
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public[count.index].id
}

resource "aws_route_table" "private" {
  count  = length(aws_subnet.private_app.*.id)
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


// cloudwatch vpc endpoint
resource "aws_security_group" "apigateway_vpc_endpoint_sg" {
  name   = "${var.project_name}-cloudwatch-logs-vpc-endpoint-sg"
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
    Name = "cloudwatch-logs-vpc-endpoint-sg"
  }
}

resource "aws_vpc_endpoint" "cloudwatch" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type = "Interface"


  security_group_ids = [
    aws_security_group.apigateway_vpc_endpoint_sg.id
  ]

  private_dns_enabled = true
  auto_accept         = true

  tags = {
    Name = "${var.project_name}-cloudwatch-log-vpc-endpoint"
  }

}

resource "aws_vpc_endpoint_subnet_association" "cloudwatch" {
  vpc_endpoint_id = aws_vpc_endpoint.cloudwatch.id
  subnet_id       = aws_subnet.cloudwatch_endpoint.id
}

