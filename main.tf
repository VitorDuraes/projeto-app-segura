resource "aws_vpc" "app-segura-vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "app-segura-vpc"
  }
}

resource "aws_internet_gateway" "app-segura-gw" {
  vpc_id = aws_vpc.app-segura-vpc.id

  tags = {
    Name = "app-segura-gw"
  }
}

resource "aws_subnet" "app-segura-subnet" {
  vpc_id                  = aws_vpc.app-segura-vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "app-segura-subnet"
  }
}

resource "aws_subnet" "app-segura-private-subnet" {
  vpc_id                  = aws_vpc.app-segura-vpc.id
  cidr_block              = "10.0.11.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "app-segura-private-subnet"
  }
}

resource "aws_subnet" "app-segura-private-subnet-2" {
  vpc_id                  = aws_vpc.app-segura-vpc.id
  cidr_block              = "10.0.12.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "app-segura-private-subnet-2"
  }
}


resource "aws_route_table" "app-segura-route-table" {
  vpc_id = aws_vpc.app-segura-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app-segura-gw.id
  }

  tags = {
    Name = "app-segura-route-table"
  }
}

resource "aws_route_table_association" "app-segura-route-table-assoc" {
  subnet_id      = aws_subnet.app-segura-subnet.id
  route_table_id = aws_route_table.app-segura-route-table.id
}

resource "aws_db_subnet_group" "app-segura-db-subnet-group" {
  name = "app-segura-db-subnet-group"
  subnet_ids = [
    aws_subnet.app-segura-private-subnet.id,
    aws_subnet.app-segura-private-subnet-2.id
  ]

  tags = {
    Name = "app-segura-db-subnet-group"
  }
}


resource "aws_db_instance" "app-segura-db" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "8.0.42"
  db_subnet_group_name   = aws_db_subnet_group.app-segura-db-subnet-group.name
  publicly_accessible    = false
  instance_class         = "db.t3.micro"
  username               = "admin"
  password               = "F%9rT8!zQw2#Lk7m"
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.app-segura-ec2-sg.id]
  tags = {
    Name = "app-segura-db"
  }
}

resource "aws_key_pair" "my-key-pair" {
  key_name   = "my-key-pair-app-segura"
  public_key = file("~/.ssh/app-segura-key.pub")
}

resource "aws_security_group" "app-segura-ec2-sg" {
  name        = "app-segura-ec2-sg"
  description = "Security group for app segura EC2"
  vpc_id      = aws_vpc.app-segura-vpc.id

  # Permitir HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Permitir SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Liberar todo tráfego de saída
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app-segura-ec2" {
  ami                    = "ami-0c02fb55956c7d316"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.app-segura-subnet.id
  vpc_security_group_ids = [aws_security_group.app-segura-ec2-sg.id]
  key_name               = aws_key_pair.my-key-pair.key_name

  tags = {
    Name = "app-segura-ec2"
  }
}
