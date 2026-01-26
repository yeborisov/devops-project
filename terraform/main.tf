## EC2 Infrastructure Configuration
##
## This Terraform configuration creates a minimal EC2 setup for hosting
## a containerized REST service. It includes:
## - SSH key pair for secure access
## - Security group with HTTP (80) and optional SSH (22) access
## - EC2 instance with Docker pre-installed via user-data
## - Automatic instance type selection based on region (free-tier friendly)
##
## Provider configuration is in provider.tf
## State backend configuration is in backend.tf

# SSH Key Pair for EC2 access
# Creates a key pair from the provided public key (typically from GitHub Secrets)
resource "aws_key_pair" "deployer" {
  count      = var.ssh_public_key != "" ? 1 : 0
  key_name   = var.ssh_key_name
  public_key = var.ssh_public_key

  tags = {
    Name = var.ssh_key_name
  }
}

# Lookup a recent Amazon Linux 2023 AMI for the region
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# Check whether t2.micro is offered in this region
locals {
  # Map of regions to a free-tier-friendly instance type. This is a best-effort mapping.
  free_tier_map = {
    "us-east-1" = "t2.micro"
    "us-west-2" = "t2.micro"
    "eu-west-1" = "t2.micro"
    "eu-central-1" = "t3.micro"
    "ap-southeast-1" = "t3.micro"
  }

  selected_instance_type = var.instance_type != "" ? var.instance_type : lookup(local.free_tier_map, var.aws_region, "t3.micro")
}

# Use the default VPC for simplicity
data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "http" {
  name        = "allow_http_ssh"
  description = "Allow HTTP and SSH inbound"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = var.allow_ssh && length(trimspace(var.ssh_allowed_cidr)) > 0 ? [1] : []
    content {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [var.ssh_allowed_cidr]
    }
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_http_ssh"
  }
}

## NOTE: SSH ingress is handled by the dynamic `ingress` block above which uses
## `var.ssh_allowed_cidr`. The previous separate `aws_security_group_rule` that
## opened SSH to 0.0.0.0/0 has been removed to avoid accidentally exposing SSH.

# EC2 instance with public IP. The instance will use the selected instance type.
resource "aws_instance" "web" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = local.selected_instance_type
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.http.id]
  key_name                    = var.ssh_public_key != "" ? aws_key_pair.deployer[0].key_name : null

  tags = {
    Name = "simple-rest-ec2"
  }

  # User data script runs on first boot to prepare the instance for deployment
  # This installs Docker and prepares the environment for Ansible
  # The actual container deployment is handled by Ansible for better control
  user_data = <<-EOF
              #!/bin/bash
              set -e  # Exit on any error

              # Update system and install Docker (Amazon Linux 2023 uses dnf, not yum)
              dnf update -y || true
              dnf install -y docker || true

              # Start Docker service and enable it to run on boot
              systemctl enable --now docker

              # Python3 is pre-installed on Amazon Linux 2023, but ensure pip is available
              dnf install -y python3-pip || true

              # Add ec2-user to docker group for non-root Docker access
              # This allows Ansible to manage containers without sudo
              usermod -aG docker ec2-user || true

              # Log completion for debugging purposes
              echo "EC2 user-data completed successfully" > /var/log/user-data.log
  EOF
}
