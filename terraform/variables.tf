variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "Optional instance type override. If empty a region-appropriate free-tier-friendly instance will be chosen."
  type        = string
  default     = ""
}

variable "allow_ssh" {
  description = "Whether to allow SSH (port 22) from the internet"
  type        = bool
  default     = true
}

variable "ssh_key_name" {
  description = "Name for the SSH key pair in AWS"
  type        = string
  default     = "devops-project-key"
}

variable "ssh_public_key" {
  description = "SSH public key content for EC2 access. Generate with: ssh-keygen -t rsa -b 4096 -f ~/.ssh/devops-project"
  type        = string
  default     = ""
}
