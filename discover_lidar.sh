#!/bin/bash
# 自动发现 Livox 雷达
# 扫描 192.168.1.0/24 网段，找到 Livox 设备
# 用法: ./discover_lidar.sh [interface]
# 输出: 雷达 IP 列表

set -e

IFACE="${1:-enp170s0}"

# 确保网口有 IP
IFACE_IP=$(ip -4 addr show "$IFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+' | head -1)
if [ -z "$IFACE_IP" ]; then
    echo "[ERROR] $IFACE 没有 IP，请先运行 setup_network.sh" >&2
    exit 1
fi

SUBNET=$(echo "$IFACE_IP" | cut -d. -f1-3)
echo "[INFO] 扫描 ${SUBNET}.0/24 网段寻找 Livox 雷达..." >&2

# 方法1: 抓取雷达广播包（最快，2秒内）
LIDAR_IPS=$(timeout 3 sudo tcpdump -i "$IFACE" -c 5 -n "udp and portrange 56000-56550" 2>/dev/null \
    | awk '{print $3}' \
    | sed -E 's/\.[0-9]+$//' \
    | grep -oP '\d+\.\d+\.\d+\.\d+' \
    | sort -u \
    | grep -v "$IFACE_IP" \
    | grep -v "255.255.255.255" || true)

if [ -n "$LIDAR_IPS" ]; then
    echo "[OK] 通过广播包发现雷达:" >&2
    echo "$LIDAR_IPS"
    exit 0
fi

# 方法2: ARP 扫描（备用）
echo "[INFO] 广播包未捕获，尝试 ARP 扫描..." >&2
if command -v arp-scan &>/dev/null; then
    LIDAR_IPS=$(sudo arp-scan -I "$IFACE" "${SUBNET}.0/24" 2>/dev/null \
        | grep -i "livox\|dji" \
        | awk '{print $1}' || true)
elif command -v nmap &>/dev/null; then
    LIDAR_IPS=$(sudo nmap -sn "${SUBNET}.0/24" --interface "$IFACE" 2>/dev/null \
        | grep -oP '\d+\.\d+\.\d+\.\d+' || true)
else
    # 方法3: ping 扫描（最慢）
    echo "[INFO] 使用 ping 扫描（可能需要 30 秒）..." >&2
    for i in $(seq 1 254); do
        ping -c 1 -W 1 -I "$IFACE" "${SUBNET}.$i" &>/dev/null &
    done
    wait
    LIDAR_IPS=$(ip neigh show dev "$IFACE" 2>/dev/null \
        | awk '$2 == "lladdr" && $0 !~ /INCOMPLETE|FAILED/ {print $1}' \
        | grep -v "$IFACE_IP" || true)
fi

if [ -n "$LIDAR_IPS" ]; then
    echo "[OK] 发现设备:" >&2
    echo "$LIDAR_IPS"
else
    echo "[WARN] 未发现雷达，请检查:" >&2
    echo "  1. 雷达是否通电" >&2
    echo "  2. 网线是否连接到 $IFACE" >&2
    echo "  3. 雷达 IP 是否在 ${SUBNET}.0/24 网段" >&2
    exit 1
fi
