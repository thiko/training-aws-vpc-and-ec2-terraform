# Exercise: EC2 Instances and Networking Components with Terraform

## Objective
Learn how to create and configure a networking infrastructure in AWS using Terraform. You'll set up a VPC with public and private subnets, and deploy EC2 instances with appropriate security configurations to enable controlled communication between them. Instead of using SSH keys, you'll use AWS Systems Manager (SSM) for instance access.

## Overview
In this exercise, you'll use the provided Terraform skeleton to create a networking infrastructure with two subnets (public and private) in the same Availability Zone. You'll deploy EC2 instances in each subnet and configure security groups to allow controlled communication between them. This represents a common pattern in cloud architecture where public-facing components can access protected backend services.

## Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform installed (version 1.0.0 or later)
- Basic understanding of AWS networking components (VPC, subnets, security groups)
- The provided Terraform skeleton file

## Steps

### Part 1: Prepare Your Project Structure

1. **Create a project directory**
   - Create a new directory for your Terraform project:
     ```bash
     mkdir terraform-ec2-networking
     cd terraform-ec2-networking
     ```

2. **Set up file structure**
   - Create the following files:
     ```bash
     touch main.tf         # Main configuration file (copy the skeleton here)
     touch variables.tf    # Variable declarations
     touch outputs.tf      # Output definitions
     mkdir -p modules/vpc  # Directory for the VPC module
     ```

3. **Create the VPC module files**
   - Create the following files in the modules/vpc directory:
     ```bash
     touch modules/vpc/main.tf
     touch modules/vpc/variables.tf
     touch modules/vpc/outputs.tf
     ```

### Part 2: Define Variables and Configuration

1. **Update variables.tf** (in project root directory - not in the module!)
   - Create the variable definitions:
     ```hcl
     variable "aws_region" {
       description = "The AWS region to deploy resources"
       type        = string
       default     = "eu-central-1"
     }

     variable "aws_profile" {
       description = "The AWS CLI profile to use"
       type        = string
       default     = "default"
     }

     variable "project_name" {
       description = "Name of the project"
       type        = string
       default     = "terraform-lab"
     }

     variable "environment" {
       description = "Environment name"
       type        = string
       default     = "dev"
     }

     variable "default_tags" {
       description = "Default tags for all resources"
       type        = map(string)
       default = {
         Owner       = "Terraform"
         Environment = "Training"
       }
     }

     variable "vpc_cidr" {
       description = "CIDR block for the VPC"
       type        = string
       default     = "10.0.0.0/16"
     }

     variable "availability_zone" {
       description = "AZ for the subnets"
       type        = string
       default     = "eu-central-1a"
     }

     variable "public_subnet_cidr" {
       description = "CIDR block for the public subnet"
       type        = string
       default     = "10.0.1.0/24"
     }

     variable "private_subnet_cidr" {
       description = "CIDR block for the private subnet"
       type        = string
       default     = "10.0.2.0/24"
     }

     variable "instance_settings" {
       description = "Settings for EC2 instances by environment"
       type        = map(any)
       default = {
         dev = {
           instance_type   = "t2.micro"
           instance_count  = 1
           root_volume_gb  = 8
         }
         prod = {
           instance_type   = "t2.small"
           instance_count  = 2
           root_volume_gb  = 20
         }
       }
     }
     ```

2. **Update main.tf**
   - Copy the **terraform, provider and data sources** provided skeleton code as a base
   - Modify it to match our networking requirements (like the resource names)

### Part 3: Create the VPC Module

1. **Define the VPC module inputs (modules/vpc/variables.tf)**
   ```hcl
   variable "vpc_name" {
     description = "The name of the VPC"
     type        = string
   }

   variable "vpc_cidr" {
     description = "The CIDR block for the VPC"
     type        = string
   }

   variable "enable_dns_hostnames" {
     description = "Should be true to enable DNS hostnames in the VPC"
     type        = bool
     default     = true
   }

   variable "enable_dns_support" {
     description = "Should be true to enable DNS support in the VPC"
     type        = bool
     default     = true
   }

   variable "public_subnet_cidr" {
     description = "The CIDR block for the public subnet"
     type        = string
   }

   variable "private_subnet_cidr" {
     description = "The CIDR block for the private subnet"
     type        = string
   }

   variable "availability_zone" {
     description = "The AZ where the subnets will be created"
     type        = string
   }

   variable "tags" {
     description = "A map of tags to add to all resources"
     type        = map(string)
     default     = {}
   }
   ```

2. **Implement the VPC module (modules/vpc/main.tf)**
   ```hcl
   # VPC
   resource "aws_vpc" "main" {
     cidr_block           = var.vpc_cidr
     enable_dns_hostnames = var.enable_dns_hostnames
     enable_dns_support   = var.enable_dns_support

     tags = merge(
       var.tags,
       {
         Name = "${var.vpc_name}-vpc"
       }
     )
   }

   # Internet Gateway
   resource "aws_internet_gateway" "main" {
     vpc_id = aws_vpc.main.id

     tags = merge(
       var.tags,
       {
         Name = "${var.vpc_name}-igw"
       }
     )
   }

   # Public Subnet
   resource "aws_subnet" "public" {
     vpc_id                  = aws_vpc.main.id
     cidr_block              = var.public_subnet_cidr
     availability_zone       = var.availability_zone
     map_public_ip_on_launch = true

     tags = merge(
       var.tags,
       {
         Name = "${var.vpc_name}-public-subnet"
       }
     )
   }

   # Private Subnet
   resource "aws_subnet" "private" {
     vpc_id            = aws_vpc.main.id
     cidr_block        = var.private_subnet_cidr
     availability_zone = var.availability_zone

     tags = merge(
       var.tags,
       {
         Name = "${var.vpc_name}-private-subnet"
       }
     )
   }

   # Public Route Table
   resource "aws_route_table" "public" {
     vpc_id = aws_vpc.main.id

     route {
       cidr_block = "0.0.0.0/0"
       gateway_id = aws_internet_gateway.main.id
     }

     tags = merge(
       var.tags,
       {
         Name = "${var.vpc_name}-public-rt"
       }
     )
   }

   # Private Route Table
   resource "aws_route_table" "private" {
     vpc_id = aws_vpc.main.id

     tags = merge(
       var.tags,
       {
         Name = "${var.vpc_name}-private-rt"
       }
     )
   }

   # Public Route Table Association
   resource "aws_route_table_association" "public" {
     subnet_id      = aws_subnet.public.id
     route_table_id = aws_route_table.public.id
   }

   # Private Route Table Association
   resource "aws_route_table_association" "private" {
     subnet_id      = aws_subnet.private.id
     route_table_id = aws_route_table.private.id
   }

   # VPC Endpoint for SSM
   # This endpoint enables the basic API communication with the SSM service
   # Required to initiate SSM operations and manage the SSM agent
   # Without this, instances in private subnets cannot communicate with the SSM service
   resource "aws_vpc_endpoint" "ssm" {
     vpc_id            = aws_vpc.main.id
     service_name      = "com.amazonaws.${data.aws_region.current.name}.ssm"
     vpc_endpoint_type = "Interface"
     subnet_ids        = [aws_subnet.private.id]
     security_group_ids = [aws_security_group.vpc_endpoint.id]
     private_dns_enabled = true
     
     tags = merge(
       var.tags,
       {
         Name = "${var.vpc_name}-ssm-endpoint"
       }
     )
   }

   # VPC Endpoint for SSM Messages
   # This endpoint is specifically for Session Manager functionality
   # It enables the bidirectional communication channel required for interactive shell sessions
   # Essential for the 'aws ssm start-session' command to work properly
   resource "aws_vpc_endpoint" "ssmmessages" {
     vpc_id            = aws_vpc.main.id
     service_name      = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
     vpc_endpoint_type = "Interface"
     subnet_ids        = [aws_subnet.private.id]
     security_group_ids = [aws_security_group.vpc_endpoint.id]
     private_dns_enabled = true
     
     tags = merge(
       var.tags,
       {
         Name = "${var.vpc_name}-ssmmessages-endpoint"
       }
     )
   }

   # VPC Endpoint for EC2 Messages
   # This endpoint allows the SSM agent on the EC2 instance to send messages back to the SSM service
   # It's responsible for reporting command status and results back to SSM
   # All three endpoints (ssm, ssmmessages, ec2messages) are required for full SSM functionality in private subnets
   resource "aws_vpc_endpoint" "ec2messages" {
     vpc_id            = aws_vpc.main.id
     service_name      = "com.amazonaws.${data.aws_region.current.name}.ec2messages"
     vpc_endpoint_type = "Interface"
     subnet_ids        = [aws_subnet.private.id]
     security_group_ids = [aws_security_group.vpc_endpoint.id]
     private_dns_enabled = true
     
     tags = merge(
       var.tags,
       {
         Name = "${var.vpc_name}-ec2messages-endpoint"
       }
     )
   }

   # Security Group for VPC Endpoints
   resource "aws_security_group" "vpc_endpoint" {
     name        = "${var.vpc_name}-vpc-endpoint-sg"
     description = "Security group for VPC endpoints"
     vpc_id      = aws_vpc.main.id

     ingress {
       from_port   = 443
       to_port     = 443
       protocol    = "tcp"
       cidr_blocks = [var.vpc_cidr]
     }

     tags = merge(
       var.tags,
       {
         Name = "${var.vpc_name}-vpc-endpoint-sg"
       }
     )
   }

   # Data source to retrieve the current region
   data "aws_region" "current" {}
   ```

3. **Define the VPC module outputs (modules/vpc/outputs.tf)**
   ```hcl
   output "vpc_id" {
     description = "The ID of the VPC"
     value       = aws_vpc.main.id
   }

   output "vpc_cidr" {
     description = "The CIDR of the VPC"
     value       = aws_vpc.main.cidr_block
   }

   output "public_subnet_id" {
     description = "The ID of the public subnet"
     value       = aws_subnet.public.id
   }

   output "private_subnet_id" {
     description = "The ID of the private subnet"
     value       = aws_subnet.private.id
   }

   output "public_route_table_id" {
     description = "The ID of the public route table"
     value       = aws_route_table.public.id
   }

   output "private_route_table_id" {
     description = "The ID of the private route table"
     value       = aws_route_table.private.id
   }

   output "vpc_endpoint_sg_id" {
     description = "The ID of the security group for VPC endpoints"
     value       = aws_security_group.vpc_endpoint.id
   }
   ```

### Part 4: Update Main Configuration

1. **Update the main.tf file**
   - Keep the existing **terraform, provider** blocks, and **data sources**
   - Replace the module and resource configurations:

   ```hcl
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
       {[myplan](terraform-ec2-networking/myplan)
         Name = "${local.common_name}-private-instance"
       }
     )
   }
   ```

### Part 5: Configure Outputs

1. **Define outputs in outputs.tf**
   ```hcl
   output "vpc_id" {
     description = "The ID of the VPC"
     value       = module.vpc.vpc_id
   }

   output "public_subnet_id" {
     description = "The ID of the public subnet"
     value       = module.vpc.public_subnet_id
   }

   output "private_subnet_id" {
     description = "The ID of the private subnet"
     value       = module.vpc.private_subnet_id
   }

   output "public_instance_ip" {
     description = "The public IP address of the public instance"
     value       = aws_instance.public.public_ip
   }

   output "public_instance_id" {
     description = "The ID of the public instance"
     value       = aws_instance.public.id
   }

   output "private_instance_id" {
     description = "The ID of the private instance"
     value       = aws_instance.private.id
   }

   output "private_instance_private_ip" {
     description = "The private IP address of the private instance"
     value       = aws_instance.private.private_ip
   }

   output "ssm_connection_public" {
     description = "Command to connect to the public instance via SSM"
     value       = "aws ssm start-session --target ${aws_instance.public.id}"
   }

   output "ssm_connection_private" {
     description = "Command to connect to the private instance via SSM"
     value       = "aws ssm start-session --target ${aws_instance.private.id}"
   }
   ```

### Part 6: Deploy the Infrastructure

1. **Initialize the Terraform project**
   ```bash
   terraform init
   ```

2. **Validate the configuration**
   ```bash
   terraform validate
   ```

3. **Preview the changes**
   ```bash
   terraform plan
   ```

4. **Apply the changes**
   ```bash
   terraform apply
   ```
   - Type "yes" when prompted to confirm

5. **Note the outputs**
   - The public IP of your public instance
   - The private IP of your private instance
   - The commands to connect to the instances via SSM

### Part 7: Test Connectivity

1. **Connect to the public instance via SSM**
   ```bash
   aws ssm start-session --target <public_instance_id>
   ```

2. **From the public instance, try to ping the private instance**
   ```bash
   ping <private_instance_private_ip>
   ```

3. **From the public instance, try to access the web server on the private instance**
   ```bash
   curl http://<private_instance_private_ip>
   ```

4. **Connect directly to the private instance**
   ```bash
   aws ssm start-session --target <private_instance_id>
   ```

### Part 8: Clean Up Resources

1. **Destroy all resources**
   ```bash
   terraform destroy
   ```
   - Type "yes" when prompted to confirm

## Verification

You have successfully completed this exercise when:
- You've created a VPC with public and private subnets in the same AZ
- You've deployed EC2 instances in both the public and private subnets
- You've configured security groups to allow communication from the public instance to the private instance
- You can connect to both instances via SSM
- You can ping and access the web server on the private instance from the public instance
- You've successfully cleaned up all resources

## Understanding the Architecture

This exercise demonstrates a common architectural pattern in AWS:

1. **Public subnet**: Contains resources that need to be accessible from the internet
   - Has a route to the internet gateway
   - EC2 instances get public IP addresses

2. **Private subnet**: Contains resources that should not be directly accessible from the internet
   - No direct route to the internet
   - Instances can only be accessed from within the VPC or through other AWS services

3. **Security groups**: Act as virtual firewalls
   - The public security group allows outbound traffic
   - The private security group only allows access from the public security group

4. **Systems Manager (SSM)**: Enables connection to instances without SSH keys
   - Uses IAM roles for authentication
   - Requires VPC endpoints for private subnets

This pattern provides increased security by limiting direct access to your backend resources.

## Common Issues and Troubleshooting

1. **SSM connection issues**:
   - Ensure the IAM role has the correct permissions
   - Verify the SSM agent is running on the instances
   - Make sure the VPC endpoints are correctly configured

2. **Connectivity issues**:
   - Verify that the security groups allow the necessary traffic
   - Check that the instances are in the correct subnets
   - Ensure the route tables are correctly associated with the subnets

3. **Terraform errors**:
   - Check for syntax errors in your configuration files
   - Ensure you have the necessary AWS permissions
   - Verify that your AWS credentials are correctly configured

## Extended Learning

1. **Add a NAT Gateway**:
   - Allow private instances to access the internet without being directly accessible
   - Update the private route table to route internet traffic through the NAT Gateway

2. **Implement auto scaling**:
   - Replace the EC2 instances with auto scaling groups
   - Configure scaling policies based on CPU utilization

3. **Add a load balancer**:
   - Deploy an Application Load Balancer in the public subnet
   - Configure the load balancer to route traffic to instances in the private subnet
