"""
Respondr Document Metadata Dashboard

A Streamlit dashboard to view and analyze document metadata extracted
from the AWS pipeline. Displays documents, filters, statistics, and
allows downloading parsed text.
"""

import streamlit as st
import boto3
from boto3.dynamodb.conditions import Key, Attr
import pandas as pd
from typing import List, Dict, Any
import json

# Page configuration - MUST be first Streamlit command
st.set_page_config(
    page_title="Respondr Document Metadata Dashboard",
    page_icon="📄",
    layout="wide"
)

# AWS Configuration
DYNAMODB_TABLE = 'respondr_docs_metadata'
PARSED_BUCKET = 'respondr-docs-demo-nit-parsed'
REGION = 'us-east-1'

# Initialize AWS clients
@st.cache_resource
def get_aws_clients():
    """Initialize and cache AWS clients."""
    # Try to get credentials from Streamlit secrets (for cloud deployment)
    # Falls back to default credentials (for local development)
    try:
        aws_access_key = st.secrets.get("AWS_ACCESS_KEY_ID")
        aws_secret_key = st.secrets.get("AWS_SECRET_ACCESS_KEY")
        aws_region = st.secrets.get("AWS_DEFAULT_REGION", REGION)

        if aws_access_key and aws_secret_key:
            # Use credentials from secrets
            dynamodb = boto3.resource(
                'dynamodb',
                region_name=aws_region,
                aws_access_key_id=aws_access_key,
                aws_secret_access_key=aws_secret_key
            )
            s3_client = boto3.client(
                's3',
                region_name=aws_region,
                aws_access_key_id=aws_access_key,
                aws_secret_access_key=aws_secret_key
            )
        else:
            # Fall back to default credentials (local development)
            dynamodb = boto3.resource('dynamodb', region_name=REGION)
            s3_client = boto3.client('s3', region_name=REGION)
    except:
        # Fall back to default credentials
        dynamodb = boto3.resource('dynamodb', region_name=REGION)
        s3_client = boto3.client('s3', region_name=REGION)

    return dynamodb, s3_client

dynamodb, s3_client = get_aws_clients()
table = dynamodb.Table(DYNAMODB_TABLE)


def fetch_all_documents() -> List[Dict[str, Any]]:
    """Fetch all documents from DynamoDB."""
    try:
        response = table.scan()
        documents = response.get('Items', [])

        # Handle pagination if there are more items
        while 'LastEvaluatedKey' in response:
            response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
            documents.extend(response.get('Items', []))

        return documents
    except Exception as e:
        st.error(f"Error fetching documents: {str(e)}")
        return []


def fetch_documents_by_org(org_id: str) -> List[Dict[str, Any]]:
    """Fetch documents filtered by organization ID."""
    try:
        response = table.scan(
            FilterExpression=Attr('org_id').eq(org_id)
        )
        return response.get('Items', [])
    except Exception as e:
        st.error(f"Error fetching documents: {str(e)}")
        return []


def fetch_documents_by_org_doctype(org_id: str, doctype: str) -> List[Dict[str, Any]]:
    """Fetch documents using the org-doctype GSI."""
    try:
        response = table.query(
            IndexName='org-doctype-index',
            KeyConditionExpression=Key('org_id').eq(org_id) & Key('doctype').eq(doctype)
        )
        return response.get('Items', [])
    except Exception as e:
        st.error(f"Error fetching documents: {str(e)}")
        return []


def download_parsed_text(doc_id: str, filename: str) -> str:
    """Download parsed text from S3."""
    try:
        # Construct S3 key
        s3_key = f"{doc_id}/{filename.replace('.pdf', '.txt')}"

        response = s3_client.get_object(Bucket=PARSED_BUCKET, Key=s3_key)
        text = response['Body'].read().decode('utf-8')
        return text
    except Exception as e:
        st.error(f"Error downloading text: {str(e)}")
        return ""


def calculate_statistics(documents: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Calculate summary statistics from documents."""
    if not documents:
        return {
            'total_docs': 0,
            'total_orgs': 0,
            'avg_pages': 0,
            'total_size': 0,
            'doctypes': {},
            'roles': {},
            'hazards': {}
        }

    # Convert Decimal to float for numeric values
    total_pages = sum(float(doc.get('pages', 0)) for doc in documents)
    total_size = sum(float(doc.get('file_size', 0)) for doc in documents)

    # Count doctypes
    doctypes = {}
    for doc in documents:
        doctype = doc.get('doctype', 'unknown')
        doctypes[doctype] = doctypes.get(doctype, 0) + 1

    # Count roles
    roles = {}
    for doc in documents:
        for role in doc.get('roles_involved', []):
            roles[role] = roles.get(role, 0) + 1

    # Count hazards
    hazards = {}
    for doc in documents:
        for hazard in doc.get('hazard_types', []):
            hazards[hazard] = hazards.get(hazard, 0) + 1

    # Get unique orgs
    orgs = set(doc.get('org_id', 'unknown') for doc in documents)

    return {
        'total_docs': len(documents),
        'total_orgs': len(orgs),
        'avg_pages': float(round(total_pages / len(documents), 1)) if documents else 0,
        'total_size': total_size,
        'doctypes': doctypes,
        'roles': roles,
        'hazards': hazards
    }


def format_bytes(bytes_value: int) -> str:
    """Format bytes to human-readable format."""
    # Convert to float to handle Decimal types from DynamoDB
    bytes_value = float(bytes_value) if bytes_value else 0

    for unit in ['B', 'KB', 'MB', 'GB']:
        if bytes_value < 1024.0:
            return f"{bytes_value:.1f} {unit}"
        bytes_value /= 1024.0
    return f"{bytes_value:.1f} TB"


def main():
    """Main dashboard application."""

    # Header
    st.title("📄 Respondr Document Metadata Dashboard")
    st.markdown("---")

    # Sidebar filters
    st.sidebar.header("🔍 Filters")

    # Refresh button
    if st.sidebar.button("🔄 Refresh Data"):
        st.cache_data.clear()
        st.rerun()

    # Filter by org_id
    org_filter = st.sidebar.text_input("Organization ID", placeholder="e.g., org1")

    # Filter by doctype
    doctype_options = ['All', 'emergency_plan', 'sop', 'policy', 'incident_report', 'training', 'unknown']
    doctype_filter = st.sidebar.selectbox("Document Type", doctype_options)

    # Fetch documents based on filters
    if org_filter and doctype_filter != 'All':
        documents = fetch_documents_by_org_doctype(org_filter, doctype_filter)
    elif org_filter:
        documents = fetch_documents_by_org(org_filter)
    else:
        documents = fetch_all_documents()

    # Calculate statistics
    stats = calculate_statistics(documents)

    # Display statistics
    st.header("📊 Summary Statistics")

    col1, col2, col3, col4 = st.columns(4)

    with col1:
        st.metric("Total Documents", stats['total_docs'])

    with col2:
        st.metric("Organizations", stats['total_orgs'])

    with col3:
        st.metric("Avg Pages", stats['avg_pages'])

    with col4:
        st.metric("Total Size", format_bytes(stats['total_size']))

    st.markdown("---")

    # Display doctype breakdown
    if stats['doctypes']:
        st.subheader("📑 Document Types")
        col1, col2, col3 = st.columns(3)

        with col1:
            st.bar_chart(stats['doctypes'])

        with col2:
            if stats['roles']:
                st.write("**Roles Involved:**")
                for role, count in sorted(stats['roles'].items(), key=lambda x: x[1], reverse=True):
                    st.write(f"- {role}: {count}")

        with col3:
            if stats['hazards']:
                st.write("**Hazard Types:**")
                for hazard, count in sorted(stats['hazards'].items(), key=lambda x: x[1], reverse=True):
                    st.write(f"- {hazard}: {count}")

    st.markdown("---")

    # Display documents
    st.header(f"📚 Documents ({len(documents)})")

    if not documents:
        st.info("No documents found. Upload PDFs to S3 to get started!")
        st.code("aws s3 cp document.pdf s3://respondr-docs-demo-nit/org1/document.pdf")
        return

    # Sort documents by processed date (newest first)
    documents.sort(key=lambda x: x.get('processed_at', ''), reverse=True)

    # Display each document in an expandable card
    for idx, doc in enumerate(documents):
        with st.expander(
            f"📄 {doc.get('source_key', 'Unknown')} - {doc.get('doctype', 'unknown')} "
            f"({doc.get('pages', 0)} pages)"
        ):
            # Create columns for metadata
            col1, col2 = st.columns(2)

            with col1:
                st.subheader("📋 Administrative")
                st.write(f"**Doc ID:** `{doc.get('doc_id', 'N/A')}`")
                st.write(f"**Organization:** {doc.get('org_id', 'N/A')}")
                st.write(f"**Version:** {doc.get('version', 'N/A')}")
                st.write(f"**Effective Date:** {doc.get('effective_date', 'N/A')}")
                st.write(f"**Author:** {doc.get('author', 'N/A')}")
                st.write(f"**Processed:** {doc.get('processed_at', 'N/A')}")

                st.subheader("🔧 Technical")
                st.write(f"**Pages:** {doc.get('pages', 0)}")
                st.write(f"**File Size:** {format_bytes(doc.get('file_size', 0))}")
                st.write(f"**MIME Type:** {doc.get('mime_type', 'N/A')}")
                st.write(f"**Checksum:** `{doc.get('checksum_sha256', 'N/A')[:16]}...`")
                st.write(f"**OCR Coverage:** {doc.get('ocr_coverage_pct', 0)}%")

            with col2:
                st.subheader("📝 Content")
                st.write(f"**Document Type:** {doc.get('doctype', 'unknown')}")

                roles = doc.get('roles_involved', [])
                st.write(f"**Roles Involved:** {', '.join(roles) if roles else 'None'}")

                hazards = doc.get('hazard_types', [])
                st.write(f"**Hazard Types:** {', '.join(hazards) if hazards else 'None'}")

                st.write(f"**Facility:** {doc.get('facility', 'N/A')}")
                st.write(f"**Jurisdiction:** {doc.get('jurisdiction', 'N/A')}")

                st.subheader("🔒 Governance")
                st.write(f"**Classification:** {doc.get('classification', 'internal')}")

                pii_present = doc.get('pii_present', False)
                pii_icon = "⚠️" if pii_present else "✅"
                st.write(f"**PII Present:** {pii_icon} {pii_present}")

            # Source information
            st.subheader("📂 Source")
            source_uri = f"s3://{doc.get('source_bucket', '')}/{doc.get('source_key', '')}"
            st.code(source_uri)

            # Text preview
            st.subheader("👁️ Text Preview")
            text_preview = doc.get('text_preview', 'No preview available')
            st.text_area("First 500 characters:", text_preview, height=100, key=f"preview_{idx}")

            # Download button for full text
            if st.button(f"📥 Download Full Text", key=f"download_{idx}"):
                try:
                    filename = doc.get('source_key', '').split('/')[-1]
                    full_text = download_parsed_text(doc.get('doc_id'), filename)

                    if full_text:
                        st.download_button(
                            label="💾 Save Text File",
                            data=full_text,
                            file_name=f"{doc.get('doc_id')}.txt",
                            mime="text/plain",
                            key=f"save_{idx}"
                        )
                except Exception as e:
                    st.error(f"Error: {str(e)}")


if __name__ == "__main__":
    main()
