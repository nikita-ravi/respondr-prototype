#!/bin/bash

# ============================================================================
# Script 02: Configure AWS CLI
# ============================================================================
# This script helps you configure AWS CLI with your root account credentials
# temporarily. We'll create a dedicated IAM user in the next step.
# ============================================================================

set -e  # Exit on any error

echo "=================================================="
echo "STEP 2: AWS CLI Configuration"
echo "=================================================="
echo ""

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}✗ AWS CLI is not installed${NC}"
    echo "Please run: ./setup/01_install_aws_cli.sh"
    exit 1
fi

echo -e "${YELLOW}IMPORTANT: Initial Setup Instructions${NC}"
echo "=========================================="
echo ""
echo "Since this is a brand new AWS account, you'll need to:"
echo ""
echo "1. Log in to AWS Console (https://console.aws.amazon.com/)"
echo "2. Go to IAM → Users → Security Credentials"
echo "3. Create an Access Key for your root/admin user"
echo "4. Copy the Access Key ID and Secret Access Key"
echo ""
echo -e "${YELLOW}NOTE:${NC} We'll create a dedicated IAM user in the next step."
echo "       This is just for initial setup."
echo ""
echo "Press Enter when you're ready to configure AWS CLI..."
read

echo ""
echo "=================================================="
echo "CONFIGURING AWS CLI"
echo "=================================================="
echo ""

# Set the region
export AWS_DEFAULT_REGION=us-east-1

# Check if already configured
if [ -f ~/.aws/credentials ] && [ -f ~/.aws/config ]; then
    echo -e "${YELLOW}AWS CLI is already configured.${NC}"
    echo ""
    echo "Current configuration:"
    echo "---"
    aws configure list
    echo ""

    read -p "Do you want to reconfigure? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing configuration."
        exit 0
    fi
fi

echo "Please enter your AWS credentials:"
echo ""

# Configure AWS CLI interactively
aws configure set region us-east-1
aws configure

echo ""
echo "=================================================="
echo "VERIFICATION"
echo "=================================================="
echo ""

# Test the configuration
echo "Testing AWS credentials..."
if aws sts get-caller-identity &> /dev/null; then
    IDENTITY=$(aws sts get-caller-identity)
    echo -e "${GREEN}✓ AWS CLI configured successfully!${NC}"
    echo ""
    echo "Your identity:"
    echo "$IDENTITY" | jq '.' 2>/dev/null || echo "$IDENTITY"

    # Extract and display account ID
    ACCOUNT_ID=$(echo "$IDENTITY" | jq -r '.Account' 2>/dev/null || echo "$IDENTITY" | grep -o '"Account": "[^"]*"' | cut -d'"' -f4)

    echo ""
    echo -e "${BLUE}Account ID: $ACCOUNT_ID${NC}"
    echo -e "${BLUE}Region: us-east-1${NC}"

    # Save account ID for later use
    echo "$ACCOUNT_ID" > config/account_id.txt

    echo ""
    echo -e "${GREEN}NEXT STEP:${NC}"
    echo "  Run: ./setup/03_create_iam_user.sh"
else
    echo -e "${RED}✗ Configuration failed${NC}"
    echo "Please check your credentials and try again."
    exit 1
fi

echo "=================================================="
