# AWS VPC with EC2 Instance - Terraform Project

This Terraform project creates a complete AWS infrastructure including a VPC, public subnet, internet gateway, route table, security group, and EC2 instance. The project uses AWS S3 as a backend for state management with DynamoDB for state locking.

## 🏗️ AWS Infrastructure Components

### **1. Virtual Private Cloud (VPC)**
```hcl
resource "aws_vpc" "public" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}
```
- **CIDR Block**: `10.0.0.0/16` (65,536 IP addresses)
- **DNS Support**: Enabled for both hostnames and support
- **Purpose**: Isolated network environment for your AWS resources

### **2. Public Subnet**
```hcl
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.public.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
}
```
- **CIDR Block**: `10.0.1.0/24` (256 IP addresses within the VPC)
- **Availability Zone**: Automatically selects the first available AZ
- **Public IP Mapping**: Instances launched in this subnet get public IPs automatically
- **Purpose**: Network segment where your EC2 instance will be deployed

### **3. Internet Gateway**
```hcl
resource "aws_internet_gateway" "public" {
  vpc_id = aws_vpc.public.id
}
```
- **Attached to**: The public VPC
- **Purpose**: Provides internet connectivity to resources in the VPC
- **Function**: Acts as a router between your VPC and the internet

### **4. Route Table**
```hcl
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.public.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.public.id
  }
}
```
- **Default Route**: `0.0.0.0/0` → Internet Gateway
- **Purpose**: Defines how traffic flows from the subnet to the internet
- **Function**: Routes all outbound traffic through the internet gateway

### **5. Route Table Association**
```hcl
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
```
- **Purpose**: Links the route table to the public subnet
- **Function**: Ensures the subnet uses the defined routing rules

### **6. Security Group**
```hcl
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
}
```
- **Inbound Rules**: Allows all traffic from anywhere (0.0.0.0/0)
- **Outbound Rules**: Allows all traffic to anywhere
- **Protocol**: `-1` means all protocols (TCP, UDP, ICMP)
- **⚠️ Security Note**: This is permissive for development. Restrict for production.

### **7. SSH Key Pair**
```hcl
resource "aws_key_pair" "local_key" {
  key_name   = "local-key"
  public_key = file("~/.ssh/aws_rsa.pub")
}
```
- **Key Name**: `local-key` (visible in AWS Console)
- **Public Key**: Reads from your local SSH public key file
- **Purpose**: Enables SSH access to EC2 instances

### **8. EC2 Instance**
```hcl
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
}
```
- **AMI**: Latest Amazon Linux 2 (automatically selected)
- **Instance Type**: `t2.micro` (free tier eligible)
- **Network**: Deployed in the public subnet
- **Security**: Uses the public security group
- **SSH Access**: Uses the created key pair
- **User Data**: Bootstrap script that:
  - Updates the system
  - Installs Apache web server
  - Starts and enables Apache
  - Creates a custom web page with instance metadata

## 🔄 Resource Dependencies & Flow

```
VPC (aws_vpc.public)
├── Subnet (aws_subnet.public) - depends on VPC
├── Internet Gateway (aws_internet_gateway.public) - depends on VPC
├── Security Group (aws_security_group.public) - depends on VPC
└── Route Table (aws_route_table.public) - depends on VPC & Internet Gateway
    └── Route Table Association (aws_route_table_association.public) - depends on Subnet & Route Table

EC2 Instance (aws_instance.public) - depends on:
├── Subnet
├── Security Group
└── Key Pair (aws_key_pair.local_key)
```

## 📊 Network Architecture

```
Internet
    │
    ▼
Internet Gateway
    │
    ▼
Route Table (0.0.0.0/0 → IGW)
    │
    ▼
Public Subnet (10.0.1.0/24)
    │
    ▼
EC2 Instance
    │
    ▼
Security Group (All traffic allowed)
```

## 🔍 Data Sources Used

### **Availability Zones**
```hcl
data "aws_availability_zones" "available" {
  state = "available"
}
```
- **Purpose**: Dynamically gets available AZs in the region
- **Usage**: Selects the first AZ for subnet placement

### **Amazon Linux 2 AMI**
```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}
```
- **Purpose**: Automatically finds the latest Amazon Linux 2 AMI
- **Filter**: Looks for HVM AMIs with GP2 root volume
- **Owners**: Only Amazon-owned AMIs (security best practice)

## 📝 Terraform Outputs

### **Infrastructure Information**
```hcl
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
```

### **Access Information**
```hcl
output "ssh_command" {
  value       = "ssh -i ~/.ssh/aws_rsa ec2-user@${aws_instance.public.public_ip}"
  description = "SSH command to connect to the instance"
}

output "web_url" {
  value       = "http://${aws_instance.public.public_ip}"
  description = "URL to access the web server"
}
```

## 🚀 Deployment Process

### **1. Infrastructure Creation Order**
1. **VPC** - Foundation network
2. **Internet Gateway** - Internet connectivity
3. **Route Table** - Traffic routing rules
4. **Subnet** - Network segment
5. **Route Table Association** - Link subnet to routing
6. **Security Group** - Network security rules
7. **Key Pair** - SSH access credentials
8. **EC2 Instance** - Compute resource

### **2. Instance Bootstrapping**
The EC2 instance automatically:
- Updates system packages
- Installs Apache web server
- Configures Apache to start on boot
- Creates a custom web page with instance metadata
- Makes the web server accessible on port 80

## 🔧 Resource Management

### **Scaling Considerations**
- **VPC**: Can accommodate multiple subnets across AZs
- **Subnets**: Can add private subnets for database tiers
- **Security Groups**: Can create separate SGs for different tiers
- **EC2**: Can use Auto Scaling Groups for high availability

### **Cost Optimization**
- **Instance Type**: `t2.micro` is free tier eligible
- **Storage**: Uses default GP2 EBS volume
- **Data Transfer**: Monitor outbound data transfer costs
- **Elastic IP**: Not used (costs money when not attached)

### **Security Enhancements**
- **Private Subnets**: Add for database and application tiers
- **NAT Gateway**: For private subnet internet access
- **Restricted Security Groups**: Limit ports and sources
- **VPC Flow Logs**: Monitor network traffic
- **CloudWatch**: Monitor instance metrics

## 🛡️ Security Best Practices

### **Current Configuration (Development)**
- ✅ VPC isolation
- ✅ SSH key-based access
- ✅ Security group attached
- ⚠️ Permissive security group (all traffic allowed)
- ⚠️ Public subnet exposure

### **Production Recommendations**
- **Security Groups**: Restrict to specific ports and sources
- **Private Subnets**: Use for application and database tiers
- **Bastion Host**: Use for secure SSH access
- **VPC Endpoints**: For AWS service access without internet
- **Network ACLs**: Additional subnet-level security
- **WAF**: Web application firewall for web traffic

## 🔄 State Management with S3 Backend

### **Backend Configuration**
```hcl
terraform {
  backend "s3" {
    bucket         = "aws-terraform-state-bucket-4737462"
    key            = "awsinstance-vpc/terraform.tfstate"
    region         = "eu-central-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

### **Benefits**
- **Centralized State**: Team collaboration
- **State Locking**: Prevents concurrent modifications
- **Version History**: S3 versioning for state changes
- **Encryption**: State files encrypted at rest
- **Disaster Recovery**: State backed up in S3

## 📋 Prerequisites

### AWS CLI Configuration
```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, Region (eu-central-1), and output format
```

### Required AWS Permissions
- **S3**: `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`, `s3:ListBucket`
- **DynamoDB**: `dynamodb:GetItem`, `dynamodb:PutItem`, `dynamodb:DeleteItem`
- **EC2**: Full EC2 permissions for VPC, subnet, security group, and instance creation
- **IAM**: Permission to create key pairs

### SSH Key Setup
```bash
# Generate SSH key if you don't have one
ssh-keygen -t rsa -b 4096 -f ~/.ssh/aws_rsa

# Verify the public key exists
ls -la ~/.ssh/aws_rsa.pub
```

## 🚀 Quick Start

### 1. Create S3 Backend Infrastructure
```bash
# Create S3 bucket
aws s3 mb s3://aws-terraform-state-bucket-4737462

# Enable versioning
aws s3api put-bucket-versioning --bucket aws-terraform-state-bucket-4737462 --versioning-configuration Status=Enabled

# Create DynamoDB table
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region eu-central-1
```

### 2. Deploy Infrastructure
```bash
# Initialize Terraform
terraform init -reconfigure

# Plan deployment
terraform plan

# Apply changes
terraform apply
```

### 3. Access Your Resources
```bash
# Get connection information
terraform output

# SSH to instance
ssh -i ~/.ssh/aws_rsa ec2-user@$(terraform output -raw instance_public_ip)

# Access web server
curl http://$(terraform output -raw instance_public_ip)
```

## 🧹 Cleanup
```bash
# Destroy all resources
terraform destroy
```

## 📚 Additional Resources

- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EC2 User Guide](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/)
- [Security Groups](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html)
- [Route Tables](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html)

## 📄 License

This project is for educational purposes. Modify security groups and configurations for production use.
