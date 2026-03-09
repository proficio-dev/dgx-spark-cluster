#!/bin/bash
# Deploy RoCE setup to a remote DGX Spark node via nohup
# This approach survives SSH disconnect when interfaces are reconfigured
#
# Usage: ./deploy_roce.sh <ssh_target> <host_octet>
# Example: ./deploy_roce.sh neo@192.168.85.101 2
set -e

SSH_TARGET="${1:?Usage: $0 <ssh_target> <host_octet>}"
HOST_OCTET="${2:?Usage: $0 <ssh_target> <host_octet>}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SETUP_SCRIPT="$SCRIPT_DIR/setup_roce.sh"

if [[ ! -f "$SETUP_SCRIPT" ]]; then
    echo "ERROR: setup_roce.sh not found at $SETUP_SCRIPT"
    exit 1
fi

echo "Deploying RoCE setup to $SSH_TARGET (host octet: $HOST_OCTET)..."

# Copy script to remote
scp -o ConnectTimeout=10 "$SETUP_SCRIPT" "${SSH_TARGET}:/tmp/setup_roce.sh"
echo "Script copied"

# Run via nohup so it survives if SSH drops during network reconfig
ssh -o ConnectTimeout=10 "$SSH_TARGET" \
    "chmod +x /tmp/setup_roce.sh && sudo nohup bash /tmp/setup_roce.sh $HOST_OCTET > /tmp/roce_out.log 2>&1 &"
echo "Setup launched in background on $SSH_TARGET"
echo "Check progress: ssh $SSH_TARGET 'cat /tmp/roce_out.log'"
