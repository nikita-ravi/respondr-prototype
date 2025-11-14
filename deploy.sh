#!/bin/bash

# ============================================================================
# Master Deployment Script
# ============================================================================
# This script orchestrates the entire deployment process for the Respondr
# Document Metadata Extraction Pipeline.
#
# It runs all setup scripts in sequence and provides status updates.
# ============================================================================

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo ""
echo "================================================================"
echo "  RESPONDR DOCUMENT METADATA EXTRACTION PIPELINE"
echo "  Master Deployment Script"
echo "================================================================"
echo ""

# Function to run a script and check status
run_script() {
    local script=$1
    local description=$2

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$description${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if [ -f "$script" ]; then
        if $script; then
            echo ""
            echo -e "${GREEN}✓ SUCCESS: $description${NC}"
            return 0
        else
            echo ""
            echo -e "${RED}✗ FAILED: $description${NC}"
            echo ""
            echo "Please fix the error and try again."
            echo "You can also run individual scripts manually:"
            echo "  $script"
            exit 1
        fi
    else
        echo -e "${RED}✗ Script not found: $script${NC}"
        exit 1
    fi
}

# Function to pause for user confirmation
pause_for_confirmation() {
    local message=$1
    echo ""
    echo -e "${YELLOW}$message${NC}"
    read -p "Press Enter to continue, or Ctrl+C to abort... " -r
    echo ""
}

# Display menu
echo "This script will:"
echo "  1. Install AWS CLI (if needed)"
echo "  2. Configure AWS credentials"
echo "  3. Create IAM user for development"
echo "  4. Create S3 buckets"
echo "  5. Create DynamoDB table"
echo "  6. Create Lambda IAM role"
echo "  7. Deploy Lambda function"
echo "  8. Configure S3 trigger"
echo ""

# Check if user wants to run all or specific steps
echo "Deployment options:"
echo "  [1] Full deployment (all steps)"
echo "  [2] Infrastructure only (steps 1-6)"
echo "  [3] Lambda deployment only (step 7)"
echo "  [4] Individual step selection"
echo ""

read -p "Select option (1-4): " -n 1 -r OPTION
echo ""
echo ""

case $OPTION in
    1)
        echo -e "${GREEN}Running full deployment...${NC}"

        run_script "./setup/01_install_aws_cli.sh" "Step 1: Install AWS CLI"

        pause_for_confirmation "Next: Configure AWS credentials. Have your AWS Access Key ID and Secret Access Key ready."
        run_script "./setup/02_configure_aws.sh" "Step 2: Configure AWS CLI"

        pause_for_confirmation "Next: Create IAM user for development."
        run_script "./setup/03_create_iam_user.sh" "Step 3: Create IAM User"

        run_script "./setup/04_create_s3_buckets.sh" "Step 4: Create S3 Buckets"
        run_script "./setup/05_create_dynamodb.sh" "Step 5: Create DynamoDB Table"
        run_script "./setup/06_create_lambda_role.sh" "Step 6: Create Lambda IAM Role"
        run_script "./setup/07_deploy_lambda.sh" "Step 7: Deploy Lambda Function"
        run_script "./setup/08_configure_s3_trigger.sh" "Step 8: Configure S3 Trigger"
        ;;

    2)
        echo -e "${GREEN}Running infrastructure deployment...${NC}"

        run_script "./setup/01_install_aws_cli.sh" "Step 1: Install AWS CLI"
        pause_for_confirmation "Next: Configure AWS credentials."
        run_script "./setup/02_configure_aws.sh" "Step 2: Configure AWS CLI"
        pause_for_confirmation "Next: Create IAM user."
        run_script "./setup/03_create_iam_user.sh" "Step 3: Create IAM User"
        run_script "./setup/04_create_s3_buckets.sh" "Step 4: Create S3 Buckets"
        run_script "./setup/05_create_dynamodb.sh" "Step 5: Create DynamoDB Table"
        run_script "./setup/06_create_lambda_role.sh" "Step 6: Create Lambda IAM Role"
        ;;

    3)
        echo -e "${GREEN}Running Lambda deployment only...${NC}"

        run_script "./setup/07_deploy_lambda.sh" "Step 7: Deploy Lambda Function"
        run_script "./setup/08_configure_s3_trigger.sh" "Step 8: Configure S3 Trigger"
        ;;

    4)
        echo "Individual step selection:"
        echo ""
        PS3="Select step to run (0 to finish): "
        options=(
            "Install AWS CLI"
            "Configure AWS CLI"
            "Create IAM User"
            "Create S3 Buckets"
            "Create DynamoDB Table"
            "Create Lambda IAM Role"
            "Deploy Lambda Function"
            "Configure S3 Trigger"
            "Done"
        )

        select opt in "${options[@]}"; do
            case $opt in
                "Install AWS CLI")
                    run_script "./setup/01_install_aws_cli.sh" "Step 1: Install AWS CLI"
                    ;;
                "Configure AWS CLI")
                    run_script "./setup/02_configure_aws.sh" "Step 2: Configure AWS CLI"
                    ;;
                "Create IAM User")
                    run_script "./setup/03_create_iam_user.sh" "Step 3: Create IAM User"
                    ;;
                "Create S3 Buckets")
                    run_script "./setup/04_create_s3_buckets.sh" "Step 4: Create S3 Buckets"
                    ;;
                "Create DynamoDB Table")
                    run_script "./setup/05_create_dynamodb.sh" "Step 5: Create DynamoDB Table"
                    ;;
                "Create Lambda IAM Role")
                    run_script "./setup/06_create_lambda_role.sh" "Step 6: Create Lambda IAM Role"
                    ;;
                "Deploy Lambda Function")
                    run_script "./setup/07_deploy_lambda.sh" "Step 7: Deploy Lambda Function"
                    ;;
                "Configure S3 Trigger")
                    run_script "./setup/08_configure_s3_trigger.sh" "Step 8: Configure S3 Trigger"
                    ;;
                "Done")
                    break
                    ;;
                *)
                    echo "Invalid option"
                    ;;
            esac
        done
        ;;

    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

echo ""
echo "================================================================"
echo -e "${GREEN}  ✓ DEPLOYMENT COMPLETE${NC}"
echo "================================================================"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Install Python dependencies for testing and dashboard:"
echo "   pip3 install reportlab streamlit boto3 pandas"
echo ""
echo "2. Create test PDF documents:"
echo "   python3 tests/create_test_pdfs.py"
echo ""
echo "3. Upload test documents to S3:"
echo "   ./tests/upload_test_docs.sh"
echo ""
echo "4. Wait 1-2 minutes, then verify processing:"
echo "   python3 tests/verify_processing.py"
echo ""
echo "5. Launch the dashboard:"
echo "   streamlit run dashboard/dashboard.py"
echo ""
echo "6. Monitor Lambda logs:"
echo "   ./tests/tail_logs.sh"
echo ""
echo "================================================================"
echo ""
