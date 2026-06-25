#!/usr/bin/env bash
# ==============================================================================
# Fedora Post-Install Setup Bootstrapper
# ==============================================================================
# This script installs DNF pre-requisites (git and ansible), clones the setup
# repository, and executes the Ansible playbook locally.
# ==============================================================================
set -euo pipefail

# Ensure DNF is available (sanity check for Fedora target)
if ! command -v dnf &> /dev/null; then
    echo "Error: This script must be run on a Fedora Linux system (DNF not found)."
    exit 1
fi

echo "--> Updating DNF and installing prerequisites (git, ansible)..."
sudo dnf install -y git ansible

# Create a temporary directory for repository download
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "--> Cloning the setup repository..."
git clone https://github.com/roguehunter7/fedora-setup-ansible.git "$TEMP_DIR"

# Move to clone directory
cd "$TEMP_DIR"

echo "--> Starting Ansible playbook execution..."
ansible-playbook playbook.yml --ask-become-pass

echo "--> Setup complete! Please log out and back in (or restart your terminal) to activate Zsh."
