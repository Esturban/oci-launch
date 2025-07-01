#!/bin/bash

# Unified A1.Flex Capacity Monitor
# Combines all monitoring approaches with proper logging and workspace management
# Author: Esturban
# Version: 1.0

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"
LOGS_DIR="$WORKSPACE_DIR/logs"
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
LOG_FILE="$LOGS_DIR/a1-monitor-$TIMESTAMP.log"

# Monitoring settings
CHECK_INTERVAL=${CHECK_INTERVAL:-240}  # Default 4 minutes
PLAN_TIMEOUT=30
APPLY_TIMEOUT=45
MAX_ATTEMPTS=3

# Monitoring modes
MODE_QUICK="quick"        # Just quota + plan check
MODE_ROBUST="robust"      # Plan + validation checks  
MODE_ULTIMATE="ultimate"  # Real terraform apply tests
MODE_CONTINUOUS="monitor" # Continuous monitoring

# Default mode
MONITOR_MODE="${MONITOR_MODE:-robust}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Ensure logs directory exists
mkdir -p "$LOGS_DIR"

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS:${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
}

log_debug() {
    echo -e "${PURPLE}[$(date '+%Y-%m-%d %H:%M:%S')] DEBUG:${NC} $1" | tee -a "$LOG_FILE"
}

log_critical() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')] CRITICAL:${NC} $1" | tee -a "$LOG_FILE"
}

# Enhanced notifications
send_notification() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"  # normal, urgent, critical
    
    # Desktop notification
    if command -v osascript >/dev/null 2>&1; then
        local sound="Glass"
        case "$urgency" in
            urgent) sound="Sosumi" ;;
            critical) sound="Sosumi" ;;
        esac
        osascript -e "display notification \"$message\" with title \"$title\" sound name \"$sound\""
    fi
    
    # Audio alerts
    if command -v afplay >/dev/null 2>&1; then
        case "$urgency" in
            normal)
                afplay /System/Library/Sounds/Glass.aiff >/dev/null 2>&1 &
                ;;
            urgent)
                afplay /System/Library/Sounds/Sosumi.aiff >/dev/null 2>&1 &
                ;;
            critical)
                # Triple alert for critical
                for i in {1..3}; do
                    afplay /System/Library/Sounds/Sosumi.aiff >/dev/null 2>&1 &
                    sleep 0.3
                done
                ;;
        esac
    fi
    
    # Voice alerts
    if command -v say >/dev/null 2>&1; then
        case "$urgency" in
            normal) say "A1 Flex notification: $message" >/dev/null 2>&1 & ;;
            urgent) say -v "Samantha" -r 180 "Alert: $message" >/dev/null 2>&1 & ;;
            critical) say -v "Samantha" -r 200 "URGENT: $message" >/dev/null 2>&1 & ;;
        esac
    fi
}

# Load environment configuration
load_config() {
    local env_file="$WORKSPACE_DIR/.env"
    if [ -f "$env_file" ]; then
        export $(grep -v '^#' "$env_file" | xargs)
        log_success "✅ Configuration loaded from .env"
    else
        log_error "❌ No .env file found in workspace directory"
        log "💡 Please create .env file with your OCI configuration"
        exit 1
    fi
}

# Validate prerequisites
check_prerequisites() {
    log_debug "🔍 Checking prerequisites..."
    
    local missing_tools=()
    
    # Check required tools
    if ! command -v terraform >/dev/null 2>&1; then
        missing_tools+=("terraform")
    fi
    
    if ! command -v oci >/dev/null 2>&1; then
        missing_tools+=("oci")
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        missing_tools+=("jq")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "❌ Missing required tools: ${missing_tools[*]}"
        exit 1
    fi
    
    # Check OCI CLI configuration
    if ! oci iam region list >/dev/null 2>&1; then
        log_error "❌ OCI CLI not configured. Run 'oci setup config' first."
        exit 1
    fi
    
    # Check required environment variables
    local required_vars=("OCI_COMPARTMENT_ID" "OCI_SUBNET_ID")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_error "❌ Missing required environment variables: ${missing_vars[*]}"
        exit 1
    fi
    
    log_success "✅ Prerequisites check passed"
}

# Quick capacity check (quota + basic validation)
quick_capacity_check() {
    local compartment_id="$1"
    local ad="$2"
    
    log_debug "⚡ Quick capacity check..."
    
    # Check quota
    local quota_info
    if ! quota_info=$(oci limits resource-availability get \
        --service-name compute \
        --limit-name standard-a1-core-count \
        --compartment-id "$compartment_id" \
        --availability-domain "$ad" 2>/dev/null); then
        log_error "Failed to check quota"
        return 1
    fi
    
    local available=$(echo "$quota_info" | jq -r '.data.available' 2>/dev/null || echo "0")
    local used=$(echo "$quota_info" | jq -r '.data.used' 2>/dev/null || echo "0")
    
    log_debug "  Quota - Available: $available cores, Used: $used cores"
    
    if [ "$available" -lt 4 ]; then
        log_warning "❌ Insufficient quota: only $available cores available"
        return 1
    fi
    
    log_debug "✅ Quick check passed"
    return 0
}

# Robust capacity check (plan-based validation)
robust_capacity_check() {
    local compartment_id="$1"
    local ad="$2"
    local subnet_id="$3"
    local test_name="plan-probe-$(date +%s)"
    
    log_debug "🔬 Robust capacity check (plan-based)..."
    
    # Quick check first
    if ! quick_capacity_check "$compartment_id" "$ad"; then
        return 1
    fi
    
    # Create test workspace
    local test_dir="$WORKSPACE_DIR/logs/plan-test-$$"
    mkdir -p "$test_dir"
    cd "$test_dir"
    
    # Copy Terraform files
    cp "$WORKSPACE_DIR"/*.tf . 2>/dev/null || true
    
    # Initialize
    if ! terraform init -input=false >/dev/null 2>&1; then
        log_error "Failed to initialize Terraform for plan test"
        cd "$WORKSPACE_DIR"
        rm -rf "$test_dir"
        return 1
    fi
    
    # Test plan
    local plan_output
    local plan_result=1
    
    if plan_output=$(timeout $PLAN_TIMEOUT terraform plan \
        -var="availability_domain=$ad" \
        -var="instance_shape=VM.Standard.A1.Flex" \
        -var="subnet_id=$subnet_id" \
        -var="instance_name=$test_name" \
        -var="compartment_id=$compartment_id" \
        -var="ssh_public_key=ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC dummy-key" \
        -var="ocpus=4" \
        -var="memory_gb=24" \
        -refresh=true \
        -no-color \
        -input=false 2>&1); then
        
        # Check for capacity issues in plan output
        if echo "$plan_output" | grep -qi "out of host capacity\|capacity.*not.*available\|insufficient capacity"; then
            log_debug "❌ Plan succeeded but found capacity issues"
            plan_result=1
        else
            log_debug "✅ Plan succeeded with no capacity errors"
            plan_result=0
        fi
    else
        log_debug "❌ Plan failed or timed out"
        plan_result=1
    fi
    
    # Cleanup
    cd "$WORKSPACE_DIR"
    rm -rf "$test_dir"
    
    return $plan_result
}

# Ultimate capacity check (real apply test)
ultimate_capacity_check() {
    local compartment_id="$1"
    local ad="$2"
    local subnet_id="$3"
    local test_name="apply-probe-$(date +%s)-$$"
    
    log_debug "🚀 Ultimate capacity check (real apply test)..."
    
    # Robust check first
    if ! robust_capacity_check "$compartment_id" "$ad" "$subnet_id"; then
        log_debug "❌ Robust check failed, skipping apply test"
        return 1
    fi
    
    # Create test workspace
    local test_dir="$WORKSPACE_DIR/logs/apply-test-$$"
    mkdir -p "$test_dir"
    cd "$test_dir"
    
    # Copy Terraform files
    cp "$WORKSPACE_DIR"/*.tf . 2>/dev/null || true
    
    # Initialize
    if ! terraform init -input=false >/dev/null 2>&1; then
        log_error "Failed to initialize Terraform for apply test"
        cd "$WORKSPACE_DIR"
        rm -rf "$test_dir"
        return 1
    fi
    
    log_debug "🎯 Attempting real terraform apply..."
    
    # Attempt real apply
    local apply_output
    local apply_result=1
    
    if apply_output=$(timeout $APPLY_TIMEOUT terraform apply \
        -var="availability_domain=$ad" \
        -var="instance_shape=VM.Standard.A1.Flex" \
        -var="subnet_id=$subnet_id" \
        -var="instance_name=$test_name" \
        -var="compartment_id=$compartment_id" \
        -var="ssh_public_key=ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC dummy-key" \
        -var="ocpus=4" \
        -var="memory_gb=24" \
        -auto-approve \
        -no-color \
        -input=false 2>&1); then
        
        log_debug "✅ APPLY SUCCEEDED! Real capacity confirmed!"
        apply_result=0
        
        # Immediate cleanup
        log_debug "🧹 Destroying test instance..."
        terraform destroy -auto-approve -no-color >/dev/null 2>&1 || {
            log_warning "⚠️  Manual cleanup needed for test instance: $test_name"
        }
        
    else
        if echo "$apply_output" | grep -qi "out of host capacity"; then
            log_debug "❌ Apply failed with capacity error (expected)"
        else
            log_debug "❌ Apply failed with other error"
        fi
        apply_result=1
    fi
    
    # Cleanup
    cd "$WORKSPACE_DIR"
    rm -rf "$test_dir"
    
    return $apply_result
}

# Main capacity validation dispatcher
check_capacity() {
    local mode="$1"
    local compartment_id="$OCI_COMPARTMENT_ID"
    local ad="mUFn:CA-TORONTO-1-AD-1"
    local subnet_id="$OCI_SUBNET_ID"
    
    case "$mode" in
        "$MODE_QUICK")
            quick_capacity_check "$compartment_id" "$ad"
            ;;
        "$MODE_ROBUST")
            robust_capacity_check "$compartment_id" "$ad" "$subnet_id"
            ;;
        "$MODE_ULTIMATE")
            ultimate_capacity_check "$compartment_id" "$ad" "$subnet_id"
            ;;
        *)
            log_error "Unknown capacity check mode: $mode"
            return 1
            ;;
    esac
}

# Continuous monitoring loop
continuous_monitor() {
    local mode="$1"
    local check_count=1
    
    log "🚀 Starting continuous A1.Flex monitoring..."
    log "🎯 Mode: $mode"
    log "📍 Region: CA-TORONTO-1"
    log "🏢 Availability Domain: mUFn:CA-TORONTO-1-AD-1"
    log "⏱️  Check interval: $CHECK_INTERVAL seconds"
    log "📝 Log file: $LOG_FILE"
    
    # Initialize Terraform in workspace
    cd "$WORKSPACE_DIR"
    if [ ! -d ".terraform" ]; then
        log "Initializing Terraform in workspace..."
        terraform init -input=false
    fi
    
    while true; do
        log "🔄 Capacity check #$check_count ($mode mode)"
        
        if check_capacity "$mode"; then
            local urgency_level="critical"
            case "$mode" in
                "$MODE_QUICK") urgency_level="normal" ;;
                "$MODE_ROBUST") urgency_level="urgent" ;;
                "$MODE_ULTIMATE") urgency_level="critical" ;;
            esac
            
            log_critical "🎉 A1.FLEX CAPACITY DETECTED!"
            log_critical "Validation mode: $mode"
            
            # Send notification
            send_notification "A1.Flex Available!" "Capacity detected via $mode mode - deploy now!" "$urgency_level"
            
            # Auto-deployment prompt
            echo ""
            echo "🚨 A1.Flex capacity detected via $mode validation!"
            echo "🚀 Start deployment immediately? (y/n) [30s timeout]"
            
            if read -t 30 -r response && [[ "$response" =~ ^[Yy]$ ]]; then
                log_critical "🚀 Starting deployment..."
                exec "$WORKSPACE_DIR/deploy-oci-instance.sh"
            else
                log_critical "💡 Manual deployment: ./deploy-oci-instance.sh"
                log_critical "⚠️  Capacity may disappear quickly!"
                exit 0
            fi
        else
            check_count=$((check_count + 1))
            log_warning "❌ No capacity available (check #$check_count)"
            
            # Encouragement messages
            if [ $((check_count % 10)) -eq 0 ]; then
                log "💪 Still monitoring... A1.Flex capacity will appear!"
            fi
        fi
        
        log "⏳ Waiting $CHECK_INTERVAL seconds until next check..."
        sleep $CHECK_INTERVAL
    done
}

# Show monitoring status and recommendations
show_status() {
    echo -e "${BOLD}A1.Flex Capacity Monitor Status${NC}"
    echo "==============================="
    echo ""
    echo "📂 Workspace: $WORKSPACE_DIR"
    echo "📝 Logs directory: $LOGS_DIR"
    echo "🔧 Current log: $LOG_FILE"
    echo ""
    echo "🎯 Available monitoring modes:"
    echo "  • quick    - Fast quota check (may have false positives)"
    echo "  • robust   - Plan-based validation (good balance)"
    echo "  • ultimate - Real apply tests (100% accurate, slower)"
    echo ""
    echo "📊 Recent log files:"
    ls -la "$LOGS_DIR"/a1-monitor-*.log 2>/dev/null | tail -5 || echo "  No logs found"
    echo ""
}

# Cleanup old logs
cleanup_logs() {
    local days_to_keep="${1:-7}"
    log "🧹 Cleaning up logs older than $days_to_keep days..."
    
    find "$LOGS_DIR" -name "a1-monitor-*.log" -mtime +$days_to_keep -delete 2>/dev/null || true
    find "$LOGS_DIR" -name "*test*" -type d -mtime +1 -exec rm -rf {} + 2>/dev/null || true
    
    log_success "✅ Log cleanup completed"
}

# Show usage information
show_usage() {
    echo "Unified A1.Flex Capacity Monitor"
    echo "================================"
    echo ""
    echo "USAGE: $0 [MODE] [OPTIONS]"
    echo ""
    echo "MODES:"
    echo "  quick              Fast quota-only check"
    echo "  robust             Plan-based validation (default)"
    echo "  ultimate           Real apply tests (most accurate)"
    echo "  monitor [mode]     Continuous monitoring"
    echo ""
    echo "OPTIONS:"
    echo "  -h, --help         Show this help"
    echo "  -s, --status       Show monitoring status"
    echo "  -i, --interval N   Set check interval (seconds)"
    echo "  -c, --cleanup [N]  Clean logs older than N days (default: 7)"
    echo ""
    echo "EXAMPLES:"
    echo "  $0 quick                    # Quick one-time check"
    echo "  $0 robust                  # Robust one-time check"
    echo "  $0 ultimate                # Ultimate accuracy check"
    echo "  $0 monitor robust          # Continuous robust monitoring"
    echo "  $0 monitor ultimate -i 120 # Ultimate monitoring every 2 minutes"
    echo "  $0 --status                # Show status and logs"
    echo "  $0 --cleanup 3             # Clean logs older than 3 days"
    echo ""
    echo "📝 All logs are saved to: $LOGS_DIR/"
    echo "🎯 Recommended: Use 'robust' mode for balanced accuracy and speed"
}

# Main execution logic
main() {
    # Parse arguments
    local mode="$MONITOR_MODE"
    local action="check"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            quick|robust|ultimate)
                mode="$1"
                shift
                ;;
            monitor)
                action="monitor"
                shift
                if [[ $# -gt 0 && "$1" =~ ^(quick|robust|ultimate)$ ]]; then
                    mode="$1"
                    shift
                fi
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -s|--status)
                show_status
                exit 0
                ;;
            -i|--interval)
                CHECK_INTERVAL="$2"
                shift 2
                ;;
            -c|--cleanup)
                cleanup_logs "$2"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Initialize
    load_config
    check_prerequisites
    
    log "🚀 A1.Flex Capacity Monitor starting..."
    log "📂 Workspace: $WORKSPACE_DIR"
    log "📝 Logging to: $LOG_FILE"
    
    # Execute based on action
    case "$action" in
        check)
            log "🔍 Single capacity check ($mode mode)"
            if check_capacity "$mode"; then
                log_success "✅ Capacity detected!"
                send_notification "A1.Flex Available!" "Capacity confirmed via $mode check"
                echo ""
                echo "🎉 A1.Flex capacity is available!"
                echo "🚀 Run ./deploy-oci-instance.sh to deploy"
                exit 0
            else
                log_warning "❌ No capacity available"
                echo ""
                echo "❌ No A1.Flex capacity currently available"
                echo "💡 Try running: $0 monitor $mode"
                exit 1
            fi
            ;;
        monitor)
            continuous_monitor "$mode"
            ;;
        *)
            log_error "Unknown action: $action"
            exit 1
            ;;
    esac
}

# Entry point
main "$@" 