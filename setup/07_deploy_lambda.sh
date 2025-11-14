#!/bin/bash

# ============================================================================
# Script 07: Deploy Lambda Function
# ============================================================================
# This script packages the Lambda function code and deploys it to AWS.
# It creates a deployment package with all dependencies and uploads it.
# ============================================================================

set -e

echo "=================================================="
echo "STEP 7: Deploy Lambda Function"
echo "=================================================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

FUNCTION_NAME="RespondrDocProcessor"
ROLE_ARN_FILE="config/lambda_role_arn.txt"
LAMBDA_DIR="lambda"
PACKAGE_DIR="lambda_package"
ZIP_FILE="lambda_deployment.zip"

# Check if role ARN file exists
if [ ! -f "$ROLE_ARN_FILE" ]; then
    echo -e "${RED}✗ Lambda role ARN file not found${NC}"
    echo "Please run: ./setup/06_create_lambda_role.sh"
    exit 1
fi

ROLE_ARN=$(cat $ROLE_ARN_FILE)
echo "Using Lambda role: $ROLE_ARN"
echo ""

# Clean up old package if exists
echo "Cleaning up old deployment package..."
rm -rf $PACKAGE_DIR
rm -f $ZIP_FILE

# Create package directory
echo "Creating deployment package..."
mkdir -p $PACKAGE_DIR

# Copy Lambda function code
echo "Copying Lambda function code..."
cp $LAMBDA_DIR/lambda_function.py $PACKAGE_DIR/

# Install dependencies
echo "Installing dependencies..."
if [ -f "$LAMBDA_DIR/requirements.txt" ]; then
    pip3 install -r $LAMBDA_DIR/requirements.txt -t $PACKAGE_DIR/ --quiet
    echo -e "${GREEN}✓ Dependencies installed${NC}"
else
    echo -e "${YELLOW}No requirements.txt found, skipping dependencies${NC}"
fi

# Create ZIP file
echo "Creating ZIP file..."
cd $PACKAGE_DIR
zip -r ../$ZIP_FILE . -q
cd ..

echo -e "${GREEN}✓ Deployment package created: $ZIP_FILE${NC}"
echo ""

# Check if Lambda function already exists
echo "Checking if Lambda function exists..."
if aws lambda get-function --function-name $FUNCTION_NAME &> /dev/null; then
    echo -e "${YELLOW}✓ Function '$FUNCTION_NAME' exists, updating code...${NC}"

    # Update function code
    aws lambda update-function-code \
        --function-name $FUNCTION_NAME \
        --zip-file fileb://$ZIP_FILE

    echo -e "${GREEN}✓ Function code updated${NC}"
    echo ""

    # Update function configuration
    echo "Updating function configuration..."
    aws lambda update-function-configuration \
        --function-name $FUNCTION_NAME \
        --timeout 300 \
        --memory-size 512 \
        --runtime python3.11

    echo -e "${GREEN}✓ Configuration updated${NC}"

else
    echo "Creating new Lambda function..."

    # Create Lambda function
    aws lambda create-function \
        --function-name $FUNCTION_NAME \
        --runtime python3.11 \
        --role $ROLE_ARN \
        --handler lambda_function.lambda_handler \
        --zip-file fileb://$ZIP_FILE \
        --timeout 300 \
        --memory-size 512 \
        --description "Respondr Document Processor - Extracts metadata from PDFs using Textract" \
        --tags Project=RespondrDocProcessor,Environment=Demo

    echo -e "${GREEN}✓ Lambda function created${NC}"
fi

echo ""
echo "Waiting for function to be active..."
aws lambda wait function-active --function-name $FUNCTION_NAME

echo ""
echo "=================================================="
echo "VERIFICATION"
echo "=================================================="
echo ""

# Get function details
echo "Function details:"
aws lambda get-function --function-name $FUNCTION_NAME --output json | jq '.Configuration | {
    FunctionName,
    FunctionArn,
    Runtime,
    Handler,
    Timeout,
    MemorySize,
    LastModified
}'

echo ""

# Save function ARN for later use
FUNCTION_ARN=$(aws lambda get-function --function-name $FUNCTION_NAME --query 'Configuration.FunctionArn' --output text)
echo "$FUNCTION_ARN" > config/lambda_function_arn.txt

echo -e "${GREEN}✓ Lambda function deployed successfully!${NC}"
echo ""
echo "Function ARN: $FUNCTION_ARN"
echo "Saved to: config/lambda_function_arn.txt"
echo ""
echo -e "${GREEN}NEXT STEP:${NC}"
echo "  Run: ./setup/08_configure_s3_trigger.sh"
echo "=================================================="
