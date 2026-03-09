#!/bin/bash
# Deploy inference stack to ALL DGX Spark nodes
# Run from Spark (control node, 192.168.85.100)
#
# This script:
#   1. Copies GitHub SSH key to each DGX node
#   2. Clones/updates the repo on each node
#   3. Runs install.sh on each node
#
# Usage: ./deploy_inference.sh [--skip-local]
#   --skip-local   Skip installation on Spark (local node)
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
REPO_URL="git@github.com:proficio-dev/dgx-spark-cluster.git"
REPO_DEST="/home/neo/dgx-spark-cluster"

GITHUB_KEY="$HOME/.ssh/id_ed25519_github"
GITHUB_KEY_PUB="${GITHUB_KEY}.pub"

SKIP_LOCAL=false
[[ "${1:-}" == "--skip-local" ]] && SKIP_LOCAL=true

# Remote nodes (DGX1–4)
declare -A NODES=(
    [DGX1]="neo@192.168.85.101"
    [DGX2]="neo@192.168.85.102"
    [DGX3]="neo@192.168.85.103"
    [DGX4]="neo@192.168.85.104"
)

SSH_OPTS="-o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes"

echo "========================================"
echo " Deploy Inference Stack to Cluster"
echo " $(date)"
echo "========================================"

# ---------- Verify GitHub key exists locally ----------
if [[ ! -f "$GITHUB_KEY" ]]; then
    echo "ERROR: GitHub SSH key not found at $GITHUB_KEY"
    exit 1
fi
echo "GitHub SSH key: $GITHUB_KEY"

# ---------- Step 1: Install locally on Spark ----------
if [[ "$SKIP_LOCAL" == false ]]; then
    echo ""
    echo "========================================"
    echo " [Spark] Local install"
    echo "========================================"
    bash "$SCRIPT_DIR/install.sh"
else
    echo ""
    echo "Skipping local install (--skip-local)"
fi

# ---------- Step 2: Deploy to each remote node ----------
for NODE_NAME in DGX1 DGX2 DGX3 DGX4; do
    TARGET="${NODES[$NODE_NAME]}"
    echo ""
    echo "========================================"
    echo " [$NODE_NAME] $TARGET"
    echo "========================================"

    # 2a. Copy GitHub SSH key
    echo "  [1/3] Deploying GitHub SSH key..."
    scp $SSH_OPTS "$GITHUB_KEY" "${TARGET}:~/.ssh/id_ed25519_github"
    scp $SSH_OPTS "$GITHUB_KEY_PUB" "${TARGET}:~/.ssh/id_ed25519_github.pub"
    ssh $SSH_OPTS "$TARGET" "chmod 600 ~/.ssh/id_ed25519_github"

    # 2b. Ensure SSH config for GitHub exists
    ssh $SSH_OPTS "$TARGET" '
        if ! grep -q "Host github.com" ~/.ssh/config 2>/dev/null; then
            cat >> ~/.ssh/config << EOF

Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_github
  IdentitiesOnly yes
EOF
            chmod 600 ~/.ssh/config
            echo "    SSH config for GitHub created"
        else
            echo "    SSH config for GitHub already exists"
        fi
    '

    # 2c. Clone or pull repo
    echo "  [2/3] Syncing repository..."
    ssh $SSH_OPTS "$TARGET" "
        if [[ -d '$REPO_DEST/.git' ]]; then
            cd '$REPO_DEST' && git pull --ff-only 2>&1 | tail -3
            echo '    Repo updated'
        else
            ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
            git clone '$REPO_URL' '$REPO_DEST' 2>&1 | tail -3
            echo '    Repo cloned'
        fi
    "

    # 2d. Run install
    echo "  [3/3] Running install.sh..."
    ssh $SSH_OPTS "$TARGET" "bash '$REPO_DEST/inference_setup/install.sh'" 2>&1 | while IFS= read -r line; do
        echo "    $line"
    done

    echo "  [$NODE_NAME] Done"
done

echo ""
echo "========================================"
echo " Deployment complete on all nodes"
echo "========================================"
