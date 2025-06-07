#!/bin/bash

# OCI A1.Flex Deployment Script with Infinite Retry Logic
# This script continuously attempts to deploy A1.Flex until capacity becomes available

set -e

# Configuration (with environment variable support)
MIN_RETRY_DELAY=${MIN_RETRY_DELAY:-20}      # Minimum wait time in seconds
MAX_RETRY_DELAY=${MAX_RETRY_DELAY:-60}     # Maximum wait time in seconds (1 minute)
LOG_FILE="deployment.log"
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
DRY_RUN=false

# Notification settings
ENABLE_NOTIFICATIONS=${ENABLE_NOTIFICATIONS:-true}
ENABLE_SOUNDS=${ENABLE_SOUNDS:-true}
ENABLE_VOICE=${ENABLE_VOICE:-true}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Availability domains to try (from environment or defaults)
if [ -n "$OCI_AVAILABILITY_DOMAIN" ]; then
    AVAILABILITY_DOMAINS=("$OCI_AVAILABILITY_DOMAIN")
else
    # Default availability domains for Toronto region (try all available ADs)
    AVAILABILITY_DOMAINS=(
        "mUFn:CA-TORONTO-1-AD-1"
        # Note: Toronto only has one AD, but script supports multiple
    )
fi

# A1.Flex ONLY - the target instance shape
TARGET_SHAPE="VM.Standard.A1.Flex"    # Always Free: 4 OCPUs, 24GB RAM
TARGET_OCPUS="4"
TARGET_MEMORY="24"

# Function to log messages
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

# Function to log errors
log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
}

# Function to log success
log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS:${NC} $1" | tee -a "$LOG_FILE"
}

# Function to log warnings
log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

# Load environment variables from .env file if it exists
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
    log_success "✅ Environment variables loaded from .env file"
else
    log_warning "⚠️  No .env file found. Using defaults and Terraform variables."
    log "💡 Copy env.example to .env and configure your settings for better security"
fi

# Function to play notification sound (macOS)
play_notification() {
    if [ "$ENABLE_SOUNDS" = "true" ] && command -v afplay >/dev/null 2>&1; then
        # Use system sound
        afplay /System/Library/Sounds/Glass.aiff
    fi
    
    if [ "$ENABLE_VOICE" = "true" ] && command -v say >/dev/null 2>&1; then
        # Use text-to-speech
        say "A1 Flex instance deployment completed"
    fi
}

# Function to send desktop notification (macOS)
send_notification() {
    local title="$1"
    local message="$2"
    local sound="$3"
    
    if [ "$ENABLE_NOTIFICATIONS" = "true" ] && command -v osascript >/dev/null 2>&1; then
        osascript -e "display notification \"$message\" with title \"$title\" sound name \"$sound\""
    fi
}

# Function to check if OCI CLI is installed and configured
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if Terraform is installed
    if ! command -v terraform >/dev/null 2>&1; then
        log_error "Terraform is not installed. Please install Terraform first."
        exit 1
    fi
    
    # Check if OCI CLI is installed
    if ! command -v oci >/dev/null 2>&1; then
        log_error "OCI CLI is not installed. Run ./install-oci-cli.sh first."
        exit 1
    fi
    
    # Check if OCI CLI is configured
    if ! oci iam region list >/dev/null 2>&1; then
        log_error "OCI CLI is not configured. Run 'oci setup config' first."
        exit 1
    fi
    
    log_success "Prerequisites check passed!"
}

# Function to get available subnets 
get_available_subnets() {
    local ad="$1"
    
    # Use environment variable if set, otherwise use defaults
    if [ -n "$OCI_SUBNET_ID" ]; then
        echo "$OCI_SUBNET_ID"
    else
        # No default subnet - force user to configure
        log_error "OCI_SUBNET_ID not configured in .env file. Please add your subnet OCID."
        exit 1
    fi
}

# Function to test notifications
test_notifications() {
    log "Testing notification system..."
    
    # Test desktop notification
    send_notification "OCI Deployment Test" "Testing notification system - this is a test!" "Glass"
    
    # Test sound notification
    play_notification
    
    # Test voice notification
    if command -v say >/dev/null 2>&1; then
        say "Notification test completed successfully"
    fi
    
    log_success "Notification test completed!"
    echo ""
    echo "Did you see the desktop notification and hear the sound? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        log_success "Notifications working correctly!"
        return 0
    else
        log_warning "Notifications may not be working. Check system preferences for notification permissions."
        return 1
    fi
}

# Function to show deployment preview
show_deployment_preview() {
    local ad="$1"
    local subnet_id="$2"
    local instance_name="instance-${TIMESTAMP}-$(echo $ad | cut -d'-' -f3)"
    
    echo ""
    echo "🔍 A1.FLEX DEPLOYMENT PREVIEW"
    echo "============================="
    echo "📍 Availability Domain: $ad"
    echo "🖥️  Instance Shape: $TARGET_SHAPE (ARM-based)"
    echo "💾 Memory: ${TARGET_MEMORY}GB"
    echo "⚡ OCPUs: $TARGET_OCPUS"
    echo "💿 Boot Volume: 50GB"
    echo "🏷️  Instance Name: $instance_name"
    echo "🌍 Region: CA-TORONTO-1"
    echo "🔐 SSH Key: [Your configured SSH key]"
    echo "🔗 Subnet: $subnet_id"
    echo "💰 Boot Volume VPUs: 10"
    echo "💸 Cost: FREE (Always Free Tier) ✅"
    echo "🔄 Retry Strategy: Infinite (until A1.Flex available)"
    echo ""
    
    # Initialize Terraform if needed
    if [ ! -d ".terraform" ]; then
        log "Initializing Terraform for preview..."
        terraform init
    fi
    
    # Show exact Terraform plan
    log "Generating A1.Flex Terraform plan preview..."
    terraform plan \
        -var="availability_domain=$ad" \
        -var="instance_shape=$TARGET_SHAPE" \
        -var="subnet_id=$subnet_id" \
        -var="instance_name=$instance_name" \
        -var="ocpus=$TARGET_OCPUS" \
        -var="memory_gb=$TARGET_MEMORY" \
        -no-color
    
    echo ""
    echo "📋 RESOURCE SUMMARY:"
    echo "==================="
    echo "• 1 x OCI Compute Instance (VM.Standard.A1.Flex)"
    echo "• 1 x Boot Volume (50GB, 10 VPUs)"
    echo "• 1 x VNIC with public IP"
    echo "• Agent plugins configured as specified"
    echo "• ARM-based processor (Ampere Altra)"
    echo ""
}

# Function to generate random delay between retries
get_random_delay() {
    echo $((RANDOM % (MAX_RETRY_DELAY - MIN_RETRY_DELAY + 1) + MIN_RETRY_DELAY))
}

# Function to get SSH public key content
get_ssh_public_key() {
    local ssh_key_path="${SSH_PUBLIC_KEY_PATH:-~/.ssh/id_rsa.pub}"
    
    # Expand tilde to home directory
    ssh_key_path="${ssh_key_path/#\~/$HOME}"
    
    if [ -f "$ssh_key_path" ]; then
        cat "$ssh_key_path"
    else
        log_error "SSH public key not found at: $ssh_key_path"
        log "💡 Create SSH key with: ssh-keygen -t rsa -b 4096"
        log "💡 Or update SSH_PUBLIC_KEY_PATH in .env file"
        exit 1
    fi
}

# Function to attempt deployment
attempt_deployment() {
    local ad="$1"
    local subnet_id="$2"
    local instance_name="${INSTANCE_NAME_PREFIX:-a1-flex-instance}-${TIMESTAMP}-$(echo $ad | cut -d'-' -f3)"
    local compartment_id="${OCI_COMPARTMENT_ID}"
    
    if [ -z "$compartment_id" ]; then
        log_error "OCI_COMPARTMENT_ID not configured in .env file. Please add your compartment OCID."
        exit 1
    fi
    local ssh_public_key=$(get_ssh_public_key)
    
    log "Attempting A1.Flex deployment with:"
    log "  - Availability Domain: $ad"
    log "  - Instance Shape: $TARGET_SHAPE"
    log "  - OCPUs: $TARGET_OCPUS"
    log "  - Memory: ${TARGET_MEMORY}GB"
    log "  - Instance Name: $instance_name"
    log "  - Compartment: $(echo $compartment_id | cut -c1-20)..."
    log "  - SSH Key: From ${SSH_PUBLIC_KEY_PATH:-~/.ssh/id_rsa.pub}"
    log "  - Always Free Tier: YES ✅"
    
    # Initialize Terraform if needed
    if [ ! -d ".terraform" ]; then
        log "Initializing Terraform..."
        terraform init
    fi
    
    # Plan the deployment
    log "Planning A1.Flex deployment..."
    terraform plan \
        -var="availability_domain=$ad" \
        -var="instance_shape=$TARGET_SHAPE" \
        -var="subnet_id=$subnet_id" \
        -var="instance_name=$instance_name" \
        -var="compartment_id=$compartment_id" \
        -var="ssh_public_key=$ssh_public_key" \
        -var="ocpus=$TARGET_OCPUS" \
        -var="memory_gb=$TARGET_MEMORY" \
        -out=tfplan
    
    # If dry run, stop here
    if [ "$DRY_RUN" = true ]; then
        log_success "DRY RUN: Plan completed successfully!"
        log "In a real deployment, this would now apply the changes."
        
        # Test notification for dry run
        send_notification "OCI Dry Run Success" "Terraform plan completed successfully!" "Glass"
        play_notification
        
        return 0
    fi
    
    # Apply the deployment
    log "Applying deployment..."
    terraform apply -auto-approve tfplan 2>&1 | tee terraform_apply.log
    
    local terraform_exit_code=${PIPESTATUS[0]}
    
    if [ $terraform_exit_code -eq 0 ]; then
        log_success "Deployment successful!"
        
        # Get outputs
        log "Instance details:"
        terraform output
        
        # Send success notification
        send_notification "OCI Deployment Success" "Instance $instance_name created successfully!" "Glass"
        play_notification
        
        # Clean up log file on success
        rm -f terraform_apply.log
        
        return 0
    else
        log_error "Deployment failed (Terraform exit code: $terraform_exit_code)"
        
        # Check for specific error patterns
        if grep -q "InternalError\|Out of host capacity\|500" terraform_apply.log; then
            log_warning "🎯 Detected capacity issue - this is the expected error when A1.Flex is unavailable"
            log_warning "   Error details: InternalError (500) = Out of host capacity"
        elif grep -q "LimitExceeded" terraform_apply.log; then
            log_error "❌ Service limit exceeded - you may already have A1.Flex instances"
            log "💡 Check your OCI console for existing instances"
        else
            log_error "❌ Unexpected error occurred. Check terraform_apply.log for details"
        fi
        
        return 1
    fi
}

# Function to cleanup failed attempts
cleanup_failed_attempt() {
    log "Cleaning up failed deployment attempt..."
    terraform destroy -auto-approve 2>/dev/null || true
    rm -f tfplan 2>/dev/null || true
    rm -f terraform_apply.log 2>/dev/null || true
}

# Main deployment logic - infinite retry for A1.Flex only
main() {
    log "Starting OCI A1.Flex deployment with infinite retry logic..."
    log "Target: $TARGET_SHAPE with $TARGET_OCPUS OCPUs and ${TARGET_MEMORY}GB RAM"
    log "Strategy: Keep trying until A1.Flex capacity becomes available"
    log "Log file: $LOG_FILE"
    
    check_prerequisites
    
    local attempt=1
    local success=false
    
    # Infinite retry loop - keep trying until A1.Flex is available
    while [ "$success" = false ]; do
        log "🔄 A1.Flex deployment attempt #$attempt"
        
        # Try each availability domain for A1.Flex
        for ad in "${AVAILABILITY_DOMAINS[@]}"; do
            if [ "$success" = true ]; then
                break
            fi
            
            local subnet_id=$(get_available_subnets "$ad")
            
            log "🎯 Trying A1.Flex in AD: $ad"
            
            if attempt_deployment "$ad" "$subnet_id"; then
                success=true
                log_success "🎉 A1.Flex instance successfully created!"
                break
            else
                log_warning "❌ A1.Flex not available in AD: $ad"
                log_warning "   Common reasons: Out of host capacity, InternalError (500)"
                log_warning "   This is expected - OCI A1.Flex has very limited capacity"
                cleanup_failed_attempt
            fi
        done
        
        if [ "$success" = false ]; then
            local delay=$(get_random_delay)
            attempt=$((attempt + 1))
            log_warning "⏳ A1.Flex capacity not available. Waiting $delay seconds before retry #$attempt..."
            log "💡 Tip: A1.Flex capacity often becomes available during off-peak hours (late evening/early morning UTC)"
            log "💡 The 'InternalError' 500 response is OCI's way of saying 'out of capacity'"
            log "💡 This script will keep trying - A1.Flex instances ARE available, just very limited"
            sleep $delay
        fi
    done
    
    log_success "🚀 A1.Flex deployment completed successfully!"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  -h, --help      Show this help message"
    echo "  -d, --dry-run   Perform a dry run (plan only, no deployment)"
    echo "  -t, --test      Test notification system"
    echo "  -p, --preview   Show detailed deployment preview"
    echo "  -l, --logs      Show deployment logs"
    echo "  -c, --clean     Clean up Terraform state and files"
    echo ""
    echo "EXAMPLES:"
    echo "  $0                    # Deploy A1.Flex with infinite retry"
    echo "  $0 --dry-run          # Test the A1.Flex deployment plan"
    echo "  $0 --test             # Test notifications"
    echo "  $0 --preview          # Show A1.Flex deployment details"
    echo ""
    echo "This script will CONTINUOUSLY attempt to deploy an A1.Flex instance"
    echo "until capacity becomes available. NO ALTERNATIVES, NO GIVING UP!"
    echo "🎯 TARGET: VM.Standard.A1.Flex (4 OCPUs, 24GB RAM)"
    echo "⚠️  ALWAYS FREE TIER ONLY - No unexpected charges!"
}

# Function to show logs
show_logs() {
    if [ -f "$LOG_FILE" ]; then
        cat "$LOG_FILE"
    else
        echo "No log file found."
    fi
}

# Function to clean up
cleanup() {
    log "Cleaning up Terraform files..."
    rm -rf .terraform*
    rm -f tfplan
    rm -f terraform.tfstate*
    rm -f terraform_apply.log
    log_success "Cleanup completed!"
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_usage
        exit 0
        ;;
    -d|--dry-run)
        DRY_RUN=true
        log_warning "DRY RUN MODE: No resources will be created"
        main
        ;;
    -t|--test)
        test_notifications
        exit $?
        ;;
    -p|--preview)
        # For preview, only check Terraform (OCI CLI not needed for plan)
        if ! command -v terraform >/dev/null 2>&1; then
            log_error "Terraform is not installed. Please install Terraform first."
            exit 1
        fi
        
        # Show preview for A1.Flex configuration
        AD="${AVAILABILITY_DOMAINS[0]}"
        SUBNET_ID=$(get_available_subnets "$AD")
        show_deployment_preview "$AD" "$SUBNET_ID"
        exit 0
        ;;
    -l|--logs)
        show_logs
        exit 0
        ;;
    -c|--clean)
        cleanup
        exit 0
        ;;
    "")
        main
        ;;
    *)
        echo "Unknown option: $1"
        show_usage
        exit 1
        ;;
esac 