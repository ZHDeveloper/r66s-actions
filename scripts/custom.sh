#!/bin/bash
set -e

# Configure git to use GITHUB_TOKEN for HTTPS authentication
if [ -n "$GITHUB_TOKEN" ]; then
    git config --global url."https://x-access-token:${GITHUB_TOKEN}@github.com/".insteadOf "https://github.com/"
fi

# ── Helper functions (克隆即替换机制，参考 haiibo/build-openwrt) ───────────────
# 所有第三方包统一放 package/A；若 package/ feeds/ target/ 中已存在同名目录，
# 则删除旧目录并原地替换为新克隆版本（package/feeds/* 旧 symlink 的目标路径不变，
# 自动指向新内容）。从根上避免「同名 Package/* 定义后扫描者覆盖先扫描者」导致
# LuCI 界面与核心二进制版本错配 → 服务 crash loop 的系统性问题。

# 第三方包统一保存目录
[ -f rules.mk ] && [ -d package ] || { echo "错误: 当前目录不是 OpenWrt 源码根目录 (cwd=$PWD)"; exit 1; }
destination_dir="package/A"
mkdir -p "$destination_dir"

# 在 package/ feeds/ target/ 三棵树里查找同名目录（深度 ≤3，与 OpenWrt 包扫描深度一致）
# 注意 find 在任一搜索根缺失时会返回非 0，set -e 下会中断脚本，故统一吞掉退出码
find_dir() {
    find $1 -maxdepth 3 -type d -name "$2" -print -quit 2>/dev/null || true
}

# 整仓库作为一个包目录（适合单包仓库，如 packages_lang_golang）
# 用法: git_clone [branch] <repo_url> [target_dir]
git_clone() {
    local repo_url branch target_dir current_dir
    if [[ "$1" == */* ]]; then
        repo_url="$1"; shift
    else
        branch="-b $1 --single-branch"; repo_url="$2"; shift 2
    fi
    target_dir="${1:-${repo_url##*/}}"
    git clone -q $branch --depth=1 "$repo_url" "$target_dir"
    rm -rf $target_dir/{.git*,README*.md,LICENSE}
    current_dir=$(find_dir "package/ feeds/ target/" "$target_dir")
    if [[ -d "$current_dir" ]]; then
        rm -rf "$current_dir"
        mv -f "$target_dir" "${current_dir%/*}"
        echo "  [替换] $target_dir -> $current_dir"
    else
        mv -f "$target_dir" "$destination_dir"
        echo "  [添加] $target_dir -> $destination_dir"
    fi
}

# 只取仓库内指定子目录（可一次取多个，按目录名查找）
# 用法: clone_dir [branch] <repo_url> <subdir_name> [subdir_name...]
clone_dir() {
    local repo_url branch temp_dir=$(mktemp -d)
    if [[ "$1" == */* ]]; then
        repo_url="$1"; shift
    else
        branch="-b $1 --single-branch"; repo_url="$2"; shift 2
    fi
    git clone -q $branch --depth=1 "$repo_url" "$temp_dir"
    local target_dir source_dir current_dir
    for target_dir in "$@"; do
        source_dir=$(find_dir "$temp_dir" "$target_dir")
        [ -d "$source_dir" ] || source_dir=$(find "$temp_dir" -maxdepth 4 -type d -name "$target_dir" -print -quit 2>/dev/null || true)
        [ -d "$source_dir" ] || { echo "  [跳过] $target_dir 在 $repo_url 中未找到"; continue; }
        current_dir=$(find_dir "package/ feeds/ target/" "$target_dir")
        if [[ -d "$current_dir" ]]; then
            rm -rf "$current_dir"
            mv -f "$source_dir" "${current_dir%/*}"
            echo "  [替换] $target_dir -> $current_dir"
        else
            mv -f "$source_dir" "$destination_dir"
            echo "  [添加] $target_dir -> $destination_dir"
        fi
    done
    rm -rf "$temp_dir"
}

# 取仓库内全部一级子目录（排除 .github 等），逐个走替换逻辑
# 用法: clone_all [branch] <repo_url>
clone_all() {
    local repo_url branch temp_dir=$(mktemp -d)
    if [[ "$1" == */* ]]; then
        repo_url="$1"; shift
    else
        branch="-b $1 --single-branch"; repo_url="$2"; shift 2
    fi
    git clone -q $branch --depth=1 "$repo_url" "$temp_dir"
    local source_dir target_dir current_dir
    while IFS= read -r source_dir; do
        target_dir=$(basename "$source_dir")
        current_dir=$(find_dir "package/ feeds/ target/" "$target_dir")
        if [[ -d "$current_dir" ]]; then
            rm -rf "$current_dir"
            mv -f "$source_dir" "${current_dir%/*}"
            echo "  [替换] $target_dir -> $current_dir"
        else
            mv -f "$source_dir" "$destination_dir"
            echo "  [添加] $target_dir -> $destination_dir"
        fi
    done < <(find "$temp_dir" -maxdepth 1 -mindepth 1 -type d ! -name '.*')
    rm -rf "$temp_dir"
}

# ── Custom packages ───────────────────────────────────────────────────────────

clone_all https://github.com/fw876/helloworld
clone_all v5 https://github.com/sbwml/luci-app-mosdns
git_clone https://github.com/sbwml/packages_lang_golang golang
clone_all https://github.com/Openwrt-Passwall/openwrt-passwall-packages
clone_all https://github.com/Openwrt-Passwall/openwrt-passwall
clone_dir https://github.com/vernesong/OpenClash luci-app-openclash
clone_dir https://github.com/linkease/nas-packages-luci luci-app-ddnsto
clone_dir https://github.com/linkease/nas-packages ddnsto

if [[ "$CONFIG_FILE" == *"flippy"* ]]; then
    clone_dir https://github.com/ophub/luci-app-amlogic luci-app-amlogic
    config_file="$destination_dir/luci-app-amlogic/root/etc/config/amlogic"
    # 该文件不存在说明 amlogic 包结构变了，宁可构建失败也不要发布指向错误 OTA 仓库的固件
    [ -f "$config_file" ] || { echo "错误: 未找到 $config_file（luci-app-amlogic 结构可能已变化）"; exit 1; }
    sed -i "s|option amlogic_firmware_repo.*|option amlogic_firmware_repo 'https://github.com/$GITHUB_REPOSITORY'|g" "$config_file"
    sed -i "s|option amlogic_firmware_tag.*|option amlogic_firmware_tag '$RELEASE_TAG'|g" "$config_file"
fi

# 修复第三方包 Makefile 的相对路径引用（../../lang / ../../luci.mk 在 package/A 深度下失效）
find "$destination_dir" -type f -name "Makefile" | xargs -r sed -i \
    -e 's?\.\./\.\./\(lang\|devel\)?$(TOPDIR)/feeds/packages/\1?' \
    -e 's?\.\./\.\./luci.mk?$(TOPDIR)/feeds/luci/luci.mk?'

# 翻译目录 zh-cn / zh_Hans 互为软链，兼容新旧 LuCI 的 po 目录命名
for e in $destination_dir/luci-*/po feeds/luci/applications/luci-*/po; do
    [ -d "$e" ] || continue
    if [[ -d $e/zh-cn && ! -d $e/zh_Hans ]]; then
        ln -s zh-cn $e/zh_Hans 2>/dev/null || true
    elif [[ -d $e/zh_Hans && ! -d $e/zh-cn ]]; then
        ln -s zh_Hans $e/zh-cn 2>/dev/null || true
    fi
done

# ── Download binary cores ─────────────────────────────────────────────────────

# OpenClash core and geo files
[ -d files/etc/openclash/core ] || mkdir -p files/etc/openclash/core
wget -qO- https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz \
    | tar xOz > files/etc/openclash/core/clash_meta
wget -qO- https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geoip.dat    > files/etc/openclash/GeoIP.dat
wget -qO- https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geosite.dat  > files/etc/openclash/GeoSite.dat
wget -qO- https://raw.githubusercontent.com/alecthw/mmdb_china_ip_list/release/Country.mmdb   > files/etc/openclash/Country.mmdb
chmod +x files/etc/openclash/core/clash_meta

# ── DIY customizations ────────────────────────────────────────────────────────

# Set default theme
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Set default IP
sed -i 's/192.168.1.1/192.168.100.1/g' package/base-files/files/bin/config_generate
[ -f "package/base-files/luci2/bin/config_generate" ] && \
    sed -i 's/192.168.1.1/192.168.100.1/g' package/base-files/luci2/bin/config_generate

# Set default hostname
sed -i "s/hostname='.*'/hostname='OpenWrt'/g" package/base-files/files/bin/config_generate
[ -f "package/base-files/luci2/bin/config_generate" ] && \
    sed -i "s/hostname='.*'/hostname='OpenWrt'/g" package/base-files/luci2/bin/config_generate

# Set default password
sed -i 's/root:::0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.:0:0:99999:7:::/g' \
    package/base-files/files/etc/shadow

# Configure ttyd auto-login
sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config
sed -i 's/\"终端\"/\"TTYD 终端\"/g' feeds/luci/applications/luci-app-ttyd/po/zh_Hans/ttyd.po

# Add build timestamp
echo "Built on $(TZ=UTC-8 date "+%Y-%m-%d %H:%M:%S")" >> package/base-files/files/etc/banner
