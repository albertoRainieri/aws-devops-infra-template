# Public VPC Configuration
resource "aws_vpc" "public" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "public-vpc"
  }
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Data source for latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.public.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "public" {
  vpc_id = aws_vpc.public.id

  tags = {
    Name = "public-igw"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.public.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.public.id
  }

  tags = {
    Name = "public-rt"
  }
}

# Route Table Association
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group - Allow all inbound and outbound traffic
resource "aws_security_group" "public" {
  name        = "public-sg"
  description = "Security group allowing all traffic"
  vpc_id      = aws_vpc.public.id

  # Allow all inbound traffic
  ingress {
    description = "All inbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "public-sg"
  }
}

# AWS Key Pair using local public key
resource "aws_key_pair" "local_key" {
  key_name   = "local-key"
  public_key = file("~/.ssh/aws_rsa.pub") # Path to your local public key
}

# EC2 Instance
resource "aws_instance" "public" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.public.id]
  key_name               = aws_key_pair.local_key.key_name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Public VPC Server</h1>" > /var/www/html/index.html
              echo "<p>Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>" >> /var/www/html/index.html
              echo "<p>Availability Zone: $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)</p>" >> /var/www/html/index.html
              echo "<p>Private IP: $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)</p>" >> /var/www/html/index.html
              EOF

  tags = {
    Name = "public-instance"
  }
}

# Outputs
output "instance_public_ip" {
  value       = aws_instance.public.public_ip
  description = "Public IP of the EC2 instance"
}

output "instance_private_ip" {
  value       = aws_instance.public.private_ip
  description = "Private IP of the EC2 instance"
}

output "vpc_id" {
  value       = aws_vpc.public.id
  description = "VPC ID"
}

output "subnet_id" {
  value       = aws_subnet.public.id
  description = "Subnet ID"
}

output "ssh_command" {
  value       = "ssh -i ~/.ssh/aws_rsa ec2-user@${aws_instance.public.public_ip}"
  description = "SSH command to connect to the instance"
}

output "web_url" {
  value       = "http://${aws_instance.public.public_ip}"
  description = "URL to access the web server"
}
