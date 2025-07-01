#!/bin/bash

# Script to discover available availability domains and instance shapes
# This helps expand your deployment options

set -e

echo "=== OCI Resource Discovery ==="
echo ""

# Check if OCI CLI is available
if ! command -v oci >/dev/null 2>&1; then
    echo "❌ OCI CLI not found. Please install it first using ./install-oci-cli.sh"
    exit 1
fi

# Get current region
CURRENT_REGION=$(oci iam region-subscription list --query 'data[?contains("is-home-region", `true`)].{region:"region-name"}' --output table 2>/dev/null | grep -v "region-name" | grep -v "+" | grep -v "|" | head -1 | xargs || echo "ca-toronto-1")

echo "🌍 Current Region: $CURRENT_REGION"
echo ""

# Get all availability domains
echo "📊 Available Availability Domains:"
echo "=================================="
oci iam availability-domain list --compartment-id $(oci iam compartment list --query 'data[0].id' --raw-output) --query 'data[].{Name:name}' --output table 2>/dev/null || echo "Unable to fetch availability domains"
echo ""

# Get available shapes in the region
echo "🖥️  Available Instance Shapes:"
echo "=============================="
oci compute shape list --compartment-id $(oci iam compartment list --query 'data[0].id' --raw-output) --query 'data[?contains(shape, `Standard`)].{Shape:shape, CPUs:ocpus, Memory:memory, Type:"processor-description"}' --output table 2>/dev/null | head -20 || echo "Unable to fetch instance shapes"
echo ""

# Get A1 Flex shapes specifically (ARM-based, often more available)
echo "💪 ARM-based (A1.Flex) Shapes:"
echo "==============================="
oci compute shape list --compartment-id $(oci iam compartment list --query 'data[0].id' --raw-output) --query 'data[?contains(shape, `A1`)].{Shape:shape, CPUs:ocpus, Memory:memory}' --output table 2>/dev/null || echo "Unable to fetch A1 shapes"
echo ""

# Check capacity for different shapes
echo "⚡ Checking Capacity (this may take a moment):"
echo "=============================================="

COMPARTMENT_ID=$(oci iam compartment list --query 'data[0].id' --raw-output)
ADS=$(oci iam availability-domain list --compartment-id $COMPARTMENT_ID --query 'data[].name' --raw-output)

if [ -n "$ADS" ]; then
    for ad in $ADS; do
        echo "📍 Availability Domain: $ad"
        
        # Check A1.Flex capacity
        echo "  VM.Standard.A1.Flex (4 OCPUs, 24GB RAM):"
        oci compute capacity-reservation list \
            --compartment-id $COMPARTMENT_ID \
            --availability-domain "$ad" \
            --query 'data[].{State:"lifecycle-state", Shape:"instance-shape"}' \
            --output table 2>/dev/null | head -5 || echo "    ℹ️  Capacity info not available"
        
        echo ""
    done
else
    echo "Unable to fetch availability domains for capacity check"
fi

echo "💡 Tips:"
echo "========"
echo "1. ARM-based instances (A1.Flex) often have better availability"
echo "2. Try different availability domains if one is at capacity"
echo "3. Consider micro instances (E2.1.Micro) as alternatives"
echo "4. Off-peak hours may have better availability"
echo ""

echo "🔧 To update your deployment script:"
echo "===================================="
echo "Edit the AVAILABILITY_DOMAINS array in deploy-oci-instance.sh with the domains listed above"
echo "Edit the INSTANCE_SHAPES array to include shapes that are available in your region" 