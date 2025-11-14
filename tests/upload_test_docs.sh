#!/bin/bash

# ============================================================================
# Upload Test Documents to S3
# ============================================================================
# This script uploads test PDF documents to S3, which will trigger the
# Lambda function to process them.
# ============================================================================

set -e

echo "=================================================="
echo "Upload Test Documents to S3"
echo "=================================================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

BUCKET_NAME="respondr-docs-demo-nit"
TEST_DIR="test_documents"

# Check if test documents exist
if [ ! -d "$TEST_DIR" ]; then
    echo -e "${RED}✗ Test documents directory not found${NC}"
    echo "Please run: python3 tests/create_test_pdfs.py"
    exit 1
fi

# Check if there are PDF files
PDF_COUNT=$(find $TEST_DIR -name "*.pdf" | wc -l)
if [ $PDF_COUNT -eq 0 ]; then
    echo -e "${RED}✗ No PDF files found in $TEST_DIR${NC}"
    echo "Please run: python3 tests/create_test_pdfs.py"
    exit 1
fi

echo "Found $PDF_COUNT PDF files to upload"
echo ""

# Upload each PDF to different org folders for testing
echo "Uploading documents..."
echo ""

# Document 1: Emergency Plan → org1
if [ -f "$TEST_DIR/emergency_evacuation_plan.pdf" ]; then
    echo "Uploading emergency_evacuation_plan.pdf to org1..."
    aws s3 cp "$TEST_DIR/emergency_evacuation_plan.pdf" \
        "s3://$BUCKET_NAME/org1/emergency_evacuation_plan.pdf"
    echo -e "${GREEN}✓ Uploaded to org1${NC}"
fi

# Document 2: SOP → org2
if [ -f "$TEST_DIR/chemical_handling_sop.pdf" ]; then
    echo "Uploading chemical_handling_sop.pdf to org2..."
    aws s3 cp "$TEST_DIR/chemical_handling_sop.pdf" \
        "s3://$BUCKET_NAME/org2/chemical_handling_sop.pdf"
    echo -e "${GREEN}✓ Uploaded to org2${NC}"
fi

# Document 3: Incident Report → org1
if [ -f "$TEST_DIR/incident_report_2024_0042.pdf" ]; then
    echo "Uploading incident_report_2024_0042.pdf to org1..."
    aws s3 cp "$TEST_DIR/incident_report_2024_0042.pdf" \
        "s3://$BUCKET_NAME/org1/incident_report_2024_0042.pdf"
    echo -e "${GREEN}✓ Uploaded to org1${NC}"
fi

echo ""
echo "=================================================="
echo "VERIFICATION"
echo "=================================================="
echo ""

# List uploaded files
echo "Files in S3 bucket:"
aws s3 ls "s3://$BUCKET_NAME/" --recursive | grep ".pdf"

echo ""
echo -e "${GREEN}✓ Upload complete!${NC}"
echo ""
echo -e "${YELLOW}The Lambda function should now be processing these documents.${NC}"
echo "This may take 1-2 minutes depending on document size."
echo ""
echo "Next steps:"
echo "  1. Wait 1-2 minutes for processing"
echo "  2. Check logs: ./tests/tail_logs.sh"
echo "  3. Verify data: python3 tests/verify_processing.py"
echo "  4. View dashboard: streamlit run dashboard/dashboard.py"
echo "=================================================="
