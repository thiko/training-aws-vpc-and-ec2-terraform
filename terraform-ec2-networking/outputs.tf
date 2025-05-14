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
