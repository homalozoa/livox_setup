# Livox 雷达一键配置工具

自动发现 Livox Mid-360/Mid-360s 雷达并适配 ROS2 驱动。

## 快速开始

```bash
cd ~/livox_ws/src/livox_setup
./start_lidar.sh
```

## 脚本说明

| 脚本 | 功能 |
|------|------|
| `setup_network.sh` | 配置雷达网口静态 IP |
| `discover_lidar.sh` | 自动发现雷达 IP |
| `start_lidar.sh` | 一键启动（网络配置 + 雷达发现 + 驱动启动） |

## 参数

```bash
./start_lidar.sh [网口名] [主机IP]
# 默认: enp170s0, 192.168.1.250
```

## 开机自启动

网络配置已通过 systemd 服务 `livox-network.service` 实现开机自启动。

```bash
# 查看服务状态
sudo systemctl status livox-network.service

# 手动启停
sudo systemctl start livox-network.service
sudo systemctl stop livox-network.service
```

## 依赖

- ROS2 Jazzy
- Livox SDK2 (`/usr/local/lib/liblivox_lidar_sdk_shared.so`)
- livox_ros_driver2 (`~/livox_ws`)

## 网络拓扑

```
[internet] --- enp171s0 (10.30.0.107)
[雷达]     --- enp170s0 (192.168.1.250) --- 192.168.1.115
```
