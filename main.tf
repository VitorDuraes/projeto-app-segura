provider "aws" {
  region = "us-east-1" # Altere para sua região
}

####################
# VPC
####################
resource "aws_vpc" "app_seguravpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name        = "app-segura-vpc"
    Environment = "dev"
  }
}

####################
# Internet Gateway
####################
resource "aws_internet_gateway" "app_segura_gw" {
  vpc_id = aws_vpc.app_seguravpc.id

  tags = {
    Name = "app-segura-gw"
  }
}

####################
# Subnets
####################
# Pública
resource "aws_subnet" "app_segura_public" {
  vpc_id                  = aws_vpc.app_seguravpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "app-segura-public-subnet"
  }
}

# Privadas (para RDS)
resource "aws_subnet" "app_segura_private1" {
  vpc_id                  = aws_vpc.app_seguravpc.id
  cidr_block              = "10.0.11.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "app-segura-private-subnet-1"
  }
}

resource "aws_subnet" "app_segura_private2" {
  vpc_id                  = aws_vpc.app_seguravpc.id
  cidr_block              = "10.0.12.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "app-segura-private-subnet-2"
  }
}

####################
# Route Table e Associação
####################
resource "aws_route_table" "app_segura_rt" {
  vpc_id = aws_vpc.app_seguravpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app_segura_gw.id
  }

  tags = {
    Name = "app-segura-rt"
  }
}

resource "aws_route_table_association" "app_segura_rt_assoc" {
  subnet_id      = aws_subnet.app_segura_public.id
  route_table_id = aws_route_table.app_segura_rt.id
}

####################
# Security Groups
####################
# EC2
resource "aws_security_group" "app_segura_ec2_sg" {
  name        = "app-segura-ec2-sg"
  description = "Allow HTTP and SSH"
  vpc_id      = aws_vpc.app_seguravpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
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
    Name = "app-segura-ec2-sg"
  }
}

# RDS
resource "aws_security_group" "app_segura_db_sg" {
  name        = "app-segura-db-sg"
  description = "Allow MySQL from EC2 only"
  vpc_id      = aws_vpc.app_seguravpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_segura_ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app-segura-db-sg"
  }
}

####################
# Key Pair
####################
resource "aws_key_pair" "app_segura_key" {
  key_name   = "app-segura-key"
  public_key = file("~/.ssh/app-segura-key.pub")
}

####################
# Elastic IP (fixa para EC2)
####################
resource "aws_eip" "app_segura_eip" {
  domain = "vpc"

  tags = {
    Name = "app-segura-eip"
  }
}

####################
# EC2 com User Data (Docker + Nginx)
####################
resource "aws_instance" "app_segura_ec2" {
  ami                         = "ami-0c02fb55956c7d316"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.app_segura_public.id
  vpc_security_group_ids      = [aws_security_group.app_segura_ec2_sg.id]
  key_name                    = aws_key_pair.app_segura_key.key_name
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash -xe
              sudo yum update -y
              sudo yum upgrade -y
              sudo yum install -y docker.io
              systemctl enable docker
              systemctl start docker
              mkdir -p /home/ubuntu/html
              echo "<h1>Olá do Nginx via Docker + Terraform</h1>" > /home/ubuntu/html/index.html
              docker run -d -p 80:80 -v /home/ubuntu/html:/usr/share/nginx/html nginx:latest
              EOF

  tags = {
    Name = "app-segura-ec2"
  }

  depends_on = [aws_eip.app_segura_eip]
}

# Associa EIP à EC2
resource "aws_eip_association" "app_segura_eip_assoc" {
  instance_id   = aws_instance.app_segura_ec2.id
  allocation_id = aws_eip.app_segura_eip.id
}

####################
# RDS MySQL
####################
resource "aws_db_subnet_group" "app_segura_db_subnet" {
  name       = "app-segura-db-subnet-group-v2"
  subnet_ids = [aws_subnet.app_segura_private1.id, aws_subnet.app_segura_private2.id]

  tags = {
    Name = "app-segura-db-subnet-group-v2"
  }
}

resource "aws_db_instance" "app_segura_db" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "8.0.42"
  db_subnet_group_name   = aws_db_subnet_group.app_segura_db_subnet.name
  publicly_accessible    = false
  instance_class         = "db.t3.micro"
  username               = "admin"
  password               = "F%9rT8!zQw2#Lk7m"
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.app_segura_db_sg.id]

  tags = {
    Name = "app-segura-db"
  }

  depends_on = [aws_security_group.app_segura_db_sg]
}

####################
# Outputs
####################
output "ec2_public_ip" {
  value       = aws_eip.app_segura_eip.public_ip
  description = "IP público fixo da EC2"
}

output "db_password" {
  value       = aws_db_instance.app_segura_db.password
  sensitive   = true
  description = "Senha do banco RDS"
}
