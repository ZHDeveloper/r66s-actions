# R66S 固件自动编译

[![GitHub Stars](https://img.shields.io/github/stars/your-username/r66s-actions.svg?style=flat-square&label=Stars&logo=github)](https://github.com/your-username/r66s-actions/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/your-username/r66s-actions.svg?style=flat-square&label=Forks&logo=github)](https://github.com/your-username/r66s-actions/network)
[![GitHub License](https://img.shields.io/github/license/your-username/r66s-actions.svg?style=flat-square&label=License)](https://github.com/your-username/r66s-actions/blob/main/LICENSE)

## 📖 项目简介

这是一个专门为 **R66S 设备** 设计的 OpenWrt 固件自动编译项目，基于 GitHub Actions 支持 **ImmortalWrt 24.10** 和 **LEDE** 双分支编译。

### ✨ 主要特性

- 🚀 **双分支支持**: ImmortalWrt 24.10 + LEDE
- 🎯 **专为 R66S 优化**: 针对 FastRhino R66S 设备定制
- 🔧 **丰富插件集成**: AdGuardHome、OpenClash、Passwall、MosDNS 等
- 📦 **自动发布**: 编译完成自动发布到 GitHub Releases
- 🌐 **中文界面**: 默认中文界面，Argon 主题
- 🛡️ **预下载内核**: 预下载 AdGuardHome 和 OpenClash 内核避免编译时下载失败
- ⚡ **编译缓存**: 支持编译缓存加速构建过程
- 💾 **磁盘优化**: 使用 LVM + Btrfs 组合磁盘避免空间不足

### 🎯 支持的设备

- **R66S (FastRhino R66S)**: RK3568 ARM64 设备
  - CPU: RK3568 四核 ARM Cortex-A55
  - 内存: 1GB/2GB/4GB DDR4
  - 存储: eMMC + TF 卡
  - 网络: 双千兆网口

## 🚀 使用方法

### 方法一：Fork 本项目（推荐）

1. 点击右上角的 `Fork` 按钮，将本项目 Fork 到你的账户
2. 进入你 Fork 的项目，点击 `Actions` 标签页
3. 选择要编译的固件类型：
   - `Build ImmortalWrt for R66S` - ImmortalWrt 24.10 分支
   - `Build LEDE for R66S` - LEDE 分支
4. 点击 `Run workflow` 按钮开始编译

### 方法二：手动触发编译

#### ImmortalWrt 编译选项：
- **branch**: 选择 ImmortalWrt 分支（openwrt-24.10 或 master）
- **upload_release**: 是否上传到 Release（默认 true）
- **upload_artifacts**: 是否上传构建产物（默认 false）
- **ssh**: SSH 连接到 Actions（调试用，默认 false）

#### LEDE 编译选项：
- **upload_release**: 是否上传到 Release（默认 true）
- **upload_artifacts**: 是否上传构建产物（默认 false）
- **ssh**: SSH 连接到 Actions（调试用，默认 false）

## 📁 项目结构

```
.
├── .github/
│   └── workflows/
│       ├── build-immortalwrt.yml   # ImmortalWrt 构建工作流
│       └── build-lede.yml          # LEDE 构建工作流
├── configs/                        # R66S 设备配置文件
│   ├── r66s-imm.config             # ImmortalWrt R66S 配置
│   └── r66s-lede.config            # LEDE R66S 配置
├── scripts/                        # 自定义脚本
│   ├── diy.sh                      # 主要定制脚本
│   ├── download-custom-packages.sh # 自定义软件包下载
│   └── download-cores.sh           # 内核文件预下载
├── files/                          # 自定义文件（可选）
└── README.md                       # 项目说明
```

## ⚙️ 自定义配置

### 修改设备配置

1. 编辑 `configs/r66s-imm.config` (ImmortalWrt) 或 `configs/r66s-lede.config` (LEDE)
2. 添加或删除需要的软件包配置
3. 提交更改并重新运行对应的 workflow

### 添加自定义插件

1. 编辑 `scripts/download-custom-packages.sh` 添加新的软件包源
2. 在对应的 `.config` 文件中启用插件
3. 如需要，可在 `scripts/diy.sh` 中添加额外配置

### 自定义文件

将需要添加到固件中的文件放入 `files/` 目录，保持相对于根目录的路径结构。

### 预下载内核

项目会自动预下载以下内核文件避免编译时下载失败：
- **AdGuard Home**: ARM64 版本
- **OpenClash Meta**: ARM64 版本

## 🔧 内置插件

### ImmortalWrt 版本插件

#### 核心功能
- **luci-app-adguardhome**: AdGuard Home 广告拦截
- **luci-app-dockerman**: Docker 容器管理
- **luci-app-netdata**: 系统监控
- **luci-app-ttyd**: Web 终端
- **luci-app-zerotier**: ZeroTier 虚拟局域网

#### 代理工具
- **luci-app-passwall**: 全功能代理工具（支持多种协议）
- **luci-app-openclash**: OpenClash 代理工具
- **luci-app-ssr-plus**: SSR Plus+ 代理工具
- **luci-app-mihomo**: Mihomo 代理内核

#### 网络工具
- **luci-app-mosdns**: MosDNS DNS 分流
- **luci-app-frpc/frps**: FRP 内网穿透
- **luci-app-diskman**: 磁盘管理

### LEDE 版本插件

LEDE 版本包含上述所有插件，并额外保留了一些传统插件以保持兼容性。

### 主题

- **luci-theme-argon**: 默认使用 Argon 主题

## 📋 编译说明

### 编译环境

- Ubuntu 22.04 LTS
- 构建时间：约 2-4 小时（取决于设备和网络）
- 磁盘空间：至少 50GB

### 默认设置

- **默认 IP**: 192.168.100.1
- **默认用户名**: root
- **默认密码**: password
- **默认主题**: Argon
- **时区**: Asia/Shanghai (CST-8)
- **主机名**: ImmortalWrt (ImmortalWrt) / OpenWrt (LEDE)

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进这个项目。

## 📄 许可证

本项目基于 [GPL-3.0](LICENSE) 许可证开源。

## 🙏 致谢

- [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) - 优秀的 OpenWrt 分支
- [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt) - GitHub Actions 模板
- [OpenWrt](https://openwrt.org/) - 开源路由器固件项目

## ⚠️ 免责声明

- 本项目仅供学习和研究使用
- 使用本项目编译的固件可能存在风险，请谨慎使用
- 作者不对使用本项目造成的任何损失负责
