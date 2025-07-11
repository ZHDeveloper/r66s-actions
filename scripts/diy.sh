#!/bin/bash
set -e

# Set default theme
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Set default IP (192.168.100.1)
sed -i '/n) ipad/s/".*"/"192.168.100.1"/' package/base-files/files/bin/config_generate

# Set default password (password)
sed -i 's/root:::0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.:0:0:99999:7:::/g' package/base-files/files/etc/shadow

# Configure ttyd to auto-login as root
sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config

# Modify TTYD Chinese translation
sed -i 's/\"终端\"/\"TTYD 终端\"/g' feeds/luci/applications/luci-app-ttyd/po/zh_Hans/ttyd.po

# Add build timestamp
echo "Built on $(TZ=UTC-8 date "+%Y-%m-%d %H:%M:%S")" >> package/base-files/files/etc/banner