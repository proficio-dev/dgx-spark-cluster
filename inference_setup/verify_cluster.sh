#!/bin/bash
# Verify inference stack installation across all nodes
# Run from Spark
#
# Usage: ./verify_cluster.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_ACTIVATE="$SCRIPT_DIR/.venv/bin/activate"
REMOTE_VENV="/home/neo/dgx-spark-cluster/inference_setup/.venv/bin/activate"

SSH_OPTS="-o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes"

ALL_NODES=(
    "Spark|local"
    "DGX1|neo@192.168.85.101"
    "DGX2|neo@192.168.85.102"
    "DGX3|neo@192.168.85.103"
    "DGX4|neo@192.168.85.104"
)

CHECK_CMD='
source VENV_PATH
echo "python: $(python3 --version 2>&1)"
echo "torch: $(python3 -c "import torch; print(torch.__version__)" 2>&1)"
echo "cuda: $(python3 -c "import torch; print(torch.cuda.is_available())" 2>&1)"
echo "ray: $(python3 -c "import ray; print(ray.__version__)" 2>&1)"
echo "vllm: $(python3 -c "import vllm; print(vllm.__version__)" 2>&1)"
echo "gpu: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>&1)"
'

echo "========================================"
echo " Cluster Verification"
echo " $(date)"
echo "========================================"

PASS=0
FAIL=0

for entry in "${ALL_NODES[@]}"; do
    IFS='|' read -r name target <<< "$entry"
    echo ""
    echo "--- $name ---"

    if [[ "$target" == "local" ]]; then
        cmd="${CHECK_CMD//VENV_PATH/$VENV_ACTIVATE}"
        eval "$cmd" 2>&1 | sed 's/^/  /'
    else
        cmd="${CHECK_CMD//VENV_PATH/$REMOTE_VENV}"
        ssh $SSH_OPTS "$target" "$cmd" 2>&1 | sed 's/^/  /'
    fi

    if [[ $? -eq 0 ]]; then
        ((PASS++))
    else
        ((FAIL++))
        echo "  STATUS: FAIL"
    fi
done

echo ""
echo "========================================"
echo " Results: $PASS passed, $FAIL failed"
echo "========================================"
