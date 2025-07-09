#!/bin/bash
set -e

# 设置默认主题
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# 通用配置函数
configure_system() {
    local firmware_type="$1"
    local settings_file="package/lean/default-settings/files/zzz-default-settings"
    local config_file="package/base-files/files/bin/config_generate"

    # 设置默认密码 (password)
    sed -i 's/root:::0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.:0:0:99999:7:::/g' package/base-files/files/etc/shadow

    if [ "$firmware_type" = "LEDE" ]; then
        [ -f "$settings_file" ] && {
            sed -i 's/192.168.1.1/192.168.100.1/g' "$settings_file"
            grep -q "network.lan.ipaddr" "$settings_file" || {
                sed -i "2a uci set network.lan.ipaddr='192.168.100.1'" "$settings_file"
                sed -i "3a uci commit network" "$settings_file"
            }
            grep -q "CST-8" "$settings_file" || {
                echo "uci set system.@system[0].timezone='CST-8'" >> "$settings_file"
                echo "uci set system.@system[0].zonename='Asia/Shanghai'" >> "$settings_file"
                echo "uci commit system" >> "$settings_file"
            }
            sed -i "s/OpenWrt /OpenWrt $(TZ=UTC-8 date "+%Y.%m.%d") @ OpenWrt /g" "$settings_file"
        }
    else
        # ImmortalWrt 配置
        sed -i 's/192.168.1.1/192.168.100.1/g' "$config_file"
        sed -i 's/OpenWrt/ImmortalWrt/g' "$config_file"
        sed -i "s/'UTC'/'CST-8'/g" "$config_file"

        cat >> "$config_file" << EOF
uci set system.@system[0].timezone='CST-8'
uci set system.@system[0].zonename='Asia/Shanghai'
uci commit system
EOF

        [ -f "$settings_file" ] && \
            sed -i "s/OpenWrt /ImmortalWrt $(TZ=UTC-8 date "+%Y.%m.%d") @ ImmortalWrt /g" "$settings_file"
    fi

    # 添加编译时间戳
    echo "Built on $(TZ=UTC-8 date "+%Y-%m-%d %H:%M:%S")" >> package/base-files/files/etc/banner
}

# 执行配置
configure_system "$FIRMWARE_TYPE"