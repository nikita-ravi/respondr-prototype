#!/usr/bin/env python3
"""
Verify Document Processing

This script queries DynamoDB to verify that documents have been processed
and displays their metadata.
"""

import boto3
import json
from datetime import datetime

# AWS Configuration
DYNAMODB_TABLE = 'respondr_docs_metadata'
REGION = 'us-east-1'

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb', region_name=REGION)
table = dynamodb.Table(DYNAMODB_TABLE)


def fetch_all_documents():
    """Fetch all documents from DynamoDB."""
    try:
        response = table.scan()
        documents = response.get('Items', [])

        # Handle pagination
        while 'LastEvaluatedKey' in response:
            response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
            documents.extend(response.get('Items', []))

        return documents
    except Exception as e:
        print(f"Error fetching documents: {str(e)}")
        return []


def display_document(doc, index):
    """Display document metadata in a formatted way."""
    print(f"\n{'='*70}")
    print(f"DOCUMENT {index + 1}")
    print('='*70)

    print(f"\n📋 ADMINISTRATIVE")
    print(f"  Doc ID:         {doc.get('doc_id', 'N/A')}")
    print(f"  Organization:   {doc.get('org_id', 'N/A')}")
    print(f"  Source:         {doc.get('source_key', 'N/A')}")
    print(f"  Version:        {doc.get('version', 'N/A')}")
    print(f"  Effective Date: {doc.get('effective_date', 'N/A')}")
    print(f"  Author:         {doc.get('author', 'N/A')}")
    print(f"  Processed:      {doc.get('processed_at', 'N/A')}")

    print(f"\n🔧 TECHNICAL")
    print(f"  Pages:          {doc.get('pages', 0)}")
    print(f"  File Size:      {format_bytes(doc.get('file_size', 0))}")
    print(f"  MIME Type:      {doc.get('mime_type', 'N/A')}")
    print(f"  Checksum:       {doc.get('checksum_sha256', 'N/A')[:32]}...")
    print(f"  OCR Coverage:   {doc.get('ocr_coverage_pct', 0)}%")

    print(f"\n📝 CONTENT")
    print(f"  Document Type:  {doc.get('doctype', 'unknown')}")

    roles = doc.get('roles_involved', [])
    print(f"  Roles Involved: {', '.join(roles) if roles else 'None'}")

    hazards = doc.get('hazard_types', [])
    print(f"  Hazard Types:   {', '.join(hazards) if hazards else 'None'}")

    print(f"  Facility:       {doc.get('facility', 'N/A')}")
    print(f"  Jurisdiction:   {doc.get('jurisdiction', 'N/A')}")

    print(f"\n🔒 GOVERNANCE")
    print(f"  Classification: {doc.get('classification', 'internal')}")
    print(f"  PII Present:    {doc.get('pii_present', False)}")

    print(f"\n👁️  TEXT PREVIEW")
    preview = doc.get('text_preview', 'No preview available')
    print(f"  {preview[:200]}...")


def format_bytes(bytes_value):
    """Format bytes to human-readable format."""
    # Convert Decimal to float if needed
    bytes_value = float(bytes_value) if bytes_value else 0

    for unit in ['B', 'KB', 'MB', 'GB']:
        if bytes_value < 1024.0:
            return f"{bytes_value:.1f} {unit}"
        bytes_value /= 1024.0
    return f"{bytes_value:.1f} TB"


def main():
    """Main function to verify document processing."""
    print("\n" + "="*70)
    print("RESPONDR DOCUMENT PROCESSING VERIFICATION")
    print("="*70)

    print("\nFetching documents from DynamoDB...")

    documents = fetch_all_documents()

    if not documents:
        print("\n❌ No documents found in DynamoDB.")
        print("\nPossible reasons:")
        print("  1. Documents haven't been processed yet (wait 1-2 minutes)")
        print("  2. Lambda function encountered an error")
        print("  3. No documents have been uploaded to S3")
        print("\nNext steps:")
        print("  1. Check Lambda logs: ./tests/tail_logs.sh")
        print("  2. Upload test documents: ./tests/upload_test_docs.sh")
        return

    print(f"\n✓ Found {len(documents)} document(s)\n")

    # Sort by processed date
    documents.sort(key=lambda x: x.get('processed_at', ''), reverse=True)

    # Display each document
    for idx, doc in enumerate(documents):
        display_document(doc, idx)

    # Summary statistics
    print(f"\n{'='*70}")
    print("SUMMARY")
    print('='*70)

    total_pages = sum(doc.get('pages', 0) for doc in documents)
    total_size = sum(doc.get('file_size', 0) for doc in documents)

    # Count by org
    orgs = {}
    for doc in documents:
        org = doc.get('org_id', 'unknown')
        orgs[org] = orgs.get(org, 0) + 1

    # Count by doctype
    doctypes = {}
    for doc in documents:
        doctype = doc.get('doctype', 'unknown')
        doctypes[doctype] = doctypes.get(doctype, 0) + 1

    print(f"\nTotal Documents:    {len(documents)}")
    print(f"Total Pages:        {total_pages}")
    print(f"Total Size:         {format_bytes(total_size)}")
    print(f"Average Pages:      {total_pages / len(documents):.1f}")

    print(f"\nOrganizations:")
    for org, count in sorted(orgs.items()):
        print(f"  {org}: {count}")

    print(f"\nDocument Types:")
    for doctype, count in sorted(doctypes.items()):
        print(f"  {doctype}: {count}")

    print(f"\n{'='*70}")
    print("✓ VERIFICATION COMPLETE")
    print('='*70)
    print("\nNext step:")
    print("  View dashboard: streamlit run dashboard/dashboard.py\n")


if __name__ == "__main__":
    main()
