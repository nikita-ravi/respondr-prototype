#!/bin/bash

# ============================================================================
# Script 06: Create IAM Role for Lambda
# ============================================================================
# Creates IAM role "RespondrDocProcessorRole" with:
# - Trust policy for Lambda service
# - Permissions for S3, Textract, DynamoDB, and CloudWatch Logs
# ============================================================================

set -e

echo "=================================================="
echo "STEP 6: Create Lambda IAM Role"
echo "=================================================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ROLE_NAME="RespondrDocProcessorRole"
TRUST_POLICY_FILE="config/lambda-trust-policy.json"

echo "Creating IAM role: $ROLE_NAME"
echo ""

# Check if trust policy file exists
if [ ! -f "$TRUST_POLICY_FILE" ]; then
    echo -e "${RED}✗ Trust policy file not found: $TRUST_POLICY_FILE${NC}"
    exit 1
fi

# Check if role already exists
if aws iam get-role --role-name $ROLE_NAME &> /dev/null; then
    echo -e "${YELLOW}✓ IAM role '$ROLE_NAME' already exists${NC}"
    echo ""

    # Get role ARN
    ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text)
    echo "Role ARN: $ROLE_ARN"

    read -p "Do you want to update the role policies? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing role."
        # Save role ARN to config
        echo "$ROLE_ARN" > config/lambda_role_arn.txt
        echo ""
        echo -e "${GREEN}NEXT STEP:${NC}"
        echo "  Run: ./setup/07_deploy_lambda.sh"
        echo "=================================================="
        exit 0
    fi
else
    # Create the role
    echo "Creating role with trust policy..."
    aws iam create-role \
        --role-name $ROLE_NAME \
        --assume-role-policy-document file://$TRUST_POLICY_FILE \
        --description "Execution role for Respondr Document Processor Lambda function"

    echo -e "${GREEN}✓ Role created${NC}"
    echo ""
fi

# Attach managed policies
echo "Attaching managed policies..."

POLICIES=(
    "arn:aws:iam::aws:policy/AmazonS3FullAccess"
    "arn:aws:iam::aws:policy/AmazonTextractFullAccess"
    "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
    "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
)

for policy in "${POLICIES[@]}"; do
    POLICY_NAME=$(echo $policy | awk -F/ '{print $NF}')
    echo "  - Attaching $POLICY_NAME"
    aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn $policy
done

echo -e "${GREEN}✓ Policies attached${NC}"
echo ""

# Get role ARN
ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text)

# Save role ARN to config
echo "$ROLE_ARN" > config/lambda_role_arn.txt

echo "=================================================="
echo "VERIFICATION"
echo "=================================================="
echo ""

echo "Role details:"
aws iam get-role --role-name $ROLE_NAME --output json | jq '.Role | {
    RoleName,
    RoleId,
    Arn,
    CreateDate
}'

echo ""
echo "Attached policies:"
aws iam list-attached-role-policies --role-name $ROLE_NAME --output table

echo ""
echo -e "${GREEN}✓ Lambda IAM role created successfully!${NC}"
echo ""
echo "Role ARN: $ROLE_ARN"
echo "Saved to: config/lambda_role_arn.txt"
echo ""
echo -e "${YELLOW}NOTE: Waiting 10 seconds for IAM changes to propagate...${NC}"
sleep 10

echo ""
echo -e "${GREEN}NEXT STEP:${NC}"
echo "  Run: ./setup/07_deploy_lambda.sh"
echo "=================================================="
