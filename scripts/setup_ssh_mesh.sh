#!/bin/bash
# Deploy SSH keys across the cluster for full mesh connectivity
# Run from any machine that already has SSH access to all nodes
#
# Usage: ./setup_ssh_mesh.sh
set -e

# All machines in the cluster
MACHINES=(
    "neo@192.168.85.100"  # Spark
    "neo@192.168.85.101"  # DGX1
    "neo@192.168.85.102"  # DGX2
    "neo@192.168.85.103"  # DGX3
    "neo@192.168.85.104"  # DGX4
)

NAMES=("Spark" "DGX1" "DGX2" "DGX3" "DGX4")

echo "========================================"
echo " SSH Mesh Setup"
echo "========================================"

# Step 1: Collect all public keys
echo ""
echo "[1/3] Collecting public keys from all machines..."
ALL_KEYS=""
for i in "${!MACHINES[@]}"; do
    echo "  ${NAMES[$i]} (${MACHINES[$i]})..."
    keys=$(ssh -o ConnectTimeout=10 "${MACHINES[$i]}" 'cat ~/.ssh/id_ed25519.pub 2>/dev/null; cat ~/.ssh/id_rsa.pub 2>/dev/null' 2>/dev/null || true)
    if [[ -n "$keys" ]]; then
        ALL_KEYS+="$keys"$'\n'
        echo "    Found key(s)"
    else
        echo "    WARNING: No keys found, generating ed25519..."
        ssh -o ConnectTimeout=10 "${MACHINES[$i]}" \
            'ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -q'
        keys=$(ssh -o ConnectTimeout=10 "${MACHINES[$i]}" 'cat ~/.ssh/id_ed25519.pub')
        ALL_KEYS+="$keys"$'\n'
        echo "    Generated and collected"
    fi
done

# Step 2: Deploy all keys to all machines
echo ""
echo "[2/3] Deploying keys to all machines..."
for i in "${!MACHINES[@]}"; do
    echo "  ${NAMES[$i]} (${MACHINES[$i]})..."
    echo "$ALL_KEYS" | ssh -o ConnectTimeout=10 "${MACHINES[$i]}" '
        mkdir -p ~/.ssh && chmod 700 ~/.ssh
        while IFS= read -r key; do
            [[ -z "$key" ]] && continue
            grep -qF "$key" ~/.ssh/authorized_keys 2>/dev/null || echo "$key" >> ~/.ssh/authorized_keys
        done
        chmod 600 ~/.ssh/authorized_keys
        echo "    Keys deployed"
    '
done

# Step 3: Verify connectivity
echo ""
echo "[3/3] Verifying mesh (each machine -> all others)..."
for i in "${!MACHINES[@]}"; do
    for j in "${!MACHINES[@]}"; do
        [[ "$i" == "$j" ]] && continue
        mgmt_ip="192.168.85.$((100 + i))"
        [[ "$i" == "3" ]] && mgmt_ip="192.168.85.103"
        [[ "$i" == "4" ]] && mgmt_ip="192.168.85.104"
        result=$(ssh -o ConnectTimeout=10 -o BatchMode=yes "${MACHINES[$i]}" \
            "ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no ${MACHINES[$j]} hostname 2>/dev/null" 2>/dev/null || echo "FAIL")
        if [[ "$result" != "FAIL" ]]; then
            echo "  ${NAMES[$i]} -> ${NAMES[$j]}: OK ($result)"
        else
            echo "  ${NAMES[$i]} -> ${NAMES[$j]}: FAIL"
        fi
    done
done

echo ""
echo "========================================"
echo " SSH Mesh Setup Complete"
echo "========================================"
