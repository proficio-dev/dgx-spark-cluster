#!/bin/bash
# Launch vLLM inference server on the Ray cluster
# Run from Spark after start_ray_cluster.sh
#
# Usage: ./start_vllm.sh <model> [options]
# Example:
#   ./start_vllm.sh meta-llama/Llama-3.1-70B-Instruct
#   ./start_vllm.sh mistralai/Mistral-7B-Instruct-v0.3 --max-model-len 8192
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_ACTIVATE="$SCRIPT_DIR/.venv/bin/activate"

MODEL="${1:?Usage: $0 <model_name_or_path> [extra vllm args...]}"
shift

# Activate venv
source "$VENV_ACTIVATE"

# NCCL over RoCE
export NCCL_IB_HCA=rocep1s0f0,rocep1s0f1,roceP2p1s0f0,roceP2p1s0f1
export NCCL_IB_GID_INDEX=3
export NCCL_NET_GDR_LEVEL=5
export NCCL_SOCKET_IFNAME=enP7s7
export NCCL_DEBUG=WARN

# Detect how many GPUs Ray sees
NUM_GPUS=$(python3 -c "import ray; ray.init(address='auto'); print(int(ray.cluster_resources().get('GPU', 1)))" 2>/dev/null || echo "5")

echo "========================================"
echo " vLLM Inference Server"
echo " Model: $MODEL"
echo " Tensor parallel: $NUM_GPUS GPUs"
echo " $(date)"
echo "========================================"

exec vllm serve "$MODEL" \
    --tensor-parallel-size "$NUM_GPUS" \
    --distributed-executor-backend ray \
    --host 0.0.0.0 \
    --port 8000 \
    "$@"
