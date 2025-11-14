#!/bin/bash

# ============================================================================
# Script 03: Create IAM User for Development
# ============================================================================
# This script creates a dedicated IAM user "respondr-dev-user" with
# programmatic access and necessary permissions for this project.
# ============================================================================

set -e

echo "=================================================="
echo "STEP 3: Create IAM User"
echo "=================================================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

IAM_USER="respondr-dev-user"

echo "Creating IAM user: $IAM_USER"
echo ""

# Check if user already exists
if aws iam get-user --user-name $IAM_USER &> /dev/null; then
    echo -e "${YELLOW}✓ IAM user '$IAM_USER' already exists${NC}"
    echo ""
    read -p "Do you want to recreate the user? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Deleting existing user..."
        # Delete access keys first
        ACCESS_KEYS=$(aws iam list-access-keys --user-name $IAM_USER --query 'AccessKeyMetadata[].AccessKeyId' --output text)
        for key in $ACCESS_KEYS; do
            aws iam delete-access-key --user-name $IAM_USER --access-key-id $key
        done
        # Detach policies
        ATTACHED_POLICIES=$(aws iam list-attached-user-policies --user-name $IAM_USER --query 'AttachedPolicies[].PolicyArn' --output text)
        for policy in $ATTACHED_POLICIES; do
            aws iam detach-user-policy --user-name $IAM_USER --policy-arn $policy
        done
        # Delete user
        aws iam delete-user --user-name $IAM_USER
        echo "User deleted."
    else
        echo "Keeping existing user."
        exit 0
    fi
fi

# Create IAM user
echo "Creating IAM user..."
aws iam create-user --user-name $IAM_USER

echo -e "${GREEN}✓ User created${NC}"
echo ""

# Attach managed policies
echo "Attaching policies to user..."
POLICIES=(
    "arn:aws:iam::aws:policy/AmazonS3FullAccess"
    "arn:aws:iam::aws:policy/AmazonTextractFullAccess"
    "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
    "arn:aws:iam::aws:policy/AWSLambda_FullAccess"
    "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
    "arn:aws:iam::aws:policy/IAMFullAccess"
)

for policy in "${POLICIES[@]}"; do
    POLICY_NAME=$(echo $policy | awk -F/ '{print $NF}')
    echo "  - Attaching $POLICY_NAME"
    aws iam attach-user-policy --user-name $IAM_USER --policy-arn $policy
done

echo -e "${GREEN}✓ Policies attached${NC}"
echo ""

# Create access key
echo "Creating access key..."
ACCESS_KEY_OUTPUT=$(aws iam create-access-key --user-name $IAM_USER --output json)

ACCESS_KEY_ID=$(echo $ACCESS_KEY_OUTPUT | jq -r '.AccessKey.AccessKeyId')
SECRET_ACCESS_KEY=$(echo $ACCESS_KEY_OUTPUT | jq -r '.AccessKey.SecretAccessKey')

echo -e "${GREEN}✓ Access key created${NC}"
echo ""

# Save credentials to file (for backup)
mkdir -p config
cat > config/dev_user_credentials.txt <<EOF
AWS_ACCESS_KEY_ID=$ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY=$SECRET_ACCESS_KEY
AWS_DEFAULT_REGION=us-east-1
EOF

chmod 600 config/dev_user_credentials.txt

echo "=================================================="
echo "CREDENTIALS CREATED"
echo "=================================================="
echo ""
echo -e "${YELLOW}Access Key ID:${NC}     $ACCESS_KEY_ID"
echo -e "${YELLOW}Secret Access Key:${NC} $SECRET_ACCESS_KEY"
echo ""
echo -e "${RED}IMPORTANT: These credentials are also saved in:${NC}"
echo "  config/dev_user_credentials.txt"
echo ""
echo -e "${YELLOW}Configuring AWS CLI with new user credentials...${NC}"
echo ""

# Configure AWS CLI with new user credentials
export AWS_ACCESS_KEY_ID=$ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=us-east-1

# Update AWS credentials file
aws configure set aws_access_key_id $ACCESS_KEY_ID
aws configure set aws_secret_access_key $SECRET_ACCESS_KEY
aws configure set region us-east-1

echo "=================================================="
echo "VERIFICATION"
echo "=================================================="
echo ""

sleep 2  # Wait for credentials to propagate

# Verify new credentials
if aws sts get-caller-identity &> /dev/null; then
    IDENTITY=$(aws sts get-caller-identity)
    echo -e "${GREEN}✓ New credentials verified!${NC}"
    echo ""
    echo "$IDENTITY" | jq '.' 2>/dev/null || echo "$IDENTITY"
    echo ""
    echo -e "${GREEN}NEXT STEP:${NC}"
    echo "  Run: ./setup/04_create_s3_buckets.sh"
else
    echo -e "${RED}✗ Credential verification failed${NC}"
    exit 1
fi

echo "=================================================="
