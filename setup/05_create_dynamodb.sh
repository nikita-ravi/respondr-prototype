#!/bin/bash

# ============================================================================
# Script 05: Create DynamoDB Table
# ============================================================================
# Creates DynamoDB table: respondr_docs_metadata with:
# - Primary key: doc_id (string)
# - GSI 1: org-doctype-index (org_id + doctype)
# - GSI 2: effective-date-index (org_id + effective_date)
# - Billing mode: PAY_PER_REQUEST (no capacity planning needed)
# ============================================================================

set -e

echo "=================================================="
echo "STEP 5: Create DynamoDB Table"
echo "=================================================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TABLE_NAME="respondr_docs_metadata"

echo "Creating DynamoDB table: $TABLE_NAME"
echo ""

# Check if table already exists
if aws dynamodb describe-table --table-name $TABLE_NAME &> /dev/null; then
    echo -e "${YELLOW}✓ Table '$TABLE_NAME' already exists${NC}"
    echo ""

    # Show table details
    echo "Table details:"
    aws dynamodb describe-table --table-name $TABLE_NAME \
        --query 'Table.[TableName,TableStatus,ItemCount,TableSizeBytes]' \
        --output table

    echo ""
    echo "Skipping table creation."
    echo ""
    echo -e "${GREEN}NEXT STEP:${NC}"
    echo "  Run: ./setup/06_create_lambda_role.sh"
    echo "=================================================="
    exit 0
fi

# Create DynamoDB table with GSIs
echo "Creating table with Global Secondary Indexes..."
aws dynamodb create-table \
    --table-name $TABLE_NAME \
    --attribute-definitions \
        AttributeName=doc_id,AttributeType=S \
        AttributeName=org_id,AttributeType=S \
        AttributeName=doctype,AttributeType=S \
        AttributeName=effective_date,AttributeType=S \
    --key-schema \
        AttributeName=doc_id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --global-secondary-indexes \
        "[
            {
                \"IndexName\": \"org-doctype-index\",
                \"KeySchema\": [
                    {\"AttributeName\": \"org_id\", \"KeyType\": \"HASH\"},
                    {\"AttributeName\": \"doctype\", \"KeyType\": \"RANGE\"}
                ],
                \"Projection\": {
                    \"ProjectionType\": \"ALL\"
                }
            },
            {
                \"IndexName\": \"effective-date-index\",
                \"KeySchema\": [
                    {\"AttributeName\": \"org_id\", \"KeyType\": \"HASH\"},
                    {\"AttributeName\": \"effective_date\", \"KeyType\": \"RANGE\"}
                ],
                \"Projection\": {
                    \"ProjectionType\": \"ALL\"
                }
            }
        ]" \
    --tags \
        Key=Project,Value=RespondrDocProcessor \
        Key=Environment,Value=Demo \
    --region us-east-1

echo -e "${GREEN}✓ Table creation initiated${NC}"
echo ""

# Wait for table to become active
echo "Waiting for table to become active (this may take 30-60 seconds)..."
aws dynamodb wait table-exists --table-name $TABLE_NAME

echo -e "${GREEN}✓ Table is now active${NC}"
echo ""

echo "=================================================="
echo "VERIFICATION"
echo "=================================================="
echo ""

# Describe the table
echo "Table details:"
aws dynamodb describe-table --table-name $TABLE_NAME \
    --query 'Table.[TableName,TableStatus,GlobalSecondaryIndexes[*].IndexName]' \
    --output table

echo ""
echo "Full table description:"
aws dynamodb describe-table --table-name $TABLE_NAME \
    --output json | jq '.Table | {
        TableName,
        TableStatus,
        BillingMode: .BillingModeSummary.BillingMode,
        ItemCount,
        PrimaryKey: .KeySchema,
        GlobalSecondaryIndexes: [.GlobalSecondaryIndexes[] | {
            IndexName,
            KeySchema,
            IndexStatus
        }]
    }'

echo ""
echo -e "${GREEN}✓ DynamoDB table created successfully!${NC}"
echo ""
echo -e "${GREEN}NEXT STEP:${NC}"
echo "  Run: ./setup/06_create_lambda_role.sh"
echo "=================================================="
