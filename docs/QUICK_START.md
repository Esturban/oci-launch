# Quick Start - Testing Before Deployment

## 🎯 Step-by-Step Testing (Recommended)

### 1. Setup Environment & OCI CLI
```bash
# Setup secure environment variables
cp env.example .env
# Edit .env with your actual OCI settings

# Install and configure OCI CLI
./install-oci-cli.sh
oci setup config  # Follow the detailed guide in README.md
```

### 2. Test Notifications First
```bash
./deploy-oci-instance.sh --test
```
**What this does:**
- Tests desktop notifications
- Tests sound alerts
- Tests voice announcements
- Confirms your system can notify you when deployment completes

### 3. Preview Your Deployment
```bash
./deploy-oci-instance.sh --preview
```
**What you'll see:**
- Exact instance specifications
- Resource details (OCPUs, memory, storage)
- Cost confirmation (Always Free Tier)
- Terraform plan output

### 4. Dry Run (Test Everything)
```bash
./deploy-oci-instance.sh --dry-run
```
**What this does:**
- Runs the complete deployment process
- Creates Terraform plans
- Tests retry logic
- Tests notifications
- **DOES NOT** create any actual resources
- Shows you exactly what would happen

### 5. Real Deployment (When Ready)
```bash
./deploy-oci-instance.sh
```

## 🛡️ Always Free Tier Protection

The script is locked to Always Free tier only:
- **VM.Standard.A1.Flex**: 4 OCPUs, 24GB RAM (ARM)
- **VM.Standard.E2.1.Micro**: 1/8 OCPU, 1GB RAM (x86)

**No unexpected charges possible!**

## 🔧 Command Reference

| Command | Purpose |
|---------|---------|
| `--test` | Test notification system |
| `--preview` | Show deployment details |
| `--dry-run` | Full test without creating resources |
| `--logs` | View deployment history |
| `--clean` | Clean up Terraform files |
| `--help` | Show all options |

## 🎉 Success Indicators

When everything works:
- ✅ Desktop notification appears
- 🔊 Sound plays (Glass sound for success)
- 🗣️ Voice announcement
- 📝 Detailed logs in `deployment.log`
- 🎯 Instance details displayed 