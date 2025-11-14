#!/bin/bash

# ============================================================================
# Tail Lambda CloudWatch Logs
# ============================================================================
# This script displays the most recent Lambda function logs from CloudWatch.
# ============================================================================

set -e

echo "=================================================="
echo "Lambda Function CloudWatch Logs"
echo "=================================================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

FUNCTION_NAME="RespondrDocProcessor"
LOG_GROUP="/aws/lambda/$FUNCTION_NAME"

echo -e "${BLUE}Function:${NC} $FUNCTION_NAME"
echo -e "${BLUE}Log Group:${NC} $LOG_GROUP"
echo ""

# Check if log group exists
if ! aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" | grep -q "$LOG_GROUP"; then
    echo -e "${RED}✗ Log group not found${NC}"
    echo "The Lambda function may not have been invoked yet."
    exit 1
fi

echo -e "${YELLOW}Fetching recent logs...${NC}"
echo ""

# Get log streams (most recent first)
LOG_STREAMS=$(aws logs describe-log-streams \
    --log-group-name "$LOG_GROUP" \
    --order-by LastEventTime \
    --descending \
    --max-items 5 \
    --query 'logStreams[*].logStreamName' \
    --output text)

if [ -z "$LOG_STREAMS" ]; then
    echo -e "${YELLOW}No log streams found${NC}"
    echo "The Lambda function has not been invoked yet."
    exit 0
fi

echo "=================================================="
echo "RECENT LOGS (Last 5 Invocations)"
echo "=================================================="
echo ""

# Display logs from each stream
for stream in $LOG_STREAMS; do
    echo -e "${BLUE}Log Stream:${NC} $stream"
    echo "---"

    aws logs get-log-events \
        --log-group-name "$LOG_GROUP" \
        --log-stream-name "$stream" \
        --limit 50 \
        --output text \
        --query 'events[*].[timestamp,message]' | \
    while IFS=$'\t' read -r timestamp message; do
        # Convert timestamp to readable format (milliseconds since epoch)
        if [ -n "$timestamp" ]; then
            readable_time=$(date -r $((timestamp / 1000)) '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "")
            if [ -n "$readable_time" ]; then
                echo "[$readable_time] $message"
            else
                echo "$message"
            fi
        fi
    done

    echo ""
    echo "=================================================="
    echo ""
done

echo ""
echo -e "${GREEN}MONITORING OPTIONS:${NC}"
echo ""
echo "To continuously monitor logs in real-time:"
echo "  aws logs tail $LOG_GROUP --follow"
echo ""
echo "To filter logs:"
echo "  aws logs tail $LOG_GROUP --filter-pattern \"ERROR\""
echo ""
echo "To see logs from last 10 minutes:"
echo "  aws logs tail $LOG_GROUP --since 10m"
echo ""
echo "=================================================="
