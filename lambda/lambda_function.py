"""
Respondr Document Processor Lambda Function

This Lambda function is triggered when PDF documents are uploaded to S3.
It extracts text using AWS Textract, parses metadata, and stores the results
in DynamoDB and S3.

Metadata Categories:
- Administrative: org_id, version, effective_date, author
- Technical: pages, file_size, mime_type, checksum_sha256, ocr_coverage
- Content: doctype, roles_involved, hazard_types, facility, jurisdiction
- Governance: classification, pii_present
"""

import json
import boto3
import hashlib
import re
import uuid
from datetime import datetime
from decimal import Decimal
from typing import Dict, List, Any, Optional

# Initialize AWS clients
s3_client = boto3.client('s3')
textract_client = boto3.client('textract')
dynamodb = boto3.resource('dynamodb')

# Configuration
DYNAMODB_TABLE = 'respondr_docs_metadata'
PARSED_BUCKET = 'respondr-docs-demo-nit-parsed'

# Metadata extraction patterns
DOCTYPE_KEYWORDS = {
    'emergency_plan': ['emergency', 'evacuation', 'response plan', 'continuity', 'disaster'],
    'sop': ['standard operating procedure', 'sop', 'procedure', 'protocol', 'process'],
    'policy': ['policy', 'policies', 'regulation', 'compliance', 'guideline'],
    'incident_report': ['incident report', 'incident', 'accident report', 'injury report'],
    'training': ['training', 'course', 'workshop', 'certification', 'instruction']
}

ROLE_KEYWORDS = {
    'security': ['security', 'guard', 'officer', 'protection'],
    'ehs': ['ehs', 'environment', 'health', 'safety', 'environmental health'],
    'facilities': ['facilities', 'maintenance', 'building', 'grounds'],
    'hr': ['human resources', 'hr', 'personnel', 'employee relations'],
    'medical': ['medical', 'nurse', 'physician', 'healthcare', 'first aid']
}

HAZARD_KEYWORDS = {
    'fire': ['fire', 'smoke', 'flame', 'burn', 'combustion'],
    'chemical': ['chemical', 'hazmat', 'spill', 'toxic', 'corrosive'],
    'active_shooter': ['active shooter', 'armed intruder', 'gunman', 'shooter'],
    'flood': ['flood', 'water damage', 'inundation', 'flooding'],
    'medical_emergency': ['medical emergency', 'cardiac', 'stroke', 'injury', 'trauma']
}

# US state abbreviations for jurisdiction detection
US_STATES = [
    'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
    'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
    'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
    'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
    'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY'
]


def lambda_handler(event, context):
    """
    Main Lambda handler function.

    Args:
        event: S3 event notification
        context: Lambda context object

    Returns:
        dict: Response with status code and message
    """
    print("Lambda function started")
    print(f"Event: {json.dumps(event)}")

    try:
        # Parse S3 event
        for record in event['Records']:
            bucket = record['s3']['bucket']['name']
            key = record['s3']['object']['key']

            print(f"Processing file: s3://{bucket}/{key}")

            # Skip if not a PDF
            if not key.lower().endswith('.pdf'):
                print(f"Skipping non-PDF file: {key}")
                continue

            # Process the document
            process_document(bucket, key)

        return {
            'statusCode': 200,
            'body': json.dumps('Document processing completed successfully')
        }

    except Exception as e:
        print(f"Error processing document: {str(e)}")
        import traceback
        traceback.print_exc()

        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }


def process_document(bucket: str, key: str):
    """
    Process a single document: extract text, parse metadata, store results.

    Args:
        bucket: S3 bucket name
        key: S3 object key
    """
    print(f"Starting document processing for {key}")

    # Step 1: Extract text using Textract
    extracted_text, page_count = extract_text_from_pdf(bucket, key)
    print(f"Extracted {len(extracted_text)} characters from {page_count} pages")

    # Step 2: Get file metadata
    file_metadata = get_file_metadata(bucket, key)

    # Step 3: Parse metadata from text
    parsed_metadata = parse_metadata(extracted_text, key)

    # Step 4: Combine all metadata
    doc_id = str(uuid.uuid4())
    complete_metadata = {
        'doc_id': doc_id,
        'source_bucket': bucket,
        'source_key': key,
        'processed_at': datetime.utcnow().isoformat(),

        # Administrative metadata
        'org_id': parsed_metadata['org_id'],
        'version': parsed_metadata.get('version', '1.0'),
        'effective_date': parsed_metadata.get('effective_date'),
        'author': parsed_metadata.get('author'),

        # Technical metadata
        'pages': page_count,
        'file_size': file_metadata['file_size'],
        'mime_type': 'application/pdf',
        'checksum_sha256': file_metadata['checksum'],
        'ocr_coverage_pct': calculate_ocr_coverage(extracted_text, page_count),

        # Content metadata
        'doctype': parsed_metadata['doctype'],
        'roles_involved': parsed_metadata['roles_involved'],
        'hazard_types': parsed_metadata['hazard_types'],
        'facility': parsed_metadata.get('facility'),
        'jurisdiction': parsed_metadata.get('jurisdiction'),

        # Governance metadata
        'classification': 'internal',
        'pii_present': detect_pii(extracted_text),

        # Text preview
        'text_preview': extracted_text[:500] if extracted_text else ''
    }

    print(f"Metadata parsed: {json.dumps(complete_metadata, indent=2)}")

    # Step 5: Store metadata in DynamoDB
    store_metadata_in_dynamodb(complete_metadata)
    print(f"Metadata stored in DynamoDB with doc_id: {doc_id}")

    # Step 6: Save extracted text to S3
    save_text_to_s3(extracted_text, doc_id, key)
    print(f"Extracted text saved to S3")

    print("Document processing completed successfully")


def extract_text_from_pdf(bucket: str, key: str) -> tuple[str, int]:
    """
    Extract text from PDF using AWS Textract.

    Args:
        bucket: S3 bucket name
        key: S3 object key

    Returns:
        tuple: (extracted_text, page_count)
    """
    print("Starting Textract document analysis")

    # Start document analysis
    response = textract_client.start_document_text_detection(
        DocumentLocation={
            'S3Object': {
                'Bucket': bucket,
                'Name': key
            }
        }
    )

    job_id = response['JobId']
    print(f"Textract job started with ID: {job_id}")

    # Wait for job to complete
    import time
    max_attempts = 60  # 5 minutes max
    attempt = 0

    while attempt < max_attempts:
        response = textract_client.get_document_text_detection(JobId=job_id)
        status = response['JobStatus']

        if status == 'SUCCEEDED':
            print("Textract job completed successfully")
            break
        elif status == 'FAILED':
            raise Exception("Textract job failed")

        time.sleep(5)
        attempt += 1

    if attempt >= max_attempts:
        raise Exception("Textract job timeout")

    # Extract text from all pages
    text_blocks = []
    page_count = 0

    # Get first page of results
    for block in response.get('Blocks', []):
        if block['BlockType'] == 'LINE':
            text_blocks.append(block['Text'])
        elif block['BlockType'] == 'PAGE':
            page_count += 1

    # Get remaining pages if any
    next_token = response.get('NextToken')
    while next_token:
        response = textract_client.get_document_text_detection(
            JobId=job_id,
            NextToken=next_token
        )

        for block in response.get('Blocks', []):
            if block['BlockType'] == 'LINE':
                text_blocks.append(block['Text'])
            elif block['BlockType'] == 'PAGE':
                page_count += 1

        next_token = response.get('NextToken')

    extracted_text = '\n'.join(text_blocks)
    return extracted_text, page_count


def get_file_metadata(bucket: str, key: str) -> Dict[str, Any]:
    """
    Get file metadata from S3.

    Args:
        bucket: S3 bucket name
        key: S3 object key

    Returns:
        dict: File metadata (size, checksum)
    """
    # Get file size
    response = s3_client.head_object(Bucket=bucket, Key=key)
    file_size = response['ContentLength']

    # Download file to calculate checksum
    obj = s3_client.get_object(Bucket=bucket, Key=key)
    file_content = obj['Body'].read()
    checksum = hashlib.sha256(file_content).hexdigest()

    return {
        'file_size': file_size,
        'checksum': checksum
    }


def parse_metadata(text: str, key: str) -> Dict[str, Any]:
    """
    Parse metadata from extracted text using keyword matching and regex.

    Args:
        text: Extracted text from document
        key: S3 object key (for org_id extraction)

    Returns:
        dict: Parsed metadata
    """
    text_lower = text.lower()

    # Extract org_id from S3 path (e.g., org1/document.pdf -> org1)
    org_id = extract_org_id_from_path(key)

    # Detect document type
    doctype = detect_doctype(text_lower)

    # Detect roles involved
    roles_involved = detect_keywords(text_lower, ROLE_KEYWORDS)

    # Detect hazard types
    hazard_types = detect_keywords(text_lower, HAZARD_KEYWORDS)

    # Extract version (e.g., "Version 1.0", "v2.3")
    version = extract_version(text)

    # Extract effective date
    effective_date = extract_date(text)

    # Extract author
    author = extract_author(text)

    # Extract facility references (e.g., "Building A", "Room 301")
    facility = extract_facility(text)

    # Detect jurisdiction (US state)
    jurisdiction = detect_jurisdiction(text)

    return {
        'org_id': org_id,
        'doctype': doctype,
        'roles_involved': roles_involved,
        'hazard_types': hazard_types,
        'version': version,
        'effective_date': effective_date,
        'author': author,
        'facility': facility,
        'jurisdiction': jurisdiction
    }


def extract_org_id_from_path(key: str) -> str:
    """Extract organization ID from S3 path."""
    parts = key.split('/')
    if len(parts) > 1:
        return parts[0]
    return 'default_org'


def detect_doctype(text: str) -> str:
    """Detect document type using keyword matching."""
    scores = {}

    for doctype, keywords in DOCTYPE_KEYWORDS.items():
        score = sum(1 for keyword in keywords if keyword in text)
        scores[doctype] = score

    # Return doctype with highest score
    if scores:
        max_doctype = max(scores, key=scores.get)
        if scores[max_doctype] > 0:
            return max_doctype

    return 'unknown'


def detect_keywords(text: str, keyword_dict: Dict[str, List[str]]) -> List[str]:
    """Detect keywords in text and return matching categories."""
    found = []

    for category, keywords in keyword_dict.items():
        if any(keyword in text for keyword in keywords):
            found.append(category)

    return found


def extract_version(text: str) -> Optional[str]:
    """Extract version number from text."""
    patterns = [
        r'version\s+(\d+\.\d+)',
        r'v(\d+\.\d+)',
        r'rev\.?\s+(\d+\.\d+)'
    ]

    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            return match.group(1)

    return None


def extract_date(text: str) -> Optional[str]:
    """Extract effective date from text."""
    patterns = [
        r'effective\s+date:\s*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})',
        r'effective:\s*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})',
        r'date:\s*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})'
    ]

    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            return match.group(1)

    return None


def extract_author(text: str) -> Optional[str]:
    """Extract author name from text."""
    patterns = [
        r'author:\s*([A-Z][a-z]+\s+[A-Z][a-z]+)',
        r'prepared\s+by:\s*([A-Z][a-z]+\s+[A-Z][a-z]+)',
        r'written\s+by:\s*([A-Z][a-z]+\s+[A-Z][a-z]+)'
    ]

    for pattern in patterns:
        match = re.search(pattern, text)
        if match:
            return match.group(1)

    return None


def extract_facility(text: str) -> Optional[str]:
    """Extract facility references from text."""
    patterns = [
        r'(Building\s+[A-Z0-9]+)',
        r'(Room\s+\d+)',
        r'(Floor\s+\d+)'
    ]

    facilities = []
    for pattern in patterns:
        matches = re.findall(pattern, text, re.IGNORECASE)
        facilities.extend(matches)

    if facilities:
        return ', '.join(set(facilities[:3]))  # Return up to 3 unique facilities

    return None


def detect_jurisdiction(text: str) -> Optional[str]:
    """Detect US state jurisdiction."""
    # Look for state abbreviations
    for state in US_STATES:
        # Match state abbreviation with word boundaries
        if re.search(rf'\b{state}\b', text):
            return state

    return None


def calculate_ocr_coverage(text: str, page_count: int) -> float:
    """Calculate OCR coverage percentage."""
    if page_count == 0:
        return 0.0

    # Estimate: average 300 words per page for good coverage
    word_count = len(text.split())
    expected_words = page_count * 300

    coverage = min(100.0, (word_count / expected_words) * 100)
    return round(coverage, 2)


def detect_pii(text: str) -> bool:
    """Detect presence of PII (phone numbers, emails, SSN)."""
    pii_patterns = [
        r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b',  # Phone number
        r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',  # Email
        r'\b\d{3}-\d{2}-\d{4}\b'  # SSN
    ]

    for pattern in pii_patterns:
        if re.search(pattern, text):
            return True

    return False


def store_metadata_in_dynamodb(metadata: Dict[str, Any]):
    """Store metadata in DynamoDB table."""
    table = dynamodb.Table(DYNAMODB_TABLE)

    # Convert lists to DynamoDB format
    item = metadata.copy()
    if not item.get('roles_involved'):
        item['roles_involved'] = []
    if not item.get('hazard_types'):
        item['hazard_types'] = []

    # Convert float to Decimal for DynamoDB
    if 'ocr_coverage_pct' in item and isinstance(item['ocr_coverage_pct'], float):
        item['ocr_coverage_pct'] = Decimal(str(item['ocr_coverage_pct']))

    table.put_item(Item=item)


def save_text_to_s3(text: str, doc_id: str, original_key: str):
    """Save extracted text to S3 parsed bucket."""
    # Create key based on original filename
    filename = original_key.split('/')[-1].replace('.pdf', '.txt')
    parsed_key = f"{doc_id}/{filename}"

    s3_client.put_object(
        Bucket=PARSED_BUCKET,
        Key=parsed_key,
        Body=text.encode('utf-8'),
        ContentType='text/plain'
    )
