# Inference Setup — vLLM + Ray on DGX Spark Cluster

Multi-node LLM inference using vLLM with Ray for distributed tensor parallelism across 5 DGX Spark nodes, communicating over the RoCE v2 RDMA mesh.

## Files

| File | Purpose |
|------|---------|
| `requirements.txt` | Python dependencies (vLLM, Ray, PyTorch) |
| `install.sh` | Install stack on a single node (creates `.venv`) |
| `deploy_inference.sh` | Deploy to **all** nodes from Spark |
| `start_ray_cluster.sh` | Start/stop Ray cluster (5 nodes) |
| `start_vllm.sh` | Launch vLLM serving on the Ray cluster |
| `verify_cluster.sh` | Verify installation on all nodes |

## Quick Start

### 1. Deploy to all nodes (from Spark)

```bash
cd ~/dgx-spark-cluster/inference_setup
chmod +x *.sh
./deploy_inference.sh
```

This will:
- Install the venv + packages on Spark
- Copy GitHub SSH key to DGX1–4
- Clone the repo on each DGX node
- Run `install.sh` on each node

### 2. Start the Ray cluster

```bash
./start_ray_cluster.sh
```

### 3. Launch vLLM

```bash
./start_vllm.sh meta-llama/Llama-3.1-70B-Instruct
```

The API server runs on `http://192.168.85.100:8000` (OpenAI-compatible).

### 4. Test it

```bash
curl http://192.168.85.100:8000/v1/models
curl http://192.168.85.100:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "meta-llama/Llama-3.1-70B-Instruct", "prompt": "Hello", "max_tokens": 64}'
```

### 5. Tear down

```bash
./start_ray_cluster.sh stop
```

## NCCL / RoCE Configuration

The scripts set the following environment variables to route NCCL traffic over RoCE:

| Variable | Value | Purpose |
|----------|-------|---------|
| `NCCL_IB_HCA` | `rocep1s0f0,rocep1s0f1,roceP2p1s0f0,roceP2p1s0f1` | Use all 4 ConnectX-7 ports |
| `NCCL_IB_GID_INDEX` | `3` | RoCE v2 GID |
| `NCCL_NET_GDR_LEVEL` | `5` | GPU Direct RDMA |
| `NCCL_SOCKET_IFNAME` | `enP7s7` | Management NIC for control plane |

## Notes

- Each node gets its own `.venv` at `inference_setup/.venv/` (git-ignored)
- The `.venv` is **not** shared across nodes — each installs independently
- GB10 has unified CPU+GPU memory; use `--cpu-offload-gb` in vLLM if needed
- Ray dashboard available at `http://192.168.85.100:8265` when cluster is running
