#!/bin/bash
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查必要的环境变量
check_env() {
    log_step "检查环境变量..."
    
    if [ -z "$PROFILE" ]; then
        log_error "PROFILE 环境变量未设置"
        exit 1
    fi
    
    log_info "Profile: $PROFILE"
    log_info "根文件系统大小: ${ROOTFS_PARTSIZE:-1024}MB"
    log_info "Docker 支持: ${INCLUDE_DOCKER:-yes}"
    log_info "Passwall: ✅ 默认启用"
    log_info "OpenClash: ✅ 默认启用"
    log_info "AdGuard Home: ✅ 默认启用"
    log_info "MosDNS: ✅ 默认启用"
}

# 构建包列表
build_package_list() {
    log_step "构建软件包列表..."
    
    # 基础包
    PACKAGES="base-files busybox ca-bundle dropbear firewall4 fstools kmod-gpio-button-hotplug"
    PACKAGES="$PACKAGES kmod-nft-offload libc libgcc libustream-mbedtls logd mtd netifd nftables"
    PACKAGES="$PACKAGES odhcp6c odhcpd-ipv6only opkg ppp ppp-mod-pppoe procd procd-seccomp procd-ujail"
    PACKAGES="$PACKAGES uci uclient-fetch urandom-seed urngd"
    
    # LuCI 基础
    PACKAGES="$PACKAGES luci luci-ssl-openssl luci-theme-bootstrap"
    
    # 常用工具
    PACKAGES="$PACKAGES curl wget nano htop iperf3 tcpdump ethtool"
    PACKAGES="$PACKAGES kmod-usb-storage kmod-usb2 kmod-usb3 block-mount"
    
    # 网络工具
    PACKAGES="$PACKAGES iptables-mod-tproxy iptables-mod-extra ipset"
    PACKAGES="$PACKAGES kmod-ipt-nat kmod-ipt-nat6 kmod-ipt-conntrack"
    
    # 主题
    PACKAGES="$PACKAGES luci-theme-argon"
    
    # 系统工具
    PACKAGES="$PACKAGES luci-app-ttyd ttyd"
    PACKAGES="$PACKAGES luci-app-autoreboot"
    PACKAGES="$PACKAGES luci-app-filetransfer"
    
    # 网络服务
    PACKAGES="$PACKAGES luci-app-upnp miniupnpd"
    PACKAGES="$PACKAGES luci-app-ddns ddns-scripts"
    
    # Docker 支持
    if [ "$INCLUDE_DOCKER" = "yes" ]; then
        log_info "添加 Docker 支持..."
        PACKAGES="$PACKAGES docker dockerd luci-app-dockerman"
        PACKAGES="$PACKAGES cgroupfs-mount containerd runc tini"
        PACKAGES="$PACKAGES kmod-veth kmod-bridge kmod-br-netfilter"
    fi
    
    # Passwall (默认启用)
    log_info "添加 Passwall..."
    PACKAGES="$PACKAGES luci-app-passwall"
    PACKAGES="$PACKAGES xray-core v2ray-geoip v2ray-geosite"
    PACKAGES="$PACKAGES shadowsocks-libev-ss-local shadowsocks-libev-ss-redir"
    PACKAGES="$PACKAGES simple-obfs v2ray-plugin"
    
    # OpenClash (默认启用)
    log_info "添加 OpenClash..."
    PACKAGES="$PACKAGES luci-app-openclash"
    PACKAGES="$PACKAGES coreutils-nohup bash dnsmasq-full curl ca-certificates"
    PACKAGES="$PACKAGES ipset ip-full iptables-mod-tproxy iptables-mod-extra"
    PACKAGES="$PACKAGES libcap libcap-bin ruby ruby-yaml kmod-tun"
    
    # AdGuard Home (默认启用)
    log_info "添加 AdGuard Home..."
    PACKAGES="$PACKAGES luci-app-adguardhome adguardhome"
    
    # MosDNS (默认启用)
    log_info "添加 MosDNS..."
    PACKAGES="$PACKAGES luci-app-mosdns mosdns"
    
    # 清理重复包
    PACKAGES=$(echo $PACKAGES | tr ' ' '\n' | sort -u | tr '\n' ' ')
    
    log_info "最终包列表: $PACKAGES"
}

# 配置根文件系统大小
configure_rootfs() {
    if [ -n "$ROOTFS_PARTSIZE" ]; then
        log_step "配置根文件系统大小为 ${ROOTFS_PARTSIZE}MB..."
        
        # 修改配置文件
        if [ -f ".config" ]; then
            sed -i "s/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=$ROOTFS_PARTSIZE/" .config
        fi
        
        # 或者通过 make menuconfig 的方式
        echo "CONFIG_TARGET_ROOTFS_PARTSIZE=$ROOTFS_PARTSIZE" >> .config
    fi
}

# 显示可用的 profiles
show_profiles() {
    log_step "显示可用的设备 profiles..."
    make info 2>/dev/null || log_warn "无法获取 profile 信息"
}

# 构建固件
build_firmware() {
    log_step "开始构建固件..."
    
    # 显示构建信息
    echo "=================================="
    echo "Profile: $PROFILE"
    echo "Root FS Size: ${ROOTFS_PARTSIZE:-1024}MB"
    echo "Package Count: $(echo $PACKAGES | wc -w)"
    echo "=================================="
    
    # 显示包列表（分行显示，便于阅读）
    log_info "包列表:"
    echo "$PACKAGES" | tr ' ' '\n' | sort | sed 's/^/  - /'
    echo "=================================="
    
    # 检查磁盘空间
    log_step "检查磁盘空间..."
    df -h . | tail -1 | awk '{print "可用空间: " $4}'
    
    # 执行构建
    log_step "执行 make image..."
    if timeout 3600 make image PROFILE="$PROFILE" PACKAGES="$PACKAGES" V=s; then
        log_info "✅ 固件构建成功！"
        
        # 显示生成的文件
        log_step "生成的固件文件:"
        if find bin/targets -name "*.img.gz" -o -name "*.bin" -o -name "*.img" | grep -q .; then
            find bin/targets -name "*.img.gz" -o -name "*.bin" -o -name "*.img" | while read file; do
                size=$(ls -lh "$file" | awk '{print $5}')
                log_info "  - $(basename "$file") ($size)"
            done
        else
            log_warn "未找到预期的固件文件"
            log_info "bin/targets 目录内容:"
            find bin/targets -type f | head -20
        fi
        
        return 0
    else
        log_error "❌ 固件构建失败 (可能超时或包冲突)"
        
        # 显示构建日志的最后几行
        log_step "构建日志 (最后 50 行):"
        tail -50 build.log 2>/dev/null || echo "无法读取构建日志"
        
        # 尝试使用最小包集合重新构建
        log_warn "尝试使用最小包集合重新构建..."
        MINIMAL_PACKAGES="luci luci-ssl-openssl luci-theme-bootstrap curl wget nano"
        
        if timeout 1800 make image PROFILE="$PROFILE" PACKAGES="$MINIMAL_PACKAGES" V=s; then
            log_warn "⚠️ 使用最小包集合构建成功"
            return 0
        else
            log_error "❌ 最小包集合构建也失败"
            
            # 最后尝试：只用基础包
            log_warn "最后尝试：只使用基础包..."
            BASIC_PACKAGES="luci"
            
            if timeout 1200 make image PROFILE="$PROFILE" PACKAGES="$BASIC_PACKAGES"; then
                log_warn "⚠️ 基础包构建成功"
                return 0
            else
                log_error "❌ 所有构建尝试都失败"
                return 1
            fi
        fi
    fi
}

# 主函数
main() {
    log_info "🚀 开始 R66S 固件构建流程..."
    
    # 检查环境
    check_env
    
    # 显示可用 profiles
    show_profiles
    
    # 构建包列表
    build_package_list
    
    # 配置根文件系统
    configure_rootfs
    
    # 构建固件
    if build_firmware; then
        log_info "🎉 构建流程完成！"
        exit 0
    else
        log_error "💥 构建流程失败！"
        exit 1
    fi
}

# 执行主函数
main "$@"