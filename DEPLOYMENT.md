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

#### Required Secret:

- **EC2_SSH_PRIVATE_KEY**: Your SSH private key for EC2 access
  ```bash
  # Display your private key
  cat ~/.ssh/devops-project-key

  # Copy the entire content (including BEGIN/END lines)
  # Paste into GitHub secret
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

### Option 1: Deploy Latest Image

1. Go to **Actions** tab in GitHub
2. Select **Deploy to AWS EC2** workflow
3. Click **Run workflow**
4. Fill in the inputs:
   - **EC2 Public IP**: Your EC2 instance IP (from `terraform output`)
   - **Docker image**: Leave default or specify version
5. Click **Run workflow**
6. **Approve the deployment** when prompted (if you're a code owner)
7. Watch the deployment progress

### Option 2: Deploy Specific Version

Same as above, but specify a tag in the Docker image field:
```
ghcr.io/yeborisov/devops-project:v1.2.3
```

## What Happens During Deployment

1. ✅ Checks out repository code
2. ✅ Installs Ansible
3. ✅ Sets up SSH connection to EC2
4. ✅ Creates Ansible inventory dynamically
5. ✅ Runs Ansible playbook to deploy container
6. ✅ Verifies deployment by testing endpoints
7. ✅ Reports deployment status

## Deployment Approval Flow

Since we use the `production` environment:

1. **Workflow triggered** → Waits for approval
2. **Notification sent** → Code owners receive notification
3. **Manual approval** → Code owner reviews and approves
4. **Deployment proceeds** → Ansible deploys the application
5. **Verification** → Automated tests confirm deployment

## Troubleshooting

### "EC2_SSH_PRIVATE_KEY secret not found"

**Solution:** Add the secret in Repository Settings → Secrets

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

## Next Steps

- Set up Slack/Email notifications for deployment events
- Add deployment frequency limits
- Configure staging environment for testing before production
- Implement blue/green deployments
- Add rollback workflow
