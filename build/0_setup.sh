#!/bin/bash

# OCI A1.Flex Deployment Setup Script
# This script helps you get started quickly and securely

set -e

echo "🚀 OCI A1.Flex Deployment Setup"
echo "==============================="
echo ""

# Check if .env already exists
if [ -f ".env" ]; then
    echo "⚠️  .env file already exists."
    echo "Do you want to overwrite it? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Keeping existing .env file."
        exit 0
    fi
fi

# Copy env.example to .env
echo "📋 Creating .env file from template..."
cp env.example .env

echo "✅ .env file created!"
echo ""
echo "🔧 Next Steps:"
echo "=============="
echo "1. Edit the .env file with your OCI settings:"
echo "   nano .env"
echo ""
echo "2. Required variables to configure:"
echo "   - OCI_COMPARTMENT_ID (your compartment OCID)"
echo "   - OCI_SUBNET_ID (your subnet OCID)"
echo "   - SSH_PUBLIC_KEY_PATH (path to your SSH public key)"
echo ""
echo "3. Install OCI CLI if needed:"
echo "   ./install-oci-cli.sh"
echo ""
echo "4. Configure OCI CLI:"
echo "   oci setup config"
echo ""
echo "5. Test your setup:"
echo "   ./deploy-oci-instance.sh --test"
echo ""
echo "6. Get your A1.Flex instance:"
echo "   ./deploy-oci-instance.sh"
echo ""
echo "🔒 Security Notes:"
echo "=================="
echo "- The .env file contains sensitive data and is ignored by git"
echo "- Never commit your .env file to version control"
echo "- SSH keys should remain in your ~/.ssh/ directory"
echo ""
echo "🎯 Target: VM.Standard.A1.Flex (4 OCPUs, 24GB RAM)"
echo "💰 Cost: FREE (Always Free Tier)"
echo "♾️  Strategy: Infinite retry until capacity available" 