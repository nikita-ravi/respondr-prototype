# Respondr Document Metadata Extraction Pipeline

A serverless AWS pipeline that automatically processes PDF documents, extracts metadata using AWS Textract, and stores structured metadata in DynamoDB.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
- [Testing](#testing)
- [Dashboard](#dashboard)
- [Metadata Schema](#metadata-schema)
- [Cost Estimates](#cost-estimates)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

## Overview

This prototype automatically:

1. **Monitors** S3 bucket for PDF uploads
2. **Extracts** text from PDFs using AWS Textract
3. **Parses** metadata using keyword matching and regex
4. **Stores** structured metadata in DynamoDB
5. **Saves** parsed text to S3
6. **Displays** results in a Streamlit dashboard

### Extracted Metadata Categories

- **Administrative**: org_id, version, effective_date, author
- **Technical**: pages, file_size, mime_type, checksum_sha256, ocr_coverage
- **Content**: doctype, roles_involved, hazard_types, facility, jurisdiction
- **Governance**: classification, pii_present

## Architecture

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│   S3 Bucket │────────>│    Lambda    │────────>│  DynamoDB   │
│   (Upload)  │ Trigger │  (Textract)  │  Store  │  (Metadata) │
└─────────────┘         └──────────────┘         └─────────────┘
                               │
                               ├────────>┌─────────────┐
                               │ Extract │  Textract   │
                               └─────────┴─────────────┘
                               │
                               └────────>┌─────────────┐
                                  Save   │  S3 Bucket  │
                                         │  (Parsed)   │
                                         └─────────────┘
```

### AWS Resources Created

| Resource | Name | Purpose |
|----------|------|---------|
| S3 Bucket | `respondr-docs-demo-nit` | Original document uploads |
| S3 Bucket | `respondr-docs-demo-nit-parsed` | Parsed text storage |
| DynamoDB Table | `respondr_docs_metadata` | Metadata storage |
| Lambda Function | `RespondrDocProcessor` | Document processing |
| IAM Role | `RespondrDocProcessorRole` | Lambda execution role |
| IAM User | `respondr-dev-user` | Development user |

## Prerequisites

### Required Software

- **Operating System**: macOS or Linux
- **Python**: 3.9 or higher
- **AWS Account**: Brand new or existing account
- **Shell**: Bash (default on Mac/Linux)

### Required Tools (Will be installed by setup scripts)

- AWS CLI v2
- jq (JSON processor)

### Python Packages (Will be installed)

```bash
# For Lambda function
boto3==1.34.30

# For dashboard
streamlit==1.31.0
boto3==1.34.30
pandas==2.2.0

# For test PDF generation
reportlab
```

## Project Structure

```
respondr-prototype/
├── setup/                    # Setup scripts (run in order)
│   ├── 01_install_aws_cli.sh
│   ├── 02_configure_aws.sh
│   ├── 03_create_iam_user.sh
│   ├── 04_create_s3_buckets.sh
│   ├── 05_create_dynamodb.sh
│   ├── 06_create_lambda_role.sh
│   ├── 07_deploy_lambda.sh
│   └── 08_configure_s3_trigger.sh
├── lambda/                   # Lambda function code
│   ├── lambda_function.py
│   └── requirements.txt
├── dashboard/                # Streamlit dashboard
│   ├── dashboard.py
│   └── requirements.txt
├── tests/                    # Testing utilities
│   ├── create_test_pdfs.py
│   ├── upload_test_docs.sh
│   ├── verify_processing.py
│   └── tail_logs.sh
├── config/                   # Configuration files (created by setup)
│   ├── lambda-trust-policy.json
│   ├── s3-notification.json
│   └── *.txt (generated config files)
├── deploy.sh                 # Master deployment script
└── README.md                 # This file
```

## Quick Start

### Option 1: Automated Deployment (Recommended)

Run the master deployment script:

```bash
./deploy.sh
```

Select option 1 for full deployment and follow the prompts.

### Option 2: Manual Step-by-Step

Run each setup script in order:

```bash
# Step 1: Install AWS CLI
./setup/01_install_aws_cli.sh

# Step 2: Configure AWS credentials
./setup/02_configure_aws.sh

# Step 3: Create IAM user
./setup/03_create_iam_user.sh

# Step 4: Create S3 buckets
./setup/04_create_s3_buckets.sh

# Step 5: Create DynamoDB table
./setup/05_create_dynamodb.sh

# Step 6: Create Lambda IAM role
./setup/06_create_lambda_role.sh

# Step 7: Deploy Lambda function
./setup/07_deploy_lambda.sh

# Step 8: Configure S3 trigger
./setup/08_configure_s3_trigger.sh
```

## Detailed Setup

### Step 1: Install AWS CLI

**What it does**: Checks if AWS CLI is installed and installs it if needed.

```bash
./setup/01_install_aws_cli.sh
```

**Expected output**:
```
✓ AWS CLI installed successfully!
  Version: aws-cli/2.x.x Python/3.x.x ...
```

**Verification**:
```bash
aws --version
```

### Step 2: Configure AWS CLI

**What it does**: Configures AWS credentials and region.

**Prerequisites**: You need AWS Access Key ID and Secret Access Key from your AWS account.

**How to get credentials**:
1. Log in to [AWS Console](https://console.aws.amazon.com/)
2. Go to IAM → Users → Your User → Security Credentials
3. Click "Create access key"
4. Copy the Access Key ID and Secret Access Key

```bash
./setup/02_configure_aws.sh
```

**Expected output**:
```
✓ AWS CLI configured successfully!
Account ID: 123456789012
Region: us-east-1
```

### Step 3: Create IAM User

**What it does**: Creates a dedicated IAM user `respondr-dev-user` with necessary permissions.

```bash
./setup/03_create_iam_user.sh
```

**Expected output**:
```
✓ User created
✓ Policies attached
✓ Access key created
✓ New credentials verified!
```

**Important**: Credentials are saved to `config/dev_user_credentials.txt` (keep this secure).

### Step 4: Create S3 Buckets

**What it does**: Creates two S3 buckets for document storage.

```bash
./setup/04_create_s3_buckets.sh
```

**Expected output**:
```
✓ Bucket created: respondr-docs-demo-nit
✓ Bucket created: respondr-docs-demo-nit-parsed
```

### Step 5: Create DynamoDB Table

**What it does**: Creates DynamoDB table with GSIs for querying.

```bash
./setup/05_create_dynamodb.sh
```

**Expected output**:
```
✓ Table creation initiated
✓ Table is now active
```

**Verification**:
```bash
aws dynamodb describe-table --table-name respondr_docs_metadata
```

### Step 6: Create Lambda IAM Role

**What it does**: Creates IAM role with permissions for Lambda to access S3, Textract, and DynamoDB.

```bash
./setup/06_create_lambda_role.sh
```

**Expected output**:
```
✓ Role created
✓ Policies attached
```

### Step 7: Deploy Lambda Function

**What it does**: Packages Lambda code and deploys to AWS.

```bash
./setup/07_deploy_lambda.sh
```

**Expected output**:
```
✓ Deployment package created: lambda_deployment.zip
✓ Lambda function created
```

### Step 8: Configure S3 Trigger

**What it does**: Configures S3 to trigger Lambda on PDF uploads.

```bash
./setup/08_configure_s3_trigger.sh
```

**Expected output**:
```
✓ Lambda permission added
✓ S3 notification configured
```

## Testing

### 1. Install Python Dependencies

```bash
pip3 install reportlab streamlit boto3 pandas
```

### 2. Create Test PDFs

Generate sample PDF documents with realistic content:

```bash
python3 tests/create_test_pdfs.py
```

**What it creates**:
- `test_documents/emergency_evacuation_plan.pdf` - Emergency plan with fire, security, EHS roles
- `test_documents/chemical_handling_sop.pdf` - SOP with chemical hazards, facilities roles
- `test_documents/incident_report_2024_0042.pdf` - Incident report with medical, HR roles

### 3. Upload Test Documents

Upload PDFs to S3 (triggers Lambda processing):

```bash
./tests/upload_test_docs.sh
```

**Expected output**:
```
✓ Uploaded to org1
✓ Uploaded to org2
✓ Upload complete!
```

### 4. Monitor Processing

Check Lambda logs in real-time:

```bash
./tests/tail_logs.sh
```

**What to look for**:
- "Lambda function started"
- "Starting Textract document analysis"
- "Document processing completed successfully"

### 5. Verify Results

Query DynamoDB to see extracted metadata:

```bash
python3 tests/verify_processing.py
```

**Expected output**:
```
✓ Found 3 document(s)

DOCUMENT 1
========================================
📋 ADMINISTRATIVE
  Doc ID:         abc-123-def-456
  Organization:   org1
  Source:         org1/emergency_evacuation_plan.pdf
  ...
```

## Dashboard

### Launch Dashboard

```bash
streamlit run dashboard/dashboard.py
```

The dashboard will open in your browser at `http://localhost:8501`

### Dashboard Features

- **Summary Statistics**: Total docs, organizations, avg pages, total size
- **Document Type Breakdown**: Bar chart of document types
- **Roles & Hazards**: Lists of detected roles and hazards
- **Filters**: Filter by organization ID and document type
- **Document Cards**: Expandable cards showing all metadata
- **Text Preview**: First 500 characters of extracted text
- **Download**: Download full parsed text from S3
- **Refresh**: Reload data from DynamoDB

### Dashboard Screenshots

**Filter Panel**:
- Organization ID text input
- Document Type dropdown
- Refresh button

**Main View**:
- Statistics at top
- Document type chart
- List of document cards
- Each card shows complete metadata

## Metadata Schema

### DynamoDB Table Schema

**Primary Key**:
- `doc_id` (String) - UUID generated for each document

**Global Secondary Indexes**:
1. `org-doctype-index`: org_id (hash) + doctype (range)
2. `effective-date-index`: org_id (hash) + effective_date (range)

**Attributes**:

```json
{
  "doc_id": "uuid",
  "source_bucket": "respondr-docs-demo-nit",
  "source_key": "org1/document.pdf",
  "processed_at": "2024-01-15T10:30:00",

  "org_id": "org1",
  "version": "2.1",
  "effective_date": "01/15/2024",
  "author": "John Smith",

  "pages": 5,
  "file_size": 245678,
  "mime_type": "application/pdf",
  "checksum_sha256": "abc123...",
  "ocr_coverage_pct": 85.5,

  "doctype": "emergency_plan",
  "roles_involved": ["security", "ehs", "facilities"],
  "hazard_types": ["fire", "chemical"],
  "facility": "Building A, Floor 3",
  "jurisdiction": "VA",

  "classification": "internal",
  "pii_present": false,
  "text_preview": "First 500 characters..."
}
```

### Document Types

- `emergency_plan` - Emergency evacuation plans, disaster response
- `sop` - Standard Operating Procedures
- `policy` - Company policies and regulations
- `incident_report` - Accident and incident reports
- `training` - Training materials and courses
- `unknown` - Could not determine type

### Roles

- `security` - Security personnel
- `ehs` - Environmental Health & Safety
- `facilities` - Facilities and maintenance
- `hr` - Human Resources
- `medical` - Medical and healthcare staff

### Hazard Types

- `fire` - Fire emergencies
- `chemical` - Chemical spills and hazmat
- `active_shooter` - Armed intruder situations
- `flood` - Flooding and water damage
- `medical_emergency` - Medical emergencies

## Cost Estimates

### AWS Free Tier (First 12 Months)

- **Lambda**: 1M requests/month, 400K GB-seconds compute
- **S3**: 5GB storage, 20K GET requests, 2K PUT requests
- **DynamoDB**: 25GB storage, 25 WCU, 25 RCU
- **Textract**: 1,000 pages/month free for first 3 months

### Estimated Monthly Costs (After Free Tier)

For **100 documents/month** (avg 10 pages each):

| Service | Usage | Cost |
|---------|-------|------|
| S3 Storage (5 GB) | Documents + parsed text | $0.12 |
| Lambda (100 invocations) | 300s timeout, 512MB | $0.01 |
| DynamoDB (PAY_PER_REQUEST) | 100 writes, 1000 reads | $0.38 |
| Textract | 1,000 pages | $1.50 |
| **Total** | | **~$2/month** |

### Cost Optimization Tips

1. **Use Textract selectively**: Only process new documents
2. **S3 Lifecycle**: Archive old documents to Glacier
3. **DynamoDB**: Use PAY_PER_REQUEST for low volume
4. **Lambda**: Optimize memory and timeout settings
5. **Delete test data**: Remove test documents after testing

## Troubleshooting

### Common Issues

#### 1. AWS CLI Not Found

**Problem**: `aws: command not found`

**Solution**:
```bash
./setup/01_install_aws_cli.sh
```

#### 2. Permission Denied

**Problem**: Scripts won't execute

**Solution**:
```bash
chmod +x setup/*.sh tests/*.sh deploy.sh
chmod +x tests/*.py
```

#### 3. Lambda Function Timeout

**Problem**: Lambda times out during Textract processing

**Solution**:
- Increase timeout: Edit `setup/07_deploy_lambda.sh`, change `--timeout 300` to `--timeout 600`
- Redeploy: `./setup/07_deploy_lambda.sh`

#### 4. No Documents in Dashboard

**Problem**: Dashboard shows "No documents found"

**Solution**:
1. Check if documents were uploaded: `aws s3 ls s3://respondr-docs-demo-nit/ --recursive`
2. Check Lambda logs: `./tests/tail_logs.sh`
3. Verify DynamoDB: `python3 tests/verify_processing.py`
4. Wait 1-2 minutes for Textract processing

#### 5. Textract "ProvisionedThroughputExceededException"

**Problem**: Too many documents processed at once

**Solution**:
- Upload documents in smaller batches
- Wait between uploads
- Consider using SQS queue for rate limiting

#### 6. IAM Permissions Error

**Problem**: "AccessDeniedException" or similar

**Solution**:
- Verify IAM policies attached: `aws iam list-attached-user-policies --user-name respondr-dev-user`
- Re-run IAM setup: `./setup/03_create_iam_user.sh`

#### 7. S3 Bucket Already Exists

**Problem**: Bucket names are globally unique

**Solution**:
- Edit bucket names in:
  - `setup/04_create_s3_buckets.sh`
  - `lambda/lambda_function.py` (PARSED_BUCKET variable)
  - `dashboard/dashboard.py` (PARSED_BUCKET variable)

### Checking Logs

**Lambda CloudWatch Logs**:
```bash
./tests/tail_logs.sh
```

**Recent errors only**:
```bash
aws logs tail /aws/lambda/RespondrDocProcessor --filter-pattern "ERROR" --since 1h
```

**Follow logs in real-time**:
```bash
aws logs tail /aws/lambda/RespondrDocProcessor --follow
```

### Verifying Resources

**Check all resources exist**:
```bash
# S3 buckets
aws s3 ls | grep respondr

# DynamoDB table
aws dynamodb describe-table --table-name respondr_docs_metadata

# Lambda function
aws lambda get-function --function-name RespondrDocProcessor

# IAM role
aws iam get-role --role-name RespondrDocProcessorRole
```

## Cleanup

### Delete All AWS Resources

**WARNING**: This will permanently delete all data and resources.

```bash
# 1. Delete S3 buckets (empties first, then deletes)
aws s3 rm s3://respondr-docs-demo-nit --recursive
aws s3 rb s3://respondr-docs-demo-nit

aws s3 rm s3://respondr-docs-demo-nit-parsed --recursive
aws s3 rb s3://respondr-docs-demo-nit-parsed

# 2. Delete Lambda function
aws lambda delete-function --function-name RespondrDocProcessor

# 3. Delete DynamoDB table
aws dynamodb delete-table --table-name respondr_docs_metadata

# 4. Delete IAM role (detach policies first)
aws iam detach-role-policy --role-name RespondrDocProcessorRole \
    --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
aws iam detach-role-policy --role-name RespondrDocProcessorRole \
    --policy-arn arn:aws:iam::aws:policy/AmazonTextractFullAccess
aws iam detach-role-policy --role-name RespondrDocProcessorRole \
    --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess
aws iam detach-role-policy --role-name RespondrDocProcessorRole \
    --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsFullAccess
aws iam delete-role --role-name RespondrDocProcessorRole

# 5. Delete IAM user (optional - only if you want to remove dev user)
aws iam list-access-keys --user-name respondr-dev-user | \
    jq -r '.AccessKeyMetadata[].AccessKeyId' | \
    xargs -I {} aws iam delete-access-key --user-name respondr-dev-user --access-key-id {}

aws iam detach-user-policy --user-name respondr-dev-user \
    --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
aws iam detach-user-policy --user-name respondr-dev-user \
    --policy-arn arn:aws:iam::aws:policy/AmazonTextractFullAccess
aws iam detach-user-policy --user-name respondr-dev-user \
    --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess
aws iam detach-user-policy --user-name respondr-dev-user \
    --policy-arn arn:aws:iam::aws:policy/AWSLambda_FullAccess
aws iam detach-user-policy --user-name respondr-dev-user \
    --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsFullAccess
aws iam detach-user-policy --user-name respondr-dev-user \
    --policy-arn arn:aws:iam::aws:policy/IAMFullAccess

aws iam delete-user --user-name respondr-dev-user
```

### Delete Local Files

```bash
# Delete generated test documents
rm -rf test_documents/

# Delete generated config files
rm -rf config/*.txt

# Delete Lambda deployment package
rm -f lambda_deployment.zip
rm -rf lambda_package/
```

## Additional Resources

### AWS Documentation

- [AWS Textract](https://docs.aws.amazon.com/textract/)
- [AWS Lambda](https://docs.aws.amazon.com/lambda/)
- [Amazon S3](https://docs.aws.amazon.com/s3/)
- [Amazon DynamoDB](https://docs.aws.amazon.com/dynamodb/)

### Project Documentation

- Lambda function: `lambda/lambda_function.py` (well-commented)
- Dashboard: `dashboard/dashboard.py` (well-commented)
- Setup scripts: `setup/*.sh` (documented inline)

## Support

For issues or questions:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review Lambda logs: `./tests/tail_logs.sh`
3. Verify setup: `python3 tests/verify_processing.py`

## License

This is a prototype/demo project. Use at your own risk.

## Authors

Created as a demonstration of AWS serverless document processing pipeline.
