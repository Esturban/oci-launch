# OCI A1.Flex Deployment with Infinite Retry

This toolkit is laser-focused on deploying Oracle Cloud Infrastructure (OCI) A1.Flex instances with infinite retry logic. It continuously attempts to deploy A1.Flex until capacity becomes available - NO alternatives, NO giving up!

## Features

- 🎯 **A1.Flex Only**: Exclusively targets VM.Standard.A1.Flex (4 OCPUs, 24GB RAM)
- ♾️ **Infinite Retry**: Never gives up until A1.Flex capacity becomes available
- 🎲 **Random Delays**: 60-300 second random waits between attempts to avoid patterns
- 🔔 **Desktop Notifications**: Get notified when A1.Flex is finally deployed (macOS)
- 📊 **Resource Discovery**: Find available availability domains for A1.Flex
- 📝 **Detailed Logging**: Track all A1.Flex deployment attempts with timestamps
- 🧹 **Easy Cleanup**: Clean up failed deployments automatically

## Prerequisites

1. **Terraform** - [Download here](https://terraform.io/downloads)
2. **OCI CLI** - We'll install this for you
3. **OCI Account** with proper permissions
4. **macOS** (for notifications - script works on other systems too)

## Quick Start

### 1. Easy Setup (Recommended)

```bash
./setup.sh
```

This creates your `.env` file and guides you through the configuration.

### 2. Manual Setup (Alternative)

```bash
# Install OCI CLI
./install-oci-cli.sh

# Setup environment variables
cp env.example .env
# Edit .env with your actual values
```

**Required variables in .env:**
- `OCI_COMPARTMENT_ID` - Your compartment OCID
- `OCI_SUBNET_ID` - Your subnet OCID  
- `SSH_PUBLIC_KEY_PATH` - Path to your SSH public key (e.g., `~/.ssh/id_rsa.pub`)

### 3. Configure OCI CLI

```bash
oci setup config
```

#### Detailed Authentication Setup:

1. **Get your User OCID:**
   - Login to [OCI Console](https://cloud.oracle.com)
   - Click your profile icon (top right) → **User Settings**
   - Copy the **OCID** (starts with `ocid1.user.oc1..`)

2. **Get your Tenancy OCID:**
   - In OCI Console, click profile icon → **Tenancy: [Your Tenancy Name]**
   - Copy the **OCID** (starts with `ocid1.tenancy.oc1..`)

3. **Choose your Region:**
   - Use the region code where your resources are located
   - Examples: `ca-toronto-1`, `us-ashburn-1`, `eu-frankfurt-1`

4. **Generate API Key:**
   - In User Settings, click **API Keys** → **Add API Key**
   - Choose **Generate API Key Pair**
   - Download both the private key (`.pem`) and public key
   - Save the private key to `~/.oci/oci_api_key.pem`
   - Copy the Configuration File Preview (you'll need this)

5. **Complete the setup:**
   - The `oci setup config` command will ask for:
     - User OCID (from step 1)
     - Tenancy OCID (from step 2)
     - Region (from step 3)
     - Path to private key (e.g., `/Users/yourusername/.oci/oci_api_key.pem`)

6. **Test the configuration:**
   ```bash
   oci iam region list
   ```
   If this works, you're authenticated correctly!

### 4. Discover Available Resources (Optional)

```bash
chmod +x src/get-availability-domains.sh
./get-availability-domains.sh
```

This shows available availability domains and instance shapes in your region.

### 5. Test and Deploy

#### 5a. Test Notifications (Recommended)
```bash
./deploy-oci-instance.sh --test
```
This ensures notifications work before deployment.

#### 5b. Preview Deployment (Recommended)
```bash
./deploy-oci-instance.sh --preview
```
Shows exactly what resources will be created.

#### 5c. Dry Run (Recommended)
```bash
./deploy-oci-instance.sh --dry-run
```
Tests the entire deployment process without creating resources.

#### 5d. Full Deployment - Get that A1.Flex!
```bash
./deploy-oci-instance.sh
```

The script will:
- ✅ Check prerequisites and load secure environment variables
- 🎯 Target ONLY A1.Flex instances (4 OCPUs, 24GB RAM)
- ♾️ Retry infinitely across availability domains until success
- 🎲 Use random delays (60-300 seconds) between attempts
- 📝 Log all A1.Flex deployment attempts
- 🔔 Notify you when A1.Flex is finally deployed
- 🛑 **STOP immediately once A1.Flex is successfully created**

## Configuration

### Customizing Availability Domains

Edit `deploy-oci-instance.sh` and update the `AVAILABILITY_DOMAINS` array:

```bash
AVAILABILITY_DOMAINS=(
    "mUFn:CA-TORONTO-1-AD-1"
    "mUFn:CA-TORONTO-1-AD-2"
    "mUFn:CA-TORONTO-1-AD-3"
)
```

### A1.Flex Target Configuration

The script is configured to deploy **ONLY A1.Flex instances**:

```bash
TARGET_SHAPE="VM.Standard.A1.Flex"    # Always Free: 4 OCPUs, 24GB RAM
TARGET_OCPUS="4"
TARGET_MEMORY="24"
```

**🎯 A1.FLEX SPECIFICATIONS**: 
- **Shape**: VM.Standard.A1.Flex (ARM-based Ampere Altra)
- **OCPUs**: 4 (Always Free tier maximum)
- **Memory**: 24GB (Always Free tier maximum)
- **Cost**: FREE (Always Free tier eligible)
- **Strategy**: Infinite retry until capacity available

### Updating Variables

Modify `variables.tf` to change default values:

```hcl
variable "compartment_id" {
  default = "your-compartment-ocid-here"
}

variable "subnet_id" {
  default = "your-subnet-ocid-here"
}
```

## Script Options

```bash
# Deploy with retry logic
./deploy-oci-instance.sh

# Test notifications first (RECOMMENDED)
./deploy-oci-instance.sh --test

# Preview what will be deployed (RECOMMENDED)
./deploy-oci-instance.sh --preview

# Dry run - test without creating resources (RECOMMENDED)
./deploy-oci-instance.sh --dry-run

# Show help
./deploy-oci-instance.sh --help

# View deployment logs
./deploy-oci-instance.sh --logs

# Clean up Terraform files
./deploy-oci-instance.sh --clean
```

## Troubleshooting

### "Host out of capacity" errors
- ✅ Script automatically tries different availability domains
- ✅ Try different instance shapes (A1.Flex often has better availability)
- ✅ Run during off-peak hours
- ✅ Use the resource discovery script to find alternatives

### OCI CLI not configured
```bash
oci setup config
```

### Terraform not found
```bash
# macOS with Homebrew
brew install terraform

# Or download from https://terraform.io/downloads
```

### Permission errors
- Ensure your OCI user has permissions to create instances
- Check that your API key is properly configured
- Verify compartment and subnet OCIDs are correct

## Files

- `main.tf` - Main Terraform configuration
- `variables.tf` - Variable definitions
- `outputs.tf` - Output definitions
- `deploy-oci-instance.sh` - Main deployment script
- `install-oci-cli.sh` - OCI CLI installation script
- `get-availability-domains.sh` - Resource discovery script
- `deployment.log` - Deployment logs (created automatically)

## Notifications

The script includes macOS desktop notifications:
- 🎉 **Success**: Glass sound + desktop notification
- ❌ **Failure**: Basso sound + desktop notification
- 🗣️ **Voice**: Text-to-speech announcement

## Success Tips

1. **ARM instances** (A1.Flex) often have better availability than x86
2. **Try different times** - off-peak hours may have more capacity
3. **Multiple regions** - consider other regions if Toronto is full
4. **Smaller instances** - start with smaller shapes and resize later
5. **Free tier** - E2.1.Micro instances are free tier eligible

## Support

If you encounter issues:
1. Check `deployment.log` for detailed error messages
2. Run `./get-availability-domains.sh` to see what's available
3. Try different instance shapes or availability domains
4. Consider using a different region

## License

This toolkit is provided as-is for educational and development purposes. 