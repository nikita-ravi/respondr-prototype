#!/bin/bash

# ============================================================================
# Script 08: Configure S3 Trigger for Lambda
# ============================================================================
# This script configures the S3 bucket to trigger the Lambda function
# whenever a PDF file is uploaded.
# ============================================================================

set -e

echo "=================================================="
echo "STEP 8: Configure S3 Trigger"
echo "=================================================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

BUCKET_NAME="respondr-docs-demo-nit"
FUNCTION_NAME="RespondrDocProcessor"
LAMBDA_ARN_FILE="config/lambda_function_arn.txt"
NOTIFICATION_CONFIG="config/s3-notification.json"

# Check if Lambda ARN file exists
if [ ! -f "$LAMBDA_ARN_FILE" ]; then
    echo -e "${RED}✗ Lambda ARN file not found${NC}"
    echo "Please run: ./setup/07_deploy_lambda.sh"
    exit 1
fi

LAMBDA_ARN=$(cat $LAMBDA_ARN_FILE)
echo "Lambda ARN: $LAMBDA_ARN"
echo "S3 Bucket: $BUCKET_NAME"
echo ""

# Step 1: Add Lambda invoke permission for S3
echo "Adding S3 invoke permission to Lambda function..."

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)

# Remove existing permission if it exists (ignore errors)
aws lambda remove-permission \
    --function-name $FUNCTION_NAME \
    --statement-id s3-trigger-permission \
    &> /dev/null || true

# Add permission
aws lambda add-permission \
    --function-name $FUNCTION_NAME \
    --statement-id s3-trigger-permission \
    --action lambda:InvokeFunction \
    --principal s3.amazonaws.com \
    --source-arn "arn:aws:s3:::$BUCKET_NAME" \
    --source-account $ACCOUNT_ID

echo -e "${GREEN}✓ Lambda permission added${NC}"
echo ""

# Step 2: Create notification configuration
echo "Creating S3 notification configuration..."

# Replace placeholder with actual Lambda ARN
TEMP_CONFIG=$(mktemp)
sed "s|LAMBDA_ARN_PLACEHOLDER|$LAMBDA_ARN|g" $NOTIFICATION_CONFIG > $TEMP_CONFIG

cat $TEMP_CONFIG

echo ""

# Step 3: Apply notification configuration to S3 bucket
echo "Applying notification configuration to S3 bucket..."

aws s3api put-bucket-notification-configuration \
    --bucket $BUCKET_NAME \
    --notification-configuration file://$TEMP_CONFIG

# Clean up temp file
rm $TEMP_CONFIG

echo -e "${GREEN}✓ S3 notification configured${NC}"
echo ""

echo "=================================================="
echo "VERIFICATION"
echo "=================================================="
echo ""

# Verify notification configuration
echo "S3 Bucket Notification Configuration:"
aws s3api get-bucket-notification-configuration \
    --bucket $BUCKET_NAME \
    --output json | jq '.'

echo ""
echo -e "${GREEN}✓ S3 trigger configured successfully!${NC}"
echo ""
echo -e "${YELLOW}SUMMARY:${NC}"
echo "  - S3 Bucket: $BUCKET_NAME"
echo "  - Trigger: Upload .pdf files"
echo "  - Lambda: $FUNCTION_NAME"
echo ""
echo -e "${GREEN}✓ Pipeline setup complete!${NC}"
echo ""
echo -e "${GREEN}NEXT STEPS:${NC}"
echo "  1. Test the pipeline: ./tests/create_test_pdfs.py"
echo "  2. Upload test documents: ./tests/upload_test_docs.sh"
echo "  3. Run the dashboard: streamlit run dashboard/dashboard.py"
echo "=================================================="
