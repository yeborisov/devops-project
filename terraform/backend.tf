# Terraform remote state backend configuration
# This stores the Terraform state in S3 with DynamoDB locking

# IMPORTANT: Before using this backend, you need to:
# 1. Create an S3 bucket for state storage
# 2. Create a DynamoDB table for state locking
# 3. Uncomment the terraform block below
# 4. Run: terraform init -migrate-state

terraform {
  backend "s3" {
    bucket         = "devops-project-terraform-state"  # Change to your bucket name
    key            = "prod/terraform.tfstate"          # Path within the bucket
    region         = "eu-central-1"
    encrypt        = true                              # Enable encryption at rest
    dynamodb_table = "devops-project-terraform-locks"  # For state locking
  }
}

# Prerequisites setup (run these AWS CLI commands first):
#
# 1. Create S3 bucket:
#    aws s3api create-bucket \
#      --bucket devops-project-terraform-state \
#      --region eu-central-1 \
#      --create-bucket-configuration LocationConstraint=eu-central-1
#
# 2. Enable versioning on the bucket:
#    aws s3api put-bucket-versioning \
#      --bucket devops-project-terraform-state \
#      --versioning-configuration Status=Enabled
#
# 3. Enable encryption:
#    aws s3api put-bucket-encryption \
#      --bucket devops-project-terraform-state \
#      --server-side-encryption-configuration '{
#        "Rules": [{
#          "ApplyServerSideEncryptionByDefault": {
#            "SSEAlgorithm": "AES256"
#          }
#        }]
#      }'
#
# 4. Block public access:
#    aws s3api put-public-access-block \
#      --bucket devops-project-terraform-state \
#      --public-access-block-configuration \
#        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
#
# 5. Create DynamoDB table for locking:
#    aws dynamodb create-table \
#      --table-name devops-project-terraform-locks \
#      --attribute-definitions AttributeName=LockID,AttributeType=S \
#      --key-schema AttributeName=LockID,KeyType=HASH \
#      --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
#      --region eu-central-1
#
# After setup:
# 1. Uncomment the terraform block above
# 2. Run: terraform init -migrate-state
# 3. Terraform will ask to migrate local state to S3
# 4. Answer "yes" to migrate
# 5. Delete local terraform.tfstate files (they're in .gitignore)
