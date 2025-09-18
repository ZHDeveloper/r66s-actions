#!/bin/bash
set -e

# Set default theme
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Set default IP (192.168.100.1)
sed -i 's/192.168.1.1/192.168.100.1/g' package/base-files/files/bin/config_generate
if [ -f "package/base-files/luci2/bin/config_generate" ]; then
    sed -i 's/192.168.1.1/192.168.100.1/g' package/base-files/luci2/bin/config_generate
fi

# Set default password (password)
sed -i 's/root:::0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.:0:0:99999:7:::/g' package/base-files/files/etc/shadow

# Configure ttyd to auto-login as root
sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config

# Modify TTYD Chinese translation
sed -i 's/\"终端\"/\"TTYD 终端\"/g' feeds/luci/applications/luci-app-ttyd/po/zh_Hans/ttyd.po

# Add build timestamp
echo "Built on $(TZ=UTC-8 date "+%Y-%m-%d %H:%M:%S")" >> package/base-files/files/etc/banner

# 内核版本设置 - 不同固件使用不同内核版本
if [[ "$FIRMWARE_TYPE" == "LEDE" ]]; then
    # LEDE使用6.12内核
    sed -i "s/KERNEL_PATCHVER:=*.*/KERNEL_PATCHVER:=6.12/g" target/linux/rockchip/Makefile
    sed -i "s/KERNEL_TESTING_PATCHVER:=*.*/KERNEL_TESTING_PATCHVER:=6.12/g" target/linux/rockchip/Makefile
fi
# ImmortalWrt使用默认内核版本（不强制修改）
