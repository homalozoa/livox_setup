# Livox 雷达一键配置工具

自动发现 Livox Mid-360/Mid-360s 雷达并适配 ROS2 驱动。

## 首次安装（新机器）

```bash
cd ~/livox_ws/src/livox_setup
sudo ./install.sh
```

一键完成：ROS2 Jazzy + Livox SDK2 + livox_ros_driver2 + 网络配置 + 开机自启动。

自定义参数：`sudo ./install.sh enp170s0 192.168.1.250`

## 日常使用

```bash
cd ~/livox_ws/src/livox_setup
./start_lidar.sh
```

自动发现雷达 IP → 生成配置 → 启动驱动。

## 脚本说明

| 脚本 | 功能 |
|------|------|
| `install.sh` | 首次安装所有依赖（需 sudo） |
| `start_lidar.sh` | 一键启动雷达 |
| `setup_network.sh` | 配置雷达网口静态 IP |
| `discover_lidar.sh` | 自动发现雷达 IP |

## 开机自启动

网口 IP 配置通过两种方式保证开机生效：

1. **NetworkManager** — `autoconnect: yes` + 静态 IP（主）
2. **livox-network.service** — systemd oneshot（备用）

```bash
sudo systemctl status livox-network.service
```

## 网络拓扑

```
[internet] --- enp171s0 (10.30.0.107)
[雷达]     --- enp170s0 (192.168.1.250) --- 192.168.1.115
```
