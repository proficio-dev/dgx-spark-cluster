#!/bin/bash
# Set up passwordless sudo for user 'neo' on a remote machine
# Usage: ./setup_sudo.sh <ssh_target>
# Example: ./setup_sudo.sh neo@192.168.85.101
set -e

SSH_TARGET="${1:?Usage: $0 <ssh_target>}"

echo "Setting up passwordless sudo on $SSH_TARGET..."
ssh -o ConnectTimeout=10 "$SSH_TARGET" \
    'echo "neo ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/neo-nopasswd > /dev/null && sudo chmod 440 /etc/sudoers.d/neo-nopasswd && echo "DONE"'
echo "Passwordless sudo configured on $SSH_TARGET"
