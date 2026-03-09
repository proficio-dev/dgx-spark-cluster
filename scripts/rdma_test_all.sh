#!/bin/bash
# RDMA bandwidth test across all machine pairs
# Tests all 10 unique pairs in a 5-node cluster
# Each pair tested on all 4 x 100G ports simultaneously
#
# Machines: Spark(.1), DGX1(.2), DGX2(.3), DGX3(.4), DGX4(.5)
# RDMA IPs: 10.0.{port}.{host} where port=1-4, host=1-5
#
# Usage: ./rdma_test_all.sh

RESULTS_FILE="/tmp/rdma_results.txt"
> "$RESULTS_FILE"

# RDMA device names (same on all DGX Sparks)
DEVS=(rocep1s0f0 rocep1s0f1 roceP2p1s0f0 roceP2p1s0f1)
PORTS=(18501 18502 18503 18504)

# Machine map
declare -A NAMES=( [1]="Spark" [2]="DGX1" [3]="DGX2" [4]="DGX3" [5]="DGX4" )
declare -A SSH=(
    [1]=""
    [2]="neo@192.168.85.101"
    [3]="neo@192.168.85.102"
    [4]="neo@192.168.85.103"
    [5]="neo@192.168.85.104"
)

run_cmd() {
    local host_id=$1
    shift
    if [[ "$host_id" == "1" ]]; then
        eval "$@"
    else
        ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "${SSH[$host_id]}" "$@"
    fi
}

test_pair() {
    local srv_id=$1
    local cli_id=$2
    local srv_name="${NAMES[$srv_id]}"
    local cli_name="${NAMES[$cli_id]}"

    echo ""
    echo "========================================"
    echo "  $srv_name (.${srv_id}) <-> $cli_name (.${cli_id})"
    echo "========================================"

    # Kill any leftover ib_write_bw on both sides
    run_cmd "$srv_id" 'pkill -9 ib_write_bw 2>/dev/null; true'
    run_cmd "$cli_id" 'pkill -9 ib_write_bw 2>/dev/null; true'
    sleep 2

    # Start 4 servers
    echo "  Starting servers on $srv_name..."
    for i in 0 1 2 3; do
        run_cmd "$srv_id" "nohup ib_write_bw -d ${DEVS[$i]} -x 3 --report_gbits -p ${PORTS[$i]} -D 5 -F > /dev/null 2>&1 &"
    done
    sleep 2

    # Run 4 clients in parallel, collect results
    echo "  Running clients from $cli_name..."
    local client_cmd=""
    for i in 0 1 2 3; do
        local subnet=$((i + 1))
        client_cmd+="ib_write_bw -d ${DEVS[$i]} -x 3 --report_gbits -p ${PORTS[$i]} -D 5 -F 10.0.${subnet}.${srv_id} > /tmp/bw_${i}.txt 2>&1 & "
    done
    client_cmd+="wait; "
    for i in 0 1 2 3; do
        client_cmd+="echo \"PORT$((i+1)): \$(grep -E '^\s*65536' /tmp/bw_${i}.txt | awk '{print \$4}')\"; "
    done

    local output
    output=$(run_cmd "$cli_id" "$client_cmd" 2>&1)
    echo "$output"

    # Parse bandwidths
    local total=0
    local all_bw=""
    while IFS= read -r line; do
        local bw=$(echo "$line" | grep -oP '[\d.]+$' || true)
        if [[ -n "$bw" ]]; then
            total=$(echo "$total + $bw" | bc 2>/dev/null || echo "$total")
            all_bw+="$bw "
        fi
    done <<< "$output"

    echo "  TOTAL: ${total} Gb/s"
    echo "$srv_name <-> $cli_name: $all_bw => ${total} Gb/s" >> "$RESULTS_FILE"

    # Cleanup
    run_cmd "$srv_id" 'pkill -9 ib_write_bw 2>/dev/null; true'
    run_cmd "$cli_id" 'pkill -9 ib_write_bw 2>/dev/null; true'
    sleep 1
}

echo "============================================"
echo " Full RDMA Bandwidth Test - All 10 Pairs"
echo " $(date)"
echo "============================================"

# All 10 unique pairs
test_pair 1 2    # Spark <-> DGX1
test_pair 1 3    # Spark <-> DGX2
test_pair 1 4    # Spark <-> DGX3
test_pair 1 5    # Spark <-> DGX4
test_pair 2 3    # DGX1 <-> DGX2
test_pair 2 4    # DGX1 <-> DGX3
test_pair 2 5    # DGX1 <-> DGX4
test_pair 3 4    # DGX2 <-> DGX3
test_pair 3 5    # DGX2 <-> DGX4
test_pair 4 5    # DGX3 <-> DGX4

echo ""
echo "============================================"
echo " SUMMARY"
echo "============================================"
cat "$RESULTS_FILE"
echo "============================================"
echo " All tests complete: $(date)"
echo "============================================"
