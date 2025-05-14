# ==============================================================
# TERRAFORM CONFIGURATION SKELETON
# ==============================================================

# ----------------------
# Terraform Block
# ----------------------
# Specifies the required Terraform version and providers
terraform {
  # Define required Terraform version
  required_version = ">= 1.0.0"

  # Define required providers with versions
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # Add other providers as needed
    # azurerm = {
    #   source  = "hashicorp/azurerm"
    #   version = "~> 3.0"
    # }
  }

  # It not possible to use variables here :-( But you can make it overwritable (check TF Backend Documentation)
  #   Or things like Terragrunt
  # Backend configuration (where state will be stored)
  backend "local" {
    path = ".tfstate/terraform.tfstate"
  }


  # Remote backend example:
  # backend "s3" {
  #   bucket         = "terraform-state-bucket"
  #   key            = "path/to/terraform.tfstate"
  #   region         = "eu-central-1"
  #   #dynamodb_table = "terraform-locks" # For state locking (!! old way !!)
  #   use_lockfile    = true  #S3 native locking! new! (replace dynamodb locks)
  #   encrypt        = true
  # }
}

# ----------------------
# Provider Blocks
# ----------------------
# Main provider
provider "aws" {
  region = var.aws_region

  # Optional profile from AWS config
  profile = var.aws_profile

  # Optional default tags applied to all resources
  default_tags {
    tags = var.default_tags
  }
}

# ----------------------
# Locals
# ----------------------
# For intermediate computed values or to avoid repetition
locals {
  common_name = "${var.project_name}-${var.environment}"

  # Example computed value based on variables
  # Another common way: instance_count = var.environment == "prod" ? 3 : 1
  instance_count = var.instance_settings[var.environment].instance_count

  # Common tags that will be applied to all resources
  common_tags = merge(
    var.default_tags,
    {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  )
}

# ----------------------
# Data Sources
# ----------------------
# Getting existing resources or information from AWS
data "aws_vpc" "default" {
  # This data provider is UNUSED - only for demo purposes
  # Get data fom DEFAULT VPC from current region (which we dont use here)
  default = true
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# ----------------------
# IAM Role for EC2 Instances
# ----------------------
resource "aws_iam_role" "ssm_role" {
  name = "${local.common_name}-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# Attach SSM Managed Policy to Role
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance Profile
resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "${local.common_name}-ssm-instance-profile"
  role = aws_iam_role.ssm_role.name
}

# ----------------------
# Module Calls
# ----------------------
module "vpc" {
  source = "./modules/vpc"

  vpc_name           = local.common_name
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  availability_zone  = var.availability_zone

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.common_tags
}

# ----------------------
# Security Groups
# ----------------------
# Security Group for public instance
resource "aws_security_group" "public" {
  name        = "${local.common_name}-public-sg"
  description = "Security group for public instances"
  vpc_id      = module.vpc.vpc_id

  # Allow HTTPS outbound for SSM access
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow outbound HTTPS traffic for SSM"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.common_name}-public-sg"
    }
  )
}

# Security Group for private instance
resource "aws_security_group" "private" {
  name        = "${local.common_name}-private-sg"
  description = "Security group for private instances"
  vpc_id      = module.vpc.vpc_id

  # Allow ICMP (ping) from public subnet only
  ingress {
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    security_groups = [aws_security_group.public.id]
    description     = "Allow ICMP from public security group"
  }

  # Allow HTTP from public subnet only (for testing)
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.public.id]
    description     = "Allow HTTP from public security group"
  }

  # Allow HTTPS outbound for SSM access
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow outbound HTTPS traffic for SSM"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.common_name}-private-sg"
    }
  )
}

# ----------------------
# EC2 Instances
# ----------------------
# Public EC2 Instance
resource "aws_instance" "public" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_settings[var.environment].instance_type
  subnet_id              = module.vpc.public_subnet_id
  vpc_security_group_ids = [aws_security_group.public.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_instance_profile.name

  root_block_device {
    volume_size = var.instance_settings[var.environment].root_volume_gb
  }

  user_data = <<-EOF
       #!/bin/bash
       echo "Hello from the public instance!"
       # Amazon SSM Agent is included by default in Amazon Linux 2
       yum update -y
       # Install some useful tools for testing
       yum install -y httpd curl nc
       systemctl enable httpd
       systemctl start httpd
       echo "<h1>Public Instance</h1>" > /var/www/html/index.html
       EOF

  tags = merge(
    local.common_tags,
    {
      Name = "${local.common_name}-public-instance"
    }
  )
}

# Private EC2 Instance
resource "aws_instance" "private" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_settings[var.environment].instance_type
  subnet_id              = module.vpc.private_subnet_id
  vpc_security_group_ids = [aws_security_group.private.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_instance_profile.name

  root_block_device {
    volume_size = var.instance_settings[var.environment].root_volume_gb
  }

  user_data = <<-EOF
       #!/bin/bash
       echo "Hello from the private instance!"
       # Amazon SSM Agent is included by default in Amazon Linux 2
       yum update -y
       # Install some useful tools for testing
       yum install -y httpd curl nc
       systemctl enable httpd
       systemctl start httpd
       echo "<h1>Private Instance</h1>" > /var/www/html/index.html
       EOF

  tags = merge(
    local.common_tags,
    {
      Name = "${local.common_name}-private-instance"
    }
  )
}
