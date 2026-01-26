# Terraform Infrastructure

This directory contains Terraform configurations for provisioning AWS EC2 infrastructure.

## Files

- **main.tf** - Main infrastructure resources (EC2, security groups, SSH keys)
- **variables.tf** - Input variables
- **outputs.tf** - Output values
- **provider.tf** - AWS provider configuration
- **backend.tf** - Remote state backend configuration (S3 + DynamoDB)
- **terraform.tfvars** - Variable values (gitignored, contains secrets)
- **terraform.tfvars.example** - Example variable values

## Local Development

### Quick Start

1. Copy example tfvars:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` with your values:
   - Add your SSH public key
   - Adjust region if needed

3. Initialize Terraform:
   ```bash
   terraform init
   ```

4. Plan infrastructure changes:
   ```bash
   terraform plan
   ```

5. Apply changes:
   ```bash
   terraform apply
   ```

## Remote State Setup (Recommended for Production)

By default, Terraform stores state locally in `terraform.tfstate`. For production use, you should store state remotely in S3.

### Why Remote State?

- **Team collaboration**: Multiple people can work on the same infrastructure
- **State locking**: Prevents concurrent modifications
- **State versioning**: S3 versioning keeps history of state changes
- **Encryption**: State is encrypted at rest in S3
- **CI/CD integration**: GitHub Actions can access the same state

### Setup Instructions

1. **Run the setup script** (creates S3 bucket and DynamoDB table):
   ```bash
   ./setup-remote-state.sh
   ```

   This creates:
   - S3 bucket: `devops-project-terraform-state`
   - DynamoDB table: `devops-project-terraform-locks`

2. **Enable backend in backend.tf**:
   ```bash
   # Edit backend.tf and uncomment the terraform block
   nano backend.tf
   ```

3. **Migrate state to S3**:
   ```bash
   terraform init -migrate-state
   ```

   Terraform will ask: "Do you want to copy existing state to the new backend?"
   Answer: `yes`

4. **Verify**:
   ```bash
   # Check S3 bucket
   aws s3 ls s3://devops-project-terraform-state/

   # Your local terraform.tfstate is now obsolete (safe to delete)
   ```

### Using Remote State in GitHub Actions

Once remote state is set up, update `.github/workflows/deploy.yml`:

1. Add backend configuration to Terraform Init step
2. Workflow will automatically use remote state
3. No more duplicate instances on each run!

See `backend.tf` for details.

## Outputs

After `terraform apply`, you can get outputs:

```bash
# Get EC2 public IP
terraform output instance_public_ip

# Get SSH command
terraform output -raw ssh_command

# Get Ansible inventory
terraform output -raw ansible_inventory
```

## Destroying Infrastructure

To tear down all resources:

```bash
terraform destroy
```

**Note**: This will terminate the EC2 instance and delete all resources.

## Security

- `terraform.tfvars` is gitignored (contains SSH keys and secrets)
- Never commit `terraform.tfstate` to git (contains infrastructure details)
- Use IAM user with minimal permissions (not root account)
- SSH keys are managed securely via AWS Key Pairs

## GitHub Actions Integration

The GitHub Actions workflow (`.github/workflows/deploy.yml`) runs Terraform automatically:

1. Creates `terraform.tfvars` from GitHub Secrets
2. Runs `terraform init`, `terraform plan`, `terraform apply`
3. Gets EC2 IP from Terraform output
4. Deploys application with Ansible

See [DEPLOYMENT.md](../DEPLOYMENT.md) for details.

## Troubleshooting

### "Error: Error acquiring the state lock"

Someone else is running Terraform. Wait for them to finish, or:

```bash
# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

### "Error: creating EC2 Instance: InvalidKeyPair.NotFound"

Your SSH key pair doesn't exist in AWS. Make sure `ssh_public_key` is set in `terraform.tfvars`.

### "Error: Error launching source instance: InsufficientInstanceCapacity"

AWS doesn't have capacity for the instance type in that AZ. Try again or use a different region.

## IAM Permissions Required

Your AWS IAM user needs these permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "s3:*",
        "dynamodb:*"
      ],
      "Resource": "*"
    }
  ]
}
```

Or use the AWS managed policy: `PowerUserAccess`
