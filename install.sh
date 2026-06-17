#!/bin/bash
# Livox 雷达环境一键安装
# 用法: sudo ./install.sh [网口名] [主机IP]
# 示例: sudo ./install.sh enp170s0 192.168.1.250
# 不传网口名则自动检测

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_USER="${SUDO_USER:-$(id -un)}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
if [ -z "$TARGET_HOME" ]; then
    TARGET_HOME="$HOME"
fi

IFACE="${1:-}"
if [ -z "$IFACE" ]; then
    IFACE=$("$SCRIPT_DIR/detect_iface.sh" 2>/dev/null || echo enp170s0)
    echo "[INFO] 自动检测网口: $IFACE"
fi
HOST_IP="${2:-192.168.1.250}"

echo "=========================================="
echo "  Livox 雷达环境一键安装"
echo "  网口: $IFACE  主机IP: $HOST_IP"
echo "=========================================="

# ------ Step 1: 系统依赖 ------
echo ""
echo "[1/5] 安装系统依赖..."
apt update -qq
apt install -y software-properties-common curl gnupg lsb-release cmake git libeigen3-dev tcpdump >/dev/null

# ------ Step 2: ROS2 Jazzy ------
echo "[2/5] 安装 ROS2 Jazzy..."
if [ ! -f /opt/ros/jazzy/setup.bash ]; then
    curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
        -o /usr/share/keyrings/ros-archive-keyring.gpg
    ARCH=$(dpkg --print-architecture)
    CODENAME=$(. /etc/os-release && echo $UBUNTU_CODENAME)
    echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu ${CODENAME} main" \
        > /etc/apt/sources.list.d/ros2.list
    apt update -qq
    apt install -y ros-jazzy-ros-base ros-jazzy-pcl-ros ros-jazzy-tf2-ros python3-colcon-common-extensions >/dev/null
    echo "  [OK] ROS2 Jazzy 已安装"
else
    echo "  [SKIP] ROS2 Jazzy 已存在: /opt/ros/jazzy/setup.bash"
fi

# ------ Step 3: Livox SDK2 ------
echo "[3/5] 安装 Livox SDK2..."
if [ -f /usr/local/lib/liblivox_lidar_sdk_shared.so ]; then
    echo "  [SKIP] Livox SDK2 已安装"
else
    TMPDIR=$(mktemp -d)
    cd "$TMPDIR"
    git clone --depth 1 https://github.com/Livox-SDK/Livox-SDK2.git >/dev/null 2>&1
    cd Livox-SDK2
    mkdir build && cd build
    cmake .. -DCMAKE_CXX_FLAGS="-include cstdint" >/dev/null 2>&1
    make -j$(nproc) >/dev/null 2>&1
    make install >/dev/null 2>&1
    ldconfig
    rm -rf "$TMPDIR"
    echo "  [OK] Livox SDK2 已安装"
fi

# ------ Step 4: livox_ros_driver2 ------
echo "[4/5] 安装 livox_ros_driver2..."
LIVOX_WS="${LIVOX_WS:-$TARGET_HOME/livox_ws}"
if [ -d "$LIVOX_WS/install/livox_ros_driver2" ]; then
    echo "  [SKIP] livox_ros_driver2 已安装"
else
    mkdir -p "$LIVOX_WS/src"
    cd "$LIVOX_WS/src"
    if [ ! -d livox_ros_driver2 ]; then
        git clone --depth 1 https://github.com/Livox-SDK/livox_ros_driver2.git >/dev/null 2>&1
    fi
    cd livox_ros_driver2
    ln -sf package_ROS2.xml package.xml
    cp -rf launch_ROS2/ launch/ 2>/dev/null || true
    source /opt/ros/jazzy/setup.bash
    cd "$LIVOX_WS"
    colcon build --cmake-args -DROS_EDITION=ROS2 -DDISTRO_ROS=jazzy --packages-select livox_ros_driver2 >/dev/null 2>&1
    echo "  [OK] livox_ros_driver2 已安装"
fi
if [ "$TARGET_USER" != "root" ]; then
    chown -R "$TARGET_USER:$TARGET_USER" "$LIVOX_WS"
fi

# ------ Step 5: 网络 + systemd service ------
echo "[5/5] 配置网络和开机自启动..."

CON_NAME=$(nmcli -t -f NAME,DEVICE con show | grep "$IFACE" | cut -d: -f1)
if [ -z "$CON_NAME" ]; then
    nmcli con add type ethernet ifname "$IFACE" con-name "livox-$IFACE" >/dev/null
    CON_NAME="livox-$IFACE"
fi
nmcli con mod "$CON_NAME" ipv4.addresses "${HOST_IP}/24" ipv4.method manual
nmcli con up "$CON_NAME" >/dev/null 2>&1

cat > /etc/systemd/system/livox-network.service << EOF
[Unit]
Description=Livox 雷达网口配置
After=NetworkManager.service
Wants=NetworkManager.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=${SCRIPT_DIR}/setup_network.sh ${IFACE} ${HOST_IP}

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable livox-network.service >/dev/null 2>&1
systemctl restart livox-network.service >/dev/null 2>&1
echo "  [OK] 网络已配置，开机自启动已启用"

# ------ 完成 ------
echo ""
echo "=========================================="
echo "  安装完成！"
echo "=========================================="
echo ""
echo "启动雷达:"
echo "  cd $SCRIPT_DIR"
echo "  ./start_lidar.sh"
echo ""
