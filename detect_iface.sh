#!/bin/bash
# 自动检测连接雷达的网口
# 逻辑：遍历物理网口，抓取 Livox 广播包（UDP 56200），有响应的就是雷达口
# 输出：网口名

set -e

# 获取所有物理以太网口（排除 lo、虚拟网卡）
get_physical_ifaces() {
    ip -br link show | awk '{print $1}' | while read iface; do
        [ "$iface" = "lo" ] && continue
        # 排除虚拟网卡（zerotier、docker、veth、br- 等）
        echo "$iface" | grep -qE '^(zts|docker|veth|br-|virbr|bond|tap)' && continue
        # 确认是物理设备
        [ -d "/sys/class/net/$iface/device" ] && echo "$iface"
    done
}

# 检测网口是否有 Livox 流量（抓 3 秒 UDP 56200 端口）
check_livox_traffic() {
    local iface="$1"
    local count
    count=$(timeout 3 sudo tcpdump -i "$iface" -c 3 udp port 56200 2>/dev/null | wc -l)
    [ "$count" -gt 0 ]
}

IFACES=$(get_physical_ifaces)
if [ -z "$IFACES" ]; then
    echo "[ERROR] 未找到物理以太网口" >&2
    exit 1
fi

echo "[INFO] 检测物理网口: $(echo $IFACES | tr '\n' ' ')" >&2

for iface in $IFACES; do
    # 跳过已有 internet IP 的网口（非 192.168.x.x）
    ip_addr=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+' | head -1)
    if [ -n "$ip_addr" ]; then
        echo "$ip_addr" | grep -qE '^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)' || {
            echo "[INFO] $iface 有公网 IP $ip_addr，跳过" >&2
            continue
        }
    fi

    echo "[INFO] 检查 $iface 是否有 Livox 流量..." >&2
    if check_livox_traffic "$iface"; then
        echo "[OK] 发现雷达网口: $iface" >&2
        echo "$iface"
        exit 0
    fi
done

echo "[ERROR] 未发现 Livox 雷达，请检查网线连接" >&2
exit 1
