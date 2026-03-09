#!/bin/bash
# RoCE/RDMA Setup for DGX Spark nodes
# Usage: sudo ./setup_roce.sh <host_octet>
#
# Each DGX Spark has:
#   - 1x Realtek 10G (enP7s7) for management on 192.168.85.0/24
#   - 4x ConnectX-7 100G ports for RDMA on 10.0.{1-4}.0/24
#
# Host octets:
#   Spark=1, DGX1=2, DGX2=3, DGX3=4, DGX4=5
#
# Example: sudo ./setup_roce.sh 2   (configures DGX1 with 10.0.{1-4}.2)
set -e

HOST_OCTET="${1:?Usage: $0 <host_octet> (1=Spark, 2=DGX1, 3=DGX2, 4=DGX3, 5=DGX4)}"

# 100G ConnectX-7 interfaces (same naming on all DGX Sparks)
IFACES=(enp1s0f0np0 enp1s0f1np1 enP2p1s0f0np0 enP2p1s0f1np1)
RDMA_DEVS=(rocep1s0f0 rocep1s0f1 roceP2p1s0f0 roceP2p1s0f1)
IPS=(10.0.1.${HOST_OCTET}/24 10.0.2.${HOST_OCTET}/24 10.0.3.${HOST_OCTET}/24 10.0.4.${HOST_OCTET}/24)

echo "========================================"
echo " RoCE/RDMA Setup - Host octet: ${HOST_OCTET}"
echo " IPs: 10.0.{1-4}.${HOST_OCTET}"
echo "========================================"

# Step 1: Remove stale default routes from 100G ports (DHCP artifacts)
echo ""
echo "[1/5] Cleaning default routes from 100G interfaces..."
for iface in "${IFACES[@]}"; do
    ip route del default dev "$iface" 2>/dev/null || true
    ip route del default via 192.168.85.1 dev "$iface" 2>/dev/null || true
done
echo "  Default routes cleaned (management via enP7s7 preserved)"

# Step 2: Flush and assign RDMA IPs
echo ""
echo "[2/5] Assigning RDMA IPs..."
for i in 0 1 2 3; do
    ip addr flush dev "${IFACES[$i]}" 2>/dev/null || true
    ip addr add "${IPS[$i]}" dev "${IFACES[$i]}"
    ip link set "${IFACES[$i]}" up
    echo "  ${IFACES[$i]} -> ${IPS[$i]}"
done

# Step 3: Set MTU and txqueuelen
echo ""
echo "[3/5] Setting MTU=1500 and txqueuelen=20000..."
for iface in "${IFACES[@]}"; do
    ip link set "$iface" mtu 1500
    ip link set "$iface" txqueuelen 20000
    echo "  $iface: mtu=1500 txqueuelen=20000"
done

# Step 4: Configure PFC and DSCP trust for lossless RoCE
echo ""
echo "[4/5] Configuring PFC and DSCP trust..."
for iface in "${IFACES[@]}"; do
    mlnx_qos -i "$iface" --trust dscp 2>/dev/null && \
        echo "  $iface: trust=dscp" || echo "  $iface: trust set skipped"
    mlnx_qos -i "$iface" --pfc 0,0,0,1,0,0,0,0 2>/dev/null && \
        echo "  $iface: PFC on priority 3" || echo "  $iface: PFC set skipped"
done

# Step 5: Verify
echo ""
echo "[5/5] Verification..."
echo ""
echo "RDMA devices:"
rdma dev 2>/dev/null || echo "  (rdma tool not available)"
echo ""
echo "Interface IPs:"
for iface in "${IFACES[@]}"; do
    echo "  $(ip -br addr show "$iface")"
done
echo ""
echo "Management (untouched):"
echo "  10G (enP7s7): $(ip -br addr show enP7s7 2>/dev/null)"
echo "  Default route: $(ip route show default | head -1)"

echo ""
echo "========================================"
echo " SETUP COMPLETE - Host .${HOST_OCTET}"
echo "========================================"
