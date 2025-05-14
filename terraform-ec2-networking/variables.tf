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
