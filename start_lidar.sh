#!/bin/bash
# 一键启动 Livox 雷达
# 自动检测网口、发现雷达 IP、适配配置、启动驱动
# 用法: ./start_lidar.sh [interface] [host_ip]
# 不传参则自动检测

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIVOX_WS="$HOME/livox_ws"
CONFIG_DIR="$LIVOX_WS/install/livox_ros_driver2/share/livox_ros_driver2/config"
SRC_CONFIG_DIR="$LIVOX_WS/src/livox_ros_driver2/config"
LAUNCH_FILE="$LIVOX_WS/install/livox_ros_driver2/share/livox_ros_driver2/launch/msg_MID360s_launch.py"
if [ ! -f "$LAUNCH_FILE" ]; then
    LAUNCH_FILE="$LIVOX_WS/install/livox_ros_driver2/share/livox_ros_driver2/launch_ROS2/msg_MID360s_launch.py"
fi

echo "=========================================="
echo "  Livox 雷达一键启动"
echo "=========================================="

# Step 1: 自动检测或使用指定网口
if [ -n "$1" ]; then
    IFACE="$1"
    echo "[INFO] 使用指定网口: $IFACE"
else
    echo "[Step 1/4] 自动检测雷达网口..."
    IFACE=$("$SCRIPT_DIR/detect_iface.sh")
fi

# Step 2: 配置网络
HOST_IP="${2:-192.168.1.250}"
echo ""
echo "[Step 2/4] 配置网络 ($IFACE -> $HOST_IP)..."
if [ "$(id -u)" -eq 0 ]; then
    "$SCRIPT_DIR/setup_network.sh" "$IFACE" "$HOST_IP"
else
    sudo "$SCRIPT_DIR/setup_network.sh" "$IFACE" "$HOST_IP"
fi

# Step 3: 发现雷达
echo ""
echo "[Step 3/4] 发现雷达..."
LIDAR_IPS=$("$SCRIPT_DIR/discover_lidar.sh" "$IFACE" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || true)

if [ -z "$LIDAR_IPS" ]; then
    echo "[ERROR] 未发现雷达，退出"
    exit 1
fi

LIDAR_IP=$(echo "$LIDAR_IPS" | head -1)
echo "[OK] 雷达: $LIDAR_IP"

# Step 4: 生成配置
echo ""
echo "[Step 4/4] 生成配置并启动驱动..."

# MID360s 配置
cat > "$CONFIG_DIR/MID360s_config.json" << EOF
{
  "lidar_summary_info" : { "lidar_type": 8 },
  "Mid360s": {
    "lidar_net_info" : {
      "cmd_data_port"  : 56100, "push_msg_port"  : 56200,
      "point_data_port": 56300, "imu_data_port"  : 56400, "log_data_port"  : 56500
    },
    "host_net_info" : [{
      "host_ip"        : "$HOST_IP",
      "cmd_data_port"  : 56101, "push_msg_port"  : 56201,
      "point_data_port": 56301, "imu_data_port"  : 56401, "log_data_port"  : 56501
    }]
  },
  "lidar_configs" : [{
    "ip" : "$LIDAR_IP", "pcl_data_type" : 1, "pattern_mode" : 0,
    "extrinsic_parameter" : { "roll": 0.0, "pitch": 0.0, "yaw": 0.0, "x": 0, "y": 0, "z": 0 }
  }]
}
EOF

# MID360 配置
cat > "$CONFIG_DIR/MID360_config.json" << EOF
{
  "lidar_summary_info" : { "lidar_type": 8 },
  "MID360": {
    "lidar_net_info" : {
      "cmd_data_port": 56100, "push_msg_port": 56200,
      "point_data_port": 56300, "imu_data_port": 56400, "log_data_port": 56500
    },
    "host_net_info" : {
      "cmd_data_ip" : "$HOST_IP", "cmd_data_port": 56101,
      "push_msg_ip": "$HOST_IP", "push_msg_port": 56201,
      "point_data_ip": "$HOST_IP", "point_data_port": 56301,
      "imu_data_ip" : "$HOST_IP", "imu_data_port": 56401,
      "log_data_ip" : "", "log_data_port": 56501
    }
  },
  "lidar_configs" : [{
    "ip" : "$LIDAR_IP", "pcl_data_type" : 1, "pattern_mode" : 0,
    "extrinsic_parameter" : { "roll": 0.0, "pitch": 0.0, "yaw": 0.0, "x": 0, "y": 0, "z": 0 }
  }]
}
EOF

cp "$CONFIG_DIR/MID360s_config.json" "$SRC_CONFIG_DIR/" 2>/dev/null || true
cp "$CONFIG_DIR/MID360_config.json" "$SRC_CONFIG_DIR/" 2>/dev/null || true

if [ ! -f "$LAUNCH_FILE" ]; then
    echo "[ERROR] 未找到 Livox ROS2 launch 文件"
    echo "  checked: $LIVOX_WS/install/livox_ros_driver2/share/livox_ros_driver2/launch/msg_MID360s_launch.py"
    echo "  checked: $LIVOX_WS/install/livox_ros_driver2/share/livox_ros_driver2/launch_ROS2/msg_MID360s_launch.py"
    exit 1
fi

echo "[OK] 网口=$IFACE 雷达=$LIDAR_IP 主机=$HOST_IP"
echo ""
echo "=========================================="
echo "  Topics: /livox/lidar, /livox/imu"
echo "  Ctrl+C 退出"
echo "=========================================="
echo ""

source /opt/ros/jazzy/setup.bash
source "$LIVOX_WS/install/setup.bash"
ros2 launch "$LAUNCH_FILE"
