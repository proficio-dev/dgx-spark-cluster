#!/bin/bash
# Quick setup: run all steps to bring up a new DGX Spark node
# Run FROM Spark (the control node) to configure a remote machine
#
# Prerequisites:
#   - SSH key access to the target machine (ssh-copy-id first)
#   - Target machine has ConnectX-7 NICs
#
# Usage: ./setup_node.sh <ssh_target> <host_octet> <mgmt_ip>
# Example: ./setup_node.sh neo@192.168.85.101 2 192.168.85.101
set -e

SSH_TARGET="${1:?Usage: $0 <ssh_target> <host_octet> <mgmt_ip>}"
HOST_OCTET="${2:?Usage: $0 <ssh_target> <host_octet> <mgmt_ip>}"
MGMT_IP="${3:?Usage: $0 <ssh_target> <host_octet> <mgmt_ip>}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "========================================"
echo " Full Node Setup: $SSH_TARGET"
echo " Host octet: $HOST_OCTET"
echo " Management IP: $MGMT_IP"
echo "========================================"

# Step 1: Passwordless sudo
echo ""
echo "[1/3] Setting up passwordless sudo..."
bash "$SCRIPT_DIR/setup_sudo.sh" "$SSH_TARGET"

# Step 2: Generate SSH key if needed
echo ""
echo "[2/3] Ensuring SSH key exists..."
ssh -o ConnectTimeout=10 "$SSH_TARGET" '
    if [[ ! -f ~/.ssh/id_ed25519 ]]; then
        ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -q
        echo "Generated new ed25519 key"
    else
        echo "Key already exists"
    fi
    cat ~/.ssh/id_ed25519.pub
'

# Step 3: Deploy RoCE setup
echo ""
echo "[3/3] Deploying RoCE configuration..."
bash "$SCRIPT_DIR/deploy_roce.sh" "$SSH_TARGET" "$HOST_OCTET"

echo ""
echo "========================================"
echo " Node setup launched for $SSH_TARGET"
echo " Wait ~10s then verify with:"
echo "   ssh $SSH_TARGET 'cat /tmp/roce_out.log'"
echo "   ping -c1 10.0.1.${HOST_OCTET}"
echo "========================================"
