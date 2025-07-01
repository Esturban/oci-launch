#!/bin/bash

# Install OCI CLI on macOS
echo "Installing OCI CLI..."

# Install using bash installer
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"

# Add to PATH (add this to your ~/.zshrc as well)
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc

echo "OCI CLI installation complete!"
echo "Please restart your terminal or run: source ~/.zshrc"
echo "Then run: oci setup config to configure your credentials" 