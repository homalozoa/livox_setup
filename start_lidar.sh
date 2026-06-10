#!/bin/bash
# 一键启动 Livox 雷达
# 自动发现雷达 IP、适配配置、启动驱动
# 用法: ./start_lidar.sh [interface] [host_ip]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IFACE="${1:-enp170s0}"
HOST_IP="${2:-192.168.1.250}"
LIVOX_WS="$HOME/livox_ws"
CONFIG_DIR="$LIVOX_WS/install/livox_ros_driver2/share/livox_ros_driver2/config"
SRC_CONFIG_DIR="$LIVOX_WS/src/livox_ros_driver2/config"

echo "=========================================="
echo "  Livox 雷达一键启动"
echo "=========================================="

# Step 1: 配置网络
echo ""
echo "[Step 1/4] 配置网络..."
"$SCRIPT_DIR/setup_network.sh" "$IFACE" "$HOST_IP"

# Step 2: 发现雷达
echo ""
echo "[Step 2/4] 发现雷达..."
LIDAR_IPS=$("$SCRIPT_DIR/discover_lidar.sh" "$IFACE" 2>&1 | grep -oP '\d+\.\d+\.\d+\.\d+' || true)

if [ -z "$LIDAR_IPS" ]; then
    echo "[ERROR] 未发现雷达，退出"
    exit 1
fi

LIDAR_IP=$(echo "$LIDAR_IPS" | head -1)
echo "[OK] 使用雷达: $LIDAR_IP"

# Step 3: 生成配置
echo ""
echo "[Step 3/4] 生成配置..."

# 判断是 MID360 还是 MID360s（通过端口差异检测）
# 先尝试 MID360s 配置（新固件用数组格式的 host_net_info）
cat > "$CONFIG_DIR/MID360s_config.json" << EOF
{
  "lidar_summary_info" : {
    "lidar_type": 8
  },
  "Mid360s": {
    "lidar_net_info" : {
      "cmd_data_port"  : 56100,
      "push_msg_port"  : 56200,
      "point_data_port": 56300,
      "imu_data_port"  : 56400,
      "log_data_port"  : 56500
    },
    "host_net_info" : [
      {
        "host_ip"        : "$HOST_IP",
        "cmd_data_port"  : 56101,
        "push_msg_port"  : 56201,
        "point_data_port": 56301,
        "imu_data_port"  : 56401,
        "log_data_port"  : 56501
      }
    ]
  },
  "lidar_configs" : [
    {
      "ip" : "$LIDAR_IP",
      "pcl_data_type" : 1,
      "pattern_mode" : 0,
      "extrinsic_parameter" : {
        "roll": 0.0, "pitch": 0.0, "yaw": 0.0,
        "x": 0, "y": 0, "z": 0
      }
    }
  ]
}
EOF

cat > "$CONFIG_DIR/MID360_config.json" << EOF
{
  "lidar_summary_info" : {
    "lidar_type": 8
  },
  "MID360": {
    "lidar_net_info" : {
      "cmd_data_port": 56100,
      "push_msg_port": 56200,
      "point_data_port": 56300,
      "imu_data_port": 56400,
      "log_data_port": 56500
    },
    "host_net_info" : {
      "cmd_data_ip" : "$HOST_IP",
      "cmd_data_port": 56101,
      "push_msg_ip": "$HOST_IP",
      "push_msg_port": 56201,
      "point_data_ip": "$HOST_IP",
      "point_data_port": 56301,
      "imu_data_ip" : "$HOST_IP",
      "imu_data_port": 56401,
      "log_data_ip" : "",
      "log_data_port": 56501
    }
  },
  "lidar_configs" : [
    {
      "ip" : "$LIDAR_IP",
      "pcl_data_type" : 1,
      "pattern_mode" : 0,
      "extrinsic_parameter" : {
        "roll": 0.0, "pitch": 0.0, "yaw": 0.0,
        "x": 0, "y": 0, "z": 0
      }
    }
  ]
}
EOF

# 同步到源码目录
cp "$CONFIG_DIR/MID360s_config.json" "$SRC_CONFIG_DIR/" 2>/dev/null || true
cp "$CONFIG_DIR/MID360_config.json" "$SRC_CONFIG_DIR/" 2>/dev/null || true

echo "[OK] 配置已更新: 雷达=$LIDAR_IP, 主机=$HOST_IP"

# Step 4: 启动驱动
echo ""
echo "[Step 4/4] 启动驱动..."
echo "=========================================="
echo "  Topics: /livox/lidar, /livox/imu"
echo "  Ctrl+C 退出"
echo "=========================================="
echo ""

source /opt/ros/jazzy/setup.bash
source "$LIVOX_WS/install/setup.bash"

# 优先尝试 MID360s，失败则用 MID360
ros2 launch livox_ros_driver2 msg_MID360s_launch.py
