#!/bin/bash
# Install vLLM + Ray inference stack on a DGX Spark node
# Creates a Python venv and installs all dependencies
#
# Usage: ./install.sh
# Run on each node (or use deploy_inference.sh to run across all)
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

echo "========================================"
echo " vLLM + Ray Install — $(hostname)"
echo " $(date)"
echo "========================================"

# Ensure python3-venv is available
if ! python3 -c "import venv" 2>/dev/null; then
    echo "[1/4] Installing python3-venv..."
    sudo apt-get update -qq && sudo apt-get install -y -qq python3-venv
else
    echo "[1/4] python3-venv already available"
fi

# Create venv
if [[ ! -d "$VENV_DIR" ]]; then
    echo "[2/4] Creating virtual environment at $VENV_DIR..."
    python3 -m venv "$VENV_DIR"
else
    echo "[2/4] Virtual environment already exists"
fi

# Activate and upgrade pip
source "$VENV_DIR/bin/activate"
echo "[3/4] Upgrading pip..."
pip install --upgrade pip setuptools wheel 2>&1 | tail -3

# Install requirements
echo "[4/4] Installing vLLM + Ray + PyTorch..."
pip install -r "$SCRIPT_DIR/requirements.txt" 2>&1 | tail -20

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
