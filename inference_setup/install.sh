#!/bin/bash
# Install vLLM + Ray inference stack on a DGX Spark node
# Creates a Python venv and installs all dependencies
#
# PyTorch requires the cu128 index for aarch64 CUDA wheels, plus
# exact versions of NVIDIA pip packages to match.
#
# Usage: ./install.sh
# Run on each node (or use deploy_inference.sh to run across all)
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"
TORCH_INDEX="https://download.pytorch.org/whl/cu128"

echo "========================================"
echo " vLLM + Ray Install — $(hostname)"
echo " $(date)"
echo "========================================"

# Ensure python3-venv is available
if ! python3 -c "import venv" 2>/dev/null; then
    echo "[1/5] Installing python3-venv..."
    sudo apt-get update -qq && sudo apt-get install -y -qq python3-venv
else
    echo "[1/5] python3-venv already available"
fi

# Create venv
if [[ ! -d "$VENV_DIR" ]]; then
    echo "[2/5] Creating virtual environment at $VENV_DIR..."
    python3 -m venv "$VENV_DIR"
else
    echo "[2/5] Virtual environment already exists"
fi

# Activate and upgrade pip
source "$VENV_DIR/bin/activate"
echo "[3/5] Upgrading pip..."
pip install --upgrade pip setuptools wheel 2>&1 | tail -3

# Install PyTorch with CUDA from the cu128 index (aarch64 needs this)
echo "[4/5] Installing PyTorch (CUDA 12.8 aarch64)..."
pip install torch torchvision torchaudio --index-url "$TORCH_INDEX" 2>&1 | tail -5

# Install vLLM + Ray (these pull in the rest)
echo "[5/5] Installing vLLM + Ray..."
pip install "vllm>=0.17.0" "ray[default]>=2.54.0" 2>&1 | tail -10

echo ""
echo "========================================"
echo " Verifying installation..."
echo "========================================"
python3 -c "import torch; print(f'  PyTorch {torch.__version__}, CUDA available: {torch.cuda.is_available()}')"
python3 -c "import ray; print(f'  Ray {ray.__version__}')"
python3 -c "import vllm; print(f'  vLLM {vllm.__version__}')"

echo ""
echo "Install complete on $(hostname)"
echo "Activate with: source $VENV_DIR/bin/activate"
