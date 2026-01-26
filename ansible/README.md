# Ansible Deployment

This directory contains the Ansible playbook for deploying the Docker container to EC2.

## Prerequisites

1. Ansible installed locally
2. EC2 instance running (provisioned via Terraform)
3. SSH access to the EC2 instance

## Setup

1. Create inventory file from the example:
```bash
cp inventory.example inventory
```

2. Update the inventory file with your EC2 instance IP:
```bash
# Get the IP from Terraform output
cd ../terraform
terraform output instance_public_ip

# Edit ansible/inventory and replace the IP
```

## Deployment Options

### Option 1: Deploy from GHCR (recommended)

Deploy the pre-built image from GitHub Container Registry:

```bash
ansible-playbook -i inventory deploy.yml \
  -e "image=ghcr.io/yeborisov/devops-project:latest"
```

For private images, add GHCR credentials:
```bash
ansible-playbook -i inventory deploy.yml \
  -e "image=ghcr.io/yeborisov/devops-project:latest" \
  -e "ghcr_username=yeborisov" \
  -e "ghcr_token=YOUR_GITHUB_TOKEN"
```

### Option 2: Build from repository

Clone and build the image on the EC2 instance:

```bash
ansible-playbook -i inventory deploy.yml \
  -e "repo_url=https://github.com/yeborisov/devops-project.git"
```

## Verify Deployment

After running the playbook, test the application:

```bash
# Get the EC2 public IP
EC2_IP=$(cd ../terraform && terraform output -raw instance_public_ip)

# Test the endpoints
curl http://$EC2_IP/
curl http://$EC2_IP/hostname
```

## GitHub Actions Integration

The Ansible playbook is also used by GitHub Actions for automated deployments.
See [../.github/workflows/deploy.yml](../.github/workflows/deploy.yml) for the full workflow.

The workflow:
1. Runs Terraform to provision infrastructure
2. Gets EC2 IP from Terraform output
3. Creates inventory dynamically
4. Runs this Ansible playbook
5. Verifies deployment

## What the Playbook Does

The `deploy.yml` playbook:
- ✅ Ensures Docker is installed and running
- ✅ Pulls the specified Docker image (from GHCR or builds from repo)
- ✅ Stops and removes existing container (if any)
- ✅ Starts new container on port 80 with restart policy
- ✅ Validates deployment

All operations are idempotent - you can run it multiple times safely.

## Troubleshooting

Check if the container is running:
```bash
ssh -i ~/.ssh/devops-project-key ec2-user@$EC2_IP "docker ps"
```

View container logs:
```bash
ssh -i ~/.ssh/devops-project-key ec2-user@$EC2_IP "docker logs simple-rest"
```

Check Ansible connectivity:
```bash
ansible -i inventory -m ping all
```
