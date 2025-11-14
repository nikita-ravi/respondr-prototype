#!/bin/bash

# ============================================================================
# Script 04: Create S3 Buckets
# ============================================================================
# Creates two S3 buckets:
# 1. respondr-docs-demo-nit - for original document uploads (with versioning)
# 2. respondr-docs-demo-nit-parsed - for parsed text storage
# ============================================================================

set -e

echo "=================================================="
echo "STEP 4: Create S3 Buckets"
echo "=================================================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

REGION="us-east-1"
BUCKET_DOCS="respondr-docs-demo-nit"
BUCKET_PARSED="respondr-docs-demo-nit-parsed"

# Function to create bucket
create_bucket() {
    local bucket_name=$1
    local enable_versioning=$2

    echo "Creating bucket: $bucket_name"

    # Check if bucket already exists
    if aws s3 ls "s3://$bucket_name" 2>&1 | grep -q 'NoSuchBucket'; then
        # Bucket doesn't exist, create it
        # Note: For us-east-1, we don't specify LocationConstraint
        if [ "$REGION" = "us-east-1" ]; then
            aws s3api create-bucket --bucket $bucket_name --region $REGION
        else
            aws s3api create-bucket --bucket $bucket_name --region $REGION \
                --create-bucket-configuration LocationConstraint=$REGION
        fi

        echo -e "${GREEN}✓ Bucket created: $bucket_name${NC}"
    else
        echo -e "${YELLOW}✓ Bucket already exists: $bucket_name${NC}"
    fi

    # Enable versioning if requested
    if [ "$enable_versioning" = "true" ]; then
        echo "  Enabling versioning..."
        aws s3api put-bucket-versioning \
            --bucket $bucket_name \
            --versioning-configuration Status=Enabled
        echo -e "${GREEN}  ✓ Versioning enabled${NC}"
    fi

    # Block public access (security best practice)
    echo "  Configuring public access block..."
    aws s3api put-public-access-block \
        --bucket $bucket_name \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    echo -e "${GREEN}  ✓ Public access blocked${NC}"

    # Add tags
    aws s3api put-bucket-tagging \
        --bucket $bucket_name \
        --tagging "TagSet=[{Key=Project,Value=RespondrDocProcessor},{Key=Environment,Value=Demo}]"

    echo ""
}

# Create buckets
create_bucket $BUCKET_DOCS true
create_bucket $BUCKET_PARSED false

echo "=================================================="
echo "VERIFICATION"
echo "=================================================="
echo ""

echo "Listing all S3 buckets:"
aws s3 ls | grep respondr-docs-demo-nit || true

echo ""
echo "Checking bucket details:"
echo ""

echo "1. Documents bucket ($BUCKET_DOCS):"
echo "   Versioning status:"
aws s3api get-bucket-versioning --bucket $BUCKET_DOCS
echo ""

echo "2. Parsed bucket ($BUCKET_PARSED):"
echo "   Versioning status:"
aws s3api get-bucket-versioning --bucket $BUCKET_PARSED
echo ""

# Save bucket names to config
cat > config/bucket_names.txt <<EOF
BUCKET_DOCS=$BUCKET_DOCS
BUCKET_PARSED=$BUCKET_PARSED
EOF

echo -e "${GREEN}✓ S3 buckets created successfully!${NC}"
echo ""
echo "Bucket names saved to: config/bucket_names.txt"
echo ""
echo -e "${GREEN}NEXT STEP:${NC}"
echo "  Run: ./setup/05_create_dynamodb.sh"
echo "=================================================="
