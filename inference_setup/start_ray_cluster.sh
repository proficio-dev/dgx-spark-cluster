#!/bin/bash
# Start Ray cluster across all DGX Spark nodes
# Run from Spark (head node, 192.168.85.100)
#
# Usage: ./start_ray_cluster.sh [stop]
#   stop   Tear down the Ray cluster on all nodes
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_ACTIVATE="$SCRIPT_DIR/.venv/bin/activate"

HEAD_IP="192.168.85.100"
RAY_PORT=6379
DASHBOARD_PORT=8265

declare -A NODES=(
    [DGX1]="neo@192.168.85.101"
    [DGX2]="neo@192.168.85.102"
    [DGX3]="neo@192.168.85.103"
    [DGX4]="neo@192.168.85.104"
)

REMOTE_VENV="/home/neo/dgx-spark-cluster/inference_setup/.venv/bin/activate"
SSH_OPTS="-o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes"

# ---------- NCCL environment for RoCE ----------
NCCL_ENV="NCCL_IB_HCA=rocep1s0f0,rocep1s0f1,roceP2p1s0f0,roceP2p1s0f1"
NCCL_ENV+=" NCCL_IB_GID_INDEX=3"
NCCL_ENV+=" NCCL_NET_GDR_LEVEL=5"
NCCL_ENV+=" NCCL_SOCKET_IFNAME=enP7s7"
NCCL_ENV+=" NCCL_DEBUG=INFO"

# ---------- Stop mode ----------
if [[ "${1:-}" == "stop" ]]; then
    echo "Stopping Ray on all nodes..."
    source "$VENV_ACTIVATE"
    ray stop --force 2>/dev/null || true
    for NODE_NAME in DGX1 DGX2 DGX3 DGX4; do
        TARGET="${NODES[$NODE_NAME]}"
        echo "  Stopping Ray on $NODE_NAME..."
        ssh $SSH_OPTS "$TARGET" "source $REMOTE_VENV && ray stop --force" 2>/dev/null || true
    done
    echo "Ray cluster stopped"
    exit 0
fi

echo "========================================"
echo " Starting Ray Cluster"
echo " Head: Spark ($HEAD_IP:$RAY_PORT)"
echo " $(date)"
echo "========================================"

# ---------- Start head node ----------
echo ""
echo "[1/2] Starting Ray head on Spark..."
source "$VENV_ACTIVATE"

# Stop any existing Ray first
ray stop --force 2>/dev/null || true

env $NCCL_ENV ray start \
    --head \
    --port=$RAY_PORT \
    --dashboard-host=0.0.0.0 \
    --dashboard-port=$DASHBOARD_PORT \
    --num-gpus=1

echo "  Head node started"
echo "  Dashboard: http://${HEAD_IP}:${DASHBOARD_PORT}"

# ---------- Start worker nodes ----------
echo ""
echo "[2/2] Starting Ray workers..."
for NODE_NAME in DGX1 DGX2 DGX3 DGX4; do
    TARGET="${NODES[$NODE_NAME]}"
    echo "  Starting worker on $NODE_NAME ($TARGET)..."
    ssh $SSH_OPTS "$TARGET" "
        source $REMOTE_VENV
        ray stop --force 2>/dev/null || true
        $NCCL_ENV ray start --address=${HEAD_IP}:${RAY_PORT} --num-gpus=1
    " 2>&1 | tail -3 | sed 's/^/    /'
    echo "  $NODE_NAME joined"
done

# ---------- Verify ----------
echo ""
echo "========================================"
echo " Ray Cluster Status"
echo "========================================"
sleep 3
ray status 2>&1

echo ""
echo "Cluster ready. Start vLLM with:"
echo "  source $VENV_ACTIVATE"
echo "  ./start_vllm.sh <model>"
