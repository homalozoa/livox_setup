#!/bin/bash
# 配置雷达网口 IP（开机自启动由 NetworkManager 持久化）
# 用法: ./setup_network.sh [interface] [host_ip]
# 默认: enp170s0, 192.168.1.250

set -e

IFACE="${1:-enp170s0}"
HOST_IP="${2:-192.168.1.250}"
SUBNET="/24"

# 检查接口是否存在
if ! ip link show "$IFACE" &>/dev/null; then
    echo "[ERROR] 网口 $IFACE 不存在"
    echo "可用网口:"
    ip -br link show | grep -v lo
    exit 1
fi

# 获取连接名（NetworkManager）
CON_NAME=$(nmcli -t -f NAME,DEVICE con show | grep "$IFACE" | cut -d: -f1)
if [ -z "$CON_NAME" ]; then
    echo "[INFO] 为 $IFACE 创建新的 NetworkManager 连接"
    nmcli con add type ethernet ifname "$IFACE" con-name "livox-$IFACE"
    CON_NAME="livox-$IFACE"
fi

# 配置静态 IP
CURRENT_IP=$(nmcli -t -f IP4.ADDRESS con show "$CON_NAME" 2>/dev/null | head -1)
if [ "$CURRENT_IP" = "${HOST_IP}${SUBNET}" ]; then
    echo "[OK] $IFACE 已配置 ${HOST_IP}${SUBNET}"
else
    echo "[INFO] 配置 $IFACE: ${HOST_IP}${SUBNET}"
    nmcli con mod "$CON_NAME" ipv4.addresses "${HOST_IP}${SUBNET}" ipv4.method manual
    nmcli con up "$CON_NAME"
    echo "[OK] $IFACE 已配置 ${HOST_IP}${SUBNET}"
fi
