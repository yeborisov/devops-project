# DevOps Project - Simple REST Service

A simple Flask REST service with automated CI/CD, containerization, and AWS deployment.

## Endpoints

- `GET /` — returns plain text "Hello World"
- `GET /hostname` — returns JSON with the machine hostname: `{ "hostname": "..." }`
- `GET /health` — returns JSON health status
- `GET /info` — returns JSON runtime info
- `GET /index` or `/index.html` — HTML landing page (protected with basic auth when enabled)

## Project Structure

```
.
├── main.py                    # Flask application
├── requirements.txt           # Python dependencies
├── Dockerfile                 # Docker image definition
├── .dockerignore             # Docker build exclusions
├── tests/                     # Unit tests
├── .github/workflows/         # CI/CD pipeline
│   └── docker-publish.yml    # Build & push to GHCR
├── terraform/                 # Infrastructure as Code
│   ├── main.tf               # EC2, Security Groups, SSH keys
│   ├── variables.tf          # Input variables
│   ├── outputs.tf            # Outputs (IP, SSH command, etc.)
│   ├── provider.tf           # AWS provider config
│   └── terraform.tfvars.example  # Example configuration
└── ansible/                   # Configuration management
    ├── deploy.yml            # Deployment playbook
    ├── inventory.example     # Inventory template
    └── README.md             # Ansible instructions
```

## Quick Start - Local Development

```bash
# Create and activate a virtualenv
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run the app
python main.py -p 8080

# Bind host (defaults to localhost for safety)
export BIND_HOST="127.0.0.1"

# Optional security settings
# Restrict access to a single hostname (Host header). Leave empty to disable.
export ALLOWED_HOST="example.com"

# Enable HTTP Basic Auth only when HTTPS is used.
export AUTH_ENABLED="true"

# Protect the HTML index with HTTP Basic Auth. Leave empty to disable.
export BASIC_AUTH_USER="admin"
export BASIC_AUTH_PASS="secret"

# Test endpoints
curl http://127.0.0.1:8080/
curl http://127.0.0.1:8080/hostname
curl http://127.0.0.1:8080/health
curl http://127.0.0.1:8080/info

# HTML index (protected if BASIC_AUTH_* is set)
curl -u admin:secret http://127.0.0.1:8080/index

# Run tests
pytest -q
```

## Docker Build & Run

```bash
# Build image
docker build -t devops-project:latest .

# Run container
docker run -d -p 80:80 devops-project:latest

# Test
curl http://localhost/
curl http://localhost/hostname
```

## CI/CD Pipeline

### Continuous Integration (CI)

GitHub Actions automatically on every push to `main`:
1. ✅ Runs tests
2. ✅ Builds Docker image
3. ✅ Pushes to GitHub Container Registry (ghcr.io)

Image is available at: `ghcr.io/yeborisov/devops-project:latest`

### Security Checks

GitHub Actions runs security scans on every push and PR to `main`:
- **Bandit**: Python static analysis
- **pip-audit**: Python dependency vulnerability scan
- **Trivy**: filesystem vulnerability scan

### Continuous Deployment (CD)

**Automated infrastructure + application deployment via GitHub Actions:**
- Go to **Actions** → **Deploy Infrastructure and Application** → **Run workflow**
- Workflow automatically:
  - Sets up S3 backend for Terraform state (if needed)
  - Provisions EC2 infrastructure with Terraform
  - Deploys application with Ansible
  - Verifies deployment with automated tests
- Optionally specify Docker image version
- Deployment requires approval from code owners
- Complete automation from infrastructure to application

📖 **See [DEPLOYMENT.md](DEPLOYMENT.md) for complete setup guide**

## AWS Deployment Guide

This project uses a **separation of concerns** approach:
- **Terraform**: Provisions infrastructure (EC2, Security Groups, SSH keys)
- **Ansible**: Deploys and manages the Docker container

This separation allows you to:
- Update the application without recreating infrastructure
- Deploy new versions with a single command
- Easily rollback if needed
- Reuse the same infrastructure for multiple deployments

### Prerequisites

1. AWS account
2. AWS CLI configured with credentials
3. Terraform installed
4. Ansible installed
5. SSH key pair generated

### Step 1: Generate SSH Key

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/devops-project-key
```

### Step 2: Configure Terraform

```bash
cd terraform

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your settings
vi terraform.tfvars
```

Update the SSH public key in `terraform.tfvars`:
```hcl
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC..."
```

### Step 3: Provision Infrastructure with Terraform

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy infrastructure (EC2, Security Groups, SSH keys)
# Note: This only sets up the infrastructure, not the application
terraform apply

# Save important outputs (IP address, SSH command, etc.)
terraform output
```

**Important**: Terraform only provisions the EC2 instance and installs Docker. The application container is deployed separately using Ansible in the next step.

### Step 4: Deploy Application

You have two options for deployment:

#### Option A: GitHub Actions (Recommended)

Fully automated deployment with approval workflow. The workflow handles everything:
- Terraform state management (S3 + DynamoDB)
- Infrastructure provisioning (EC2, Security Groups, SSH keys)
- Application deployment with Ansible
- Automated verification

1. **Add required secrets to GitHub:**
   ```bash
   # Repository → Settings → Secrets and variables → Actions
   # Add the following secrets:

   # EC2_SSH_PRIVATE_KEY - Your SSH private key
   cat ~/.ssh/devops-project-key

   # SSH_PUBLIC_KEY - Your SSH public key
   cat ~/.ssh/devops-project-key.pub

   # AWS_ACCESS_KEY_ID - From AWS IAM credentials
   # AWS_SECRET_ACCESS_KEY - From AWS IAM credentials
   ```

2. **Setup production environment:**
   - Repository → Settings → Environments → New environment: `production`
   - Add required reviewers (yourself)
   - Save protection rules

3. **Deploy:**
   - Go to **Actions** → **Deploy Infrastructure and Application** → **Run workflow**
   - Choose terraform action: `apply` (or `plan-only` to preview)
   - Optionally specify Docker image version
   - Click **Run workflow**
   - Approve when prompted
   - Workflow automatically provisions infrastructure and deploys application

📖 **See [DEPLOYMENT.md](DEPLOYMENT.md) for complete GitHub Actions setup**

#### Option B: Local Ansible Deployment

Manual deployment from your machine:

```bash
cd ../ansible

# Create inventory from example
cp inventory.example inventory

# Get EC2 IP from Terraform
EC2_IP=$(cd ../terraform && terraform output -raw instance_public_ip)

# Update inventory file with the IP
echo "[webservers]" > inventory
echo "$EC2_IP ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/devops-project-key" >> inventory

# Deploy from GHCR
ansible-playbook -i inventory deploy.yml \
  -e "image=ghcr.io/yeborisov/devops-project:latest"
```

### Step 5: Verify Deployment

```bash
# Get the EC2 public IP
EC2_IP=$(cd terraform && terraform output -raw instance_public_ip)

# Test the application
curl http://$EC2_IP/
curl http://$EC2_IP/hostname
```

### SSH Access

```bash
# Connect to EC2 instance
ssh -i ~/.ssh/devops-project-key ec2-user@$EC2_IP

# Check container status
docker ps

# View logs
docker logs simple-rest
```

## Updating the Application

One of the main advantages of this approach is easy updates:

```bash
# After pushing new code and GitHub Actions builds a new image:

cd ansible

# Simply re-run the Ansible playbook
ansible-playbook -i inventory deploy.yml \
  -e "image=ghcr.io/yeborisov/devops-project:latest"

# Or deploy a specific version
ansible-playbook -i inventory deploy.yml \
  -e "image=ghcr.io/yeborisov/devops-project:v1.2.3"
```

The playbook will:
1. Pull the new image
2. Stop the old container
3. Start the new container
4. Verify it's running

**No need to recreate the EC2 instance or run Terraform again!**

## Why This Approach?

### Terraform + Ansible vs User Data Only

**Old approach (User Data only)**:
- ❌ Runs only once at boot
- ❌ Can't update without recreating EC2
- ❌ Credentials in plaintext
- ❌ No rollback capability
- ❌ Hard to debug failures

**Current approach (Terraform + Ansible)**:
- ✅ Separate infrastructure from deployment
- ✅ Update anytime with one command
- ✅ Credentials managed securely by Ansible
- ✅ Easy rollback to previous versions
- ✅ Idempotent and repeatable
- ✅ Better logging and error handling
- ✅ Can deploy to multiple servers easily

## Cleanup

```bash
cd terraform
terraform destroy
```

## Troubleshooting

**Container not running?**
```bash
ssh -i ~/.ssh/devops-project-key ec2-user@$EC2_IP "docker ps -a"
ssh -i ~/.ssh/devops-project-key ec2-user@$EC2_IP "docker logs simple-rest"
```

**Can't connect via SSH?**
- Check security group allows SSH (port 22)
- Verify SSH key permissions: `chmod 400 ~/.ssh/devops-project-key`
- Check terraform outputs: `terraform output ssh_command`

**Application not responding?**
- Check security group allows HTTP (port 80)
- Verify Docker container is running on port 80
- Check EC2 instance status in AWS console

## Current Deployment

**Live Application**: http://3.68.33.85 (if deployed)

Infrastructure managed by:
- **Terraform** - EC2 instance on Amazon Linux 2023 (t3.micro in eu-central-1)
- **Ansible** - Docker container deployment and management
- **S3 + DynamoDB** - Terraform remote state backend with locking

Container Image: `ghcr.io/yeborisov/devops-project:latest`

## Architecture

```
┌─────────────────┐
│  GitHub Actions │  Push code → Build → Test → Push to GHCR
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Deploy Workflow│  Manual trigger → Approve → Deploy
└────────┬────────┘
         │
         ├──────────────────┐
         ▼                  ▼
    ┌─────────┐        ┌──────────┐
    │Terraform│        │ Ansible  │
    │         │        │          │
    │• EC2    │ ────▶  │• Docker  │
    │• SG     │        │• Deploy  │
    │• Keys   │        │• Verify  │
    └─────────┘        └──────────┘
         │                  │
         ▼                  ▼
    ┌─────────────────────────┐
    │  AWS EC2 (eu-central-1) │
    │  Amazon Linux 2023       │
    │  Docker Container        │
    │  Port 80 (HTTP)          │
    └─────────────────────────┘
```

