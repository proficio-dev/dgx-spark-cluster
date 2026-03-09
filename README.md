# DGX Spark Cluster — RoCE/RDMA Setup

A 5-node NVIDIA DGX Spark cluster connected via 4×100G ConnectX-7 NICs per node, configured for RoCE v2 (RDMA over Converged Ethernet) with ~185 Gb/s verified bandwidth between every pair.

## Cluster Overview

| Node  | Management IP     | RDMA IPs             | GPU           |
|-------|-------------------|----------------------|---------------|
| Spark | 192.168.85.100    | 10.0.{1-4}.1         | NVIDIA GB10   |
| DGX1  | 192.168.85.101    | 10.0.{1-4}.2         | NVIDIA GB10   |
| DGX2  | 192.168.85.102    | 10.0.{1-4}.3         | NVIDIA GB10   |
| DGX3  | 192.168.85.103    | 10.0.{1-4}.4         | NVIDIA GB10   |
| DGX4  | 192.168.85.104    | 10.0.{1-4}.5         | NVIDIA GB10   |

- **Architecture**: aarch64 (ARM), Ubuntu 24.04
- **GPU**: NVIDIA GB10 (Grace Blackwell), passively cooled
- **NICs**: Mellanox ConnectX-7, 4× 100G ports per node
- **Management**: 1× Realtek 10G (enP7s7) per node
- **Router**: MikroTik at 192.168.85.1

## Network Topology

```
             ┌─────────────────────────────────┐
             │   MikroTik Router 192.168.85.1  │
             └───────────┬─────────────────────┘
                         │ 10G Management LAN
          ┌──────┬───────┼───────┬──────┐
        Spark  DGX1    DGX2   DGX3   DGX4
        .100   .101    .102   .103   .104
          │      │       │      │      │
          └──────┴───────┴──────┴──────┘
             4×100G RoCE v2 Full Mesh
             10.0.{1-4}.{1-5}/24
```

Each node has 4 ConnectX-7 ports. The IP scheme is:
- **10.0.{port}.{host}** where port = 1–4, host = 1 (Spark), 2 (DGX1), 3 (DGX2), 4 (DGX3), 5 (DGX4)

All 10 node pairs achieve **~185 Gb/s** aggregate RDMA bandwidth (4 × ~46.3 Gb/s per port).

## Hardware Per Node

| Component        | Details                                      |
|------------------|----------------------------------------------|
| CPU              | ARM (Grace)                                  |
| GPU              | NVIDIA GB10 (passively cooled, ~4W idle)     |
| 100G NICs        | ConnectX-7 × 4 ports                         |
| 10G NIC          | Realtek (enP7s7) for management              |
| OS               | Ubuntu 24.04 (aarch64)                       |

### Interface Names (all nodes)

| Interface        | RDMA Device    | Subnet   |
|------------------|----------------|----------|
| enp1s0f0np0      | rocep1s0f0     | 10.0.1.x |
| enp1s0f1np1      | rocep1s0f1     | 10.0.2.x |
| enP2p1s0f0np0    | roceP2p1s0f0   | 10.0.3.x |
| enP2p1s0f1np1    | roceP2p1s0f1   | 10.0.4.x |

## Quick Start

### 1. SSH Key Access

Copy your SSH key to a new node:
```bash
ssh-copy-id neo@192.168.85.1XX
```

### 2. Set Up a Single Node

From the control node (Spark), set up a new machine with one command:
```bash
./scripts/setup_node.sh neo@192.168.85.101 2 192.168.85.101
```

This will:
- Configure passwordless sudo
- Generate an ed25519 SSH key
- Deploy and run the RoCE setup script

### 3. Configure RoCE Directly

On any node, run the setup script with the host octet:
```bash
sudo ./scripts/setup_roce.sh 2       # For DGX1 (10.0.{1-4}.2)
sudo ./scripts/setup_roce.sh 3       # For DGX2 (10.0.{1-4}.3)
```

### 4. Deploy RoCE to a Remote Node

When you can't run interactively (SSH may drop during network reconfig):
```bash
./scripts/deploy_roce.sh neo@192.168.85.103 4
```

This uses `nohup` so the script survives SSH disconnection.

### 5. Set Up SSH Mesh

Deploy keys so all nodes can SSH to each other:
```bash
./scripts/setup_ssh_mesh.sh
```

### 6. Run RDMA Bandwidth Test

Test all 10 node pairs (4 ports each):
```bash
./scripts/rdma_test_all.sh
```

Expected output:
```
Spark <-> DGX1: 46.28 46.28 46.28 46.28 => 185.14 Gb/s
Spark <-> DGX2: 46.28 46.28 46.28 46.28 => 185.13 Gb/s
Spark <-> DGX3: 46.28 46.28 46.28 46.28 => 185.12 Gb/s
Spark <-> DGX4: 46.28 46.28 46.28 46.28 => 185.12 Gb/s
DGX1 <-> DGX2: 46.28 46.28 46.28 46.28 => 185.13 Gb/s
DGX1 <-> DGX3: 46.28 46.28 46.28 46.28 => 185.12 Gb/s
DGX1 <-> DGX4: 46.28 46.28 46.28 46.28 => 185.12 Gb/s
DGX2 <-> DGX3: 46.28 46.28 46.28 46.28 => 185.12 Gb/s
DGX2 <-> DGX4: 46.28 46.28 46.28 46.28 => 185.12 Gb/s
DGX3 <-> DGX4: 46.28 46.28 46.28 46.28 => 185.12 Gb/s
```

## RoCE Configuration Details

| Parameter          | Value                           |
|--------------------|---------------------------------|
| RoCE version       | v2                              |
| GID index          | 3                               |
| MTU                | 1500                            |
| PFC priority       | 3 (lossless)                    |
| DSCP trust         | Enabled                         |
| TX queue length    | 20000                           |
| Test tool          | `ib_write_bw` (perftest suite)  |

## Scripts

| Script                  | Purpose                                        |
|-------------------------|------------------------------------------------|
| `scripts/setup_roce.sh` | Core RoCE setup — run on any node with `sudo`  |
| `scripts/deploy_roce.sh`| Deploy and run RoCE setup on a remote node      |
| `scripts/setup_node.sh` | Full node bootstrap (sudo + SSH key + RoCE)     |
| `scripts/setup_sudo.sh` | Configure passwordless sudo on a remote node    |
| `scripts/setup_ssh_mesh.sh` | Deploy SSH keys across all nodes            |
| `scripts/rdma_test_all.sh`  | Bandwidth test across all 10 node pairs     |

## Known Issues

### DHCP Reclaims RDMA IPs

The 100G interfaces may get DHCP addresses (192.168.85.x) after reboot, overriding the RDMA IPs. The setup scripts flush these, but **the configuration is not persistent across reboots**. Re-run `setup_roce.sh` after each reboot, or add the configuration to netplan/systemd-networkd.

### MikroTik SSH Interception

The MikroTik router at 192.168.85.1 intercepts SSH connections to 192.168.85.100 (Spark). To SSH from outside the cluster to Spark, use a ProxyJump:

```bash
# ~/.ssh/config on your MacBook
Host spark
    HostName 192.168.85.100
    User neo
    ProxyJump neo@192.168.85.101
```

## Adding a New Node

1. Connect the node to the switch (4× 100G + 1× 10G)
2. Find its DHCP-assigned management IP: `nmap -sn 192.168.85.0/24`
3. Copy your SSH key: `ssh-copy-id neo@<ip>`
4. Run: `./scripts/setup_node.sh neo@<ip> <next_octet> <mgmt_ip>`
5. Run: `./scripts/setup_ssh_mesh.sh`
6. Verify: `./scripts/rdma_test_all.sh` (update the script with the new node first)

## License

MIT
