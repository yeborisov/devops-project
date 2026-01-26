## Provider configuration moved to provider.tf

# SSH Key Pair for EC2 access
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

# SSH access security group rule (conditional)
resource "aws_security_group_rule" "ssh" {
  count             = var.allow_ssh ? 1 : 0
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.http.id
  description       = "SSH"
}

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

  # User data: Install Docker and Python for Ansible
  # Container deployment is handled by Ansible for better control and repeatability
  user_data = <<-EOF
              #!/bin/bash
              set -e

              # Install Docker (Amazon Linux 2023 uses dnf)
              dnf update -y || true
              dnf install -y docker || true
              systemctl enable --now docker

              # Python3 is pre-installed on Amazon Linux 2023
              dnf install -y python3-pip || true

              # Add ec2-user to docker group for non-root access
              usermod -aG docker ec2-user || true

              # Signal completion
              echo "EC2 user-data completed successfully" > /var/log/user-data.log
  EOF
}
