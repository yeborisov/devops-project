# GitHub Actions Deployment Guide

This guide explains how to set up automated deployment to AWS EC2 using GitHub Actions.

## Deployment Architecture

```
Push to main → Build & Test → Push to GHCR
                                    ↓
              Manual trigger → Deploy to EC2 (requires approval)
```

## Prerequisites

1. EC2 instance provisioned via Terraform
2. SSH access to EC2 instance
3. GitHub repository with Actions enabled
4. Code owner permissions (for deployment approval)

## Setup Instructions

### Step 1: Configure GitHub Secrets

Add the following secrets to your GitHub repository:

**Repository → Settings → Secrets and variables → Actions → New repository secret**

#### Required Secrets:

- **EC2_SSH_PRIVATE_KEY**: Your SSH private key for EC2 access
  ```bash
  # Display your private key
  cat ~/.ssh/devops-project-key

  # Copy the entire content (including BEGIN/END lines)
  # Paste into GitHub secret
  ```

- **SSH_PUBLIC_KEY**: Your SSH public key for creating EC2 key pair
  ```bash
  # Display your public key
  cat ~/.ssh/devops-project-key.pub

  # Copy the entire content (starts with ssh-rsa)
  # Paste into GitHub secret
  ```

- **AWS_ACCESS_KEY_ID**: Your AWS access key
  ```bash
  # Get from AWS IAM user credentials
  # The workflow uses this to provision infrastructure with Terraform
  ```

- **AWS_SECRET_ACCESS_KEY**: Your AWS secret access key
  ```bash
  # Get from AWS IAM user credentials
  # Keep this secret safe - never commit to git
  ```

### Step 2: Configure Production Environment

1. **Create Production Environment:**
   - Go to: **Repository → Settings → Environments**
   - Click **New environment**
   - Name: `production`
   - Click **Configure environment**

2. **Add Protection Rules:**
   - ✅ **Required reviewers**: Add yourself (or team members)
   - ✅ **Wait timer**: 0 minutes (or set delay if desired)
   - ⚠️ **Deployment branches**: Only `main` branch
   - Click **Save protection rules**

3. **Environment Secrets (optional):**
   If you want environment-specific secrets, add them here.
   Otherwise, repository secrets will be used.

### Step 3: Verify CODEOWNERS

The `.github/CODEOWNERS` file ensures only authorized users can approve deployments:

```
* @yeborisov
/terraform/ @yeborisov
/ansible/ @yeborisov
/.github/workflows/deploy.yml @yeborisov
```

Update with your GitHub username if different.

## How to Deploy

### Option 1: Full Infrastructure + Application Deployment

1. Go to **Actions** tab in GitHub
2. Select **Deploy Infrastructure and Application** workflow
3. Click **Run workflow**
4. Fill in the inputs:
   - **Docker image**: Leave default for latest, or specify version
   - **Terraform action**: Choose `apply` for full deployment
5. Click **Run workflow**
6. **Approve the deployment** when prompted (if you're a code owner)
7. Watch the deployment progress

The workflow will:
- Run Terraform to create/update EC2 infrastructure
- Get the EC2 IP address from Terraform output
- Deploy the application with Ansible
- Verify the deployment

### Option 2: Terraform Plan Only (Preview Changes)

Same as above, but select **Terraform action: plan-only**. This will show you what Terraform will do without actually applying changes.

### Option 3: Deploy Specific Version

Specify a tag in the Docker image field:
```
ghcr.io/yeborisov/devops-project:v1.2.3
```

**Note**: The workflow now runs Terraform and gets the EC2 IP directly from Terraform output!

## What Happens During Deployment

1. ✅ Checks out repository code
2. ✅ Configures AWS credentials
3. ✅ Sets up Terraform
4. ✅ Creates Terraform tfvars with secrets (SSH keys)
5. ✅ Runs `terraform init`
6. ✅ Runs `terraform plan`
7. ✅ Runs `terraform apply` (creates/updates EC2 infrastructure)
8. ✅ Gets EC2 IP address from Terraform output
9. ✅ Waits for EC2 user-data to complete (Docker installation)
10. ✅ Installs Ansible
11. ✅ Sets up SSH connection to EC2
12. ✅ Creates Ansible inventory dynamically
13. ✅ Runs Ansible playbook to deploy container
14. ✅ Verifies deployment by testing endpoints
15. ✅ Reports deployment status

**Key Benefits:**
- Full infrastructure automation (no manual Terraform runs needed)
- Terraform state managed in workflow
- EC2 IP directly from Terraform output (always accurate)
- Single workflow for infrastructure + application deployment

## Deployment Approval Flow

Since we use the `production` environment:

1. **Workflow triggered** → Waits for approval
2. **Notification sent** → Code owners receive notification
3. **Manual approval** → Code owner reviews and approves
4. **Deployment proceeds** → Ansible deploys the application
5. **Verification** → Automated tests confirm deployment

## Troubleshooting

### "AWS credentials not found" or "Unable to locate credentials"

**Solution:**
1. Add **AWS_ACCESS_KEY_ID** and **AWS_SECRET_ACCESS_KEY** secrets in Repository Settings → Secrets
2. Ensure the AWS IAM user has permissions for EC2, including:
   - `ec2:*` (for Terraform to create resources)
   - Or more restrictive: `ec2:RunInstances`, `ec2:DescribeInstances`, `ec2:CreateKeyPair`, etc.
3. Verify the credentials are correct and not expired

### "SSH_PUBLIC_KEY secret not found"

**Solution:**
1. Add **SSH_PUBLIC_KEY** secret in Repository Settings → Secrets
2. Get the public key: `cat ~/.ssh/devops-project-key.pub`
3. Copy the entire content (starts with `ssh-rsa`)

### "EC2_SSH_PRIVATE_KEY secret not found"

**Solution:** Add the secret in Repository Settings → Secrets

### Terraform errors during apply

**Solution:**
1. Check the workflow logs for specific Terraform errors
2. Common issues:
   - AWS quotas/limits reached
   - Invalid SSH key format
   - Security group conflicts
   - Region-specific AMI not available
3. You can test locally: `cd terraform && terraform plan`

### "Waiting for approval from environment protection rules"

**Solution:**
1. Check your email for approval notification
2. Go to Actions → Click on the running workflow
3. Click **Review deployments**
4. Approve the deployment

### "Permission denied (publickey)"

**Solution:**
1. Verify the SSH private key is correct
2. Ensure the EC2 security group allows SSH (port 22)
3. Check that the EC2 instance has the corresponding public key

### "Connection refused" when testing endpoints

**Solution:**
1. SSH into EC2 and check if Docker container is running: `docker ps`
2. Check container logs: `docker logs simple-rest`
3. Verify security group allows HTTP (port 80)

## Security Best Practices

✅ **SSH keys** are stored as GitHub secrets (encrypted at rest)
✅ **Manual approval** required for production deployments
✅ **Code owners** are the only users who can approve
✅ **Audit log** available in GitHub Actions history
✅ **No credentials** in workflow files or code

## Alternative: Deploy from Local Machine

If GitHub Actions is unavailable, you can still deploy manually:

```bash
cd ansible
ansible-playbook -i inventory deploy.yml \
  -e "image=ghcr.io/yeborisov/devops-project:latest"
```

See [ansible/README.md](ansible/README.md) for details.

## Monitoring Deployments

View deployment history:
- **Repository → Actions → Deploy to AWS EC2**
- Filter by status (success/failure)
- Click on any run to see logs

## Important Notes

### Terraform State Management

**Current Setup (Default):**
- Terraform state is **NOT persisted** between workflow runs
- Each workflow run starts with fresh state
- This means Terraform will try to create new resources each time

**Implications:**
- ⚠️ Running the workflow multiple times will create duplicate EC2 instances
- ⚠️ You should manually destroy old instances: `terraform destroy` locally
- ⚠️ Or use AWS Console to terminate old instances before re-running

**Recommended for Production (Remote State):**

Set up **Terraform Remote State** (S3 backend) to persist state between runs:

1. **Setup Remote State** (one-time):
   ```bash
   cd terraform
   ./setup-remote-state.sh
   ```

2. **Enable backend**:
   - Edit `terraform/backend.tf`
   - Uncomment the `terraform` block

3. **Migrate local state**:
   ```bash
   cd terraform
   terraform init -migrate-state
   ```

4. **Update workflow**:
   - The workflow will automatically use remote state on next run
   - No more duplicate instances!

**Benefits of Remote State:**
- ✅ State persists between workflow runs
- ✅ No duplicate resources created
- ✅ Team collaboration (multiple people can work on same infrastructure)
- ✅ State locking (prevents concurrent modifications)
- ✅ State versioning and encryption

See [terraform/README.md](terraform/README.md) for detailed instructions.

## Next Steps

- **Set up Terraform Remote State** (S3 backend) for production use
- Set up Slack/Email notifications for deployment events
- Add deployment frequency limits
- Configure staging environment for testing before production
- Implement blue/green deployments
- Add rollback workflow
