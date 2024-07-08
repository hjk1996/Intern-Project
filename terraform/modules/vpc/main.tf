




resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "${var.project_name}-vpc"
  }

}

//subnets
resource "aws_subnet" "public" {
  count      = 3
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet(var.cidr_block, 8, count.index)



  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private_app" {
  count      = 3
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet(var.cidr_block, 8, 100 + count.index)
  tags = {
    Name = "${var.project_name}-private-app-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private_db" {
  count      = 3
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet(var.cidr_block, 8, 200 + count.index)
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
  vpc_id = aws_vpc.main.id

    tags = {
      Name = "${var.project_name}-private-rt"
    }

}

resource "aws_route_table_association" "app" {
  count          = length(aws_subnet.private_app.*.id)
  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.private_app[count.index].id
}

resource "aws_route_table_association" "db" {
  count          = length(aws_subnet.private_db.*.id)
  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.private_db[count.index].id
}






