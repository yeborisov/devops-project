#!/bin/bash
# Setup script for Terraform remote state backend (S3 + DynamoDB)
# Run this ONCE to set up the infrastructure for storing Terraform state

set -e

# Configuration
BUCKET_NAME="devops-project-terraform-state"
DYNAMODB_TABLE="devops-project-terraform-locks"
REGION="eu-central-1"

echo "🚀 Setting up Terraform remote state backend..."
echo ""
echo "Configuration:"
echo "  S3 Bucket: $BUCKET_NAME"
echo "  DynamoDB Table: $DYNAMODB_TABLE"
echo "  Region: $REGION"
echo ""

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &>/dev/null; then
    echo "❌ AWS CLI is not configured or credentials are invalid"
    echo "Run: aws configure"
    exit 1
fi

echo "✅ AWS credentials are valid"
echo ""

# 1. Create S3 bucket
echo "📦 Creating S3 bucket: $BUCKET_NAME"
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "✅ Bucket already exists"
else
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" \
        --create-bucket-configuration LocationConstraint="$REGION"
    echo "✅ Bucket created"
fi

# 2. Enable versioning
echo "🔄 Enabling versioning..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled
echo "✅ Versioning enabled"

# 3. Enable encryption
echo "🔒 Enabling encryption..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }]
    }'
echo "✅ Encryption enabled"

# 4. Block public access
echo "🛡️  Blocking public access..."
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
      "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
echo "✅ Public access blocked"

# 5. Create DynamoDB table
echo "🗄️  Creating DynamoDB table: $DYNAMODB_TABLE"
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$REGION" &>/dev/null; then
    echo "✅ Table already exists"
else
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region "$REGION"

    echo "⏳ Waiting for table to be active..."
    aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE" --region "$REGION"
    echo "✅ Table created"
fi

echo ""
echo "🎉 Remote state backend setup complete!"
echo ""
echo "Next steps:"
echo "1. Edit backend.tf and uncomment the terraform block"
echo "2. Run: terraform init -migrate-state"
echo "3. Answer 'yes' when prompted to migrate state"
echo "4. Your state is now stored remotely in S3!"
echo ""
echo "Resources created:"
echo "  - S3 Bucket: $BUCKET_NAME (with versioning and encryption)"
echo "  - DynamoDB Table: $DYNAMODB_TABLE (for state locking)"
echo ""
