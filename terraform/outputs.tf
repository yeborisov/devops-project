output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.web.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.web.public_dns
}

output "selected_instance_type" {
  description = "Instance type chosen to launch"
  value       = local.selected_instance_type
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.web.id
}

output "region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}

output "ssh_key_name" {
  description = "SSH key pair name (if configured)"
  value       = var.ssh_public_key != "" ? aws_key_pair.deployer[0].key_name : "No SSH key configured"
}

output "app_url" {
  description = "URL to access the application"
  value       = "http://${aws_instance.web.public_ip}"
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = var.ssh_public_key != "" ? "ssh -i ~/.ssh/${var.ssh_key_name} ec2-user@${aws_instance.web.public_ip}" : "SSH not configured"
}

output "ansible_inventory" {
  description = "Ansible inventory format for easy deployment"
  value       = <<-EOT
    [webservers]
    ${aws_instance.web.public_ip} ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/${var.ssh_key_name}
  EOT
}
