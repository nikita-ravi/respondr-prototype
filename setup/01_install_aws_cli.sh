#!/bin/bash

# ============================================================================
# Script 01: Install AWS CLI
# ============================================================================
# This script checks if AWS CLI is installed and installs it if needed.
# It works for both macOS (using Homebrew or official installer) and Linux.
# ============================================================================

set -e  # Exit on any error

echo "=================================================="
echo "STEP 1: AWS CLI Installation"
echo "=================================================="
echo ""

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if AWS CLI is already installed
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version 2>&1)
    echo -e "${GREEN}✓ AWS CLI is already installed${NC}"
    echo "  Version: $AWS_VERSION"
    echo ""
    echo "Skipping installation."
    exit 0
fi

echo -e "${YELLOW}AWS CLI is not installed. Installing now...${NC}"
echo ""

# Detect operating system
OS="$(uname -s)"

case "${OS}" in
    Darwin*)
        echo "Detected: macOS"
        echo ""

        # Check if Homebrew is available
        if command -v brew &> /dev/null; then
            echo "Using Homebrew to install AWS CLI..."
            brew install awscli
        else
            echo "Homebrew not found. Using official AWS CLI installer..."
            echo ""

            # Download the installer
            echo "Downloading AWS CLI installer..."
            curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "/tmp/AWSCLIV2.pkg"

            echo "Installing AWS CLI (may require sudo password)..."
            sudo installer -pkg /tmp/AWSCLIV2.pkg -target /

            # Clean up
            rm /tmp/AWSCLIV2.pkg
        fi
        ;;

    Linux*)
        echo "Detected: Linux"
        echo ""
        echo "Using official AWS CLI installer..."

        # Download and install
        cd /tmp
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip -q awscliv2.zip
        sudo ./aws/install

        # Clean up
        rm -rf awscliv2.zip aws
        cd - > /dev/null
        ;;

    *)
        echo -e "${RED}Unsupported operating system: ${OS}${NC}"
        echo "Please install AWS CLI manually from:"
        echo "https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
        ;;
esac

echo ""
echo "=================================================="
echo "VERIFICATION"
echo "=================================================="

# Verify installation
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version 2>&1)
    echo -e "${GREEN}✓ AWS CLI installed successfully!${NC}"
    echo "  Version: $AWS_VERSION"
    echo ""
    echo -e "${GREEN}NEXT STEP:${NC}"
    echo "  Run: ./setup/02_configure_aws.sh"
else
    echo -e "${RED}✗ Installation failed${NC}"
    echo "Please install AWS CLI manually and try again."
    exit 1
fi

echo "=================================================="
