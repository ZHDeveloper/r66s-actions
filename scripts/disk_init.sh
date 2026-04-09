#!/bin/bash
# disk_init.sh — 首次启动自动扩容脚本
# 适配: r66s / r68s (RK3568 / RK3568B2)
# 来源参考: https://github.com/unifreq/openwrt_packit/blob/master/files/first_run.sh
#
# 分区布局 (最终):
#   SKIP | p1:BOOT | p2:ROOT1 | p3:ROOT2(备用升级槽) | p4:SHARED(剩余→Docker)
#
# 调用方式: /etc/disk_init.sh >/root/disk_init.log 2>&1
# 依赖工具: parted, btrfs-progs, e2fsprogs, jq (dockerman UCI 同步)

SENTINEL_FILE="/etc/disk_init.done"
PART_SIZE_FILE="/etc/part_size"

die() { echo "[disk_init] ERROR: $*"; exit 1; }

# ── 幂等检查 ──────────────────────────────────────────────────────────────────
[ -f "$SENTINEL_FILE" ] && { echo "[disk_init] 已初始化，跳过"; exit 0; }
[ -f "$PART_SIZE_FILE" ] || die "$PART_SIZE_FILE 不存在"

# ── 识别磁盘及分区前缀 ────────────────────────────────────────────────────────
ROOT_PTNAME=$(df / | awk 'NR==2{print $1}' | awk -F'/' '{print $NF}')
[ -n "$ROOT_PTNAME" ] || die "无法识别根文件系统分区"

case "$ROOT_PTNAME" in
    mmcblk?p[1-9]) DISK_NAME="${ROOT_PTNAME%p[1-9]}"; PT_PRE="${DISK_NAME}p"; LB_PRE="MMC_"  ;;
    nvme?n?p[1-9]) DISK_NAME="${ROOT_PTNAME%p[1-9]}"; PT_PRE="${DISK_NAME}p"; LB_PRE="NVME_" ;;
    [hsv]d[a-z]*)  DISK_NAME="${ROOT_PTNAME%%[0-9]*}"; PT_PRE="${DISK_NAME}"; LB_PRE=""      ;;
    *)              die "无法识别磁盘类型: $ROOT_PTNAME" ;;
esac
echo "[disk_init] 根分区: /dev/${ROOT_PTNAME}  磁盘: /dev/${DISK_NAME}"

# ── 分区数检查（兼容手动分区场景）───────────────────────────────────────────
PT_CNT=$(parted /dev/"${DISK_NAME}" print | awk '$1~/^[0-9]+$/{c++}END{print c+0}')
[ "$PT_CNT" = "2" ] || { echo "[disk_init] 分区数为 ${PT_CNT}（非初始状态），跳过"; exit 0; }

# ── 读取打包时写入的分区参数 ──────────────────────────────────────────────────
read -r SKIP_MiB BOOT_MiB ROOTFS_MiB <<EOF
$(awk '{print $1, $2, $3}' "$PART_SIZE_FILE")
EOF
case "${SKIP_MiB}${BOOT_MiB}${ROOTFS_MiB}" in
    *[!0-9]*|'') die "${PART_SIZE_FILE} 内容无效: '${SKIP_MiB} ${BOOT_MiB} ${ROOTFS_MiB}'" ;;
esac

DISK_TOTAL_B=$(lsblk -b -l | awk -v d="$DISK_NAME" '$1==d && $6=="disk" {print $4}')
[ -n "$DISK_TOTAL_B" ] || die "无法读取磁盘总大小"

USED_MiB=$(( SKIP_MiB + BOOT_MiB + ROOTFS_MiB + 1 ))
AVAIL_MiB=$(( DISK_TOTAL_B / 1024 / 1024 - USED_MiB ))
echo "[disk_init] 磁盘总计: $((DISK_TOTAL_B / 1024 / 1024)) MiB  可用: ${AVAIL_MiB} MiB"

[ "$AVAIL_MiB" -lt "$ROOTFS_MiB" ] && \
    die "可用空间 (${AVAIL_MiB} MiB) 不足，需要至少 ${ROOTFS_MiB} MiB"

# ── 修复分区表以适配实际介质大小 ─────────────────────────────────────────────
printf 'f\n' | parted ---pretend-input-tty /dev/"${DISK_NAME}" print \
    || die "parted fix 失败"

# ── 格式化辅助函数 ────────────────────────────────────────────────────────────
# make_fs <fstype> <label> <device> <mount_point>
make_fs() {
    local fstype=$1 label=$2 dev=$3 mnt=$4 mtype=$1
    case "$fstype" in
        btrfs) mkfs.btrfs -f -L "$label" "$dev" || die "mkfs.btrfs $dev 失败" ;;
        xfs)   mkfs.xfs   -f -L "$label" "$dev" || die "mkfs.xfs $dev 失败" ;;
        *)     mkfs.ext4  -F -L "$label" "$dev" || die "mkfs.ext4 $dev 失败"; mtype=ext4 ;;
    esac
    mkdir -p "$mnt"
    mount -t "$mtype" "$dev" "$mnt" || die "mount $dev 失败"
}

TARGET_ROOTFS2_FSTYPE="${ROOTFS2_FSTYPE:-btrfs}"
TARGET_SHARED_FSTYPE="${SHARED_FSTYPE:-btrfs}"

# ── 新建 p3: ROOTFS2 + p4: SHARED ────────────────────────────────────────────
START_P3=$(( (SKIP_MiB + BOOT_MiB + ROOTFS_MiB) * 1024 * 1024 ))
END_P3=$(( START_P3 + ROOTFS_MiB * 1024 * 1024 - 1 ))
START_P4=$(( END_P3 + 1 ))

parted -s /dev/"${DISK_NAME}" mkpart primary "${TARGET_ROOTFS2_FSTYPE}" "${START_P3}b" "${END_P3}b" \
    || die "parted mkpart p3 失败"
parted -s /dev/"${DISK_NAME}" mkpart primary "${TARGET_SHARED_FSTYPE}"  "${START_P4}b" "100%" \
    || die "parted mkpart p4 失败"

partprobe /dev/"${DISK_NAME}" 2>/dev/null || true; sleep 1
parted /dev/"${DISK_NAME}" unit MiB print

make_fs "$TARGET_ROOTFS2_FSTYPE" "${LB_PRE}ROOTFS2" "/dev/${PT_PRE}3" "/mnt/${PT_PRE}3"
make_fs "$TARGET_SHARED_FSTYPE"  "${LB_PRE}SHARED"  "/dev/${PT_PRE}4" "/mnt/${PT_PRE}4"

# ── 初始化 Docker ─────────────────────────────────────────────────────────────
[ -f /etc/init.d/dockerman ] && /etc/init.d/dockerman stop 2>/dev/null
/etc/init.d/dockerd stop    2>/dev/null || true
/etc/init.d/dockerd disable 2>/dev/null || true

mkdir -p "/mnt/${PT_PRE}4/docker"
rm -rf /opt/docker
ln -sf "/mnt/${PT_PRE}4/docker/" /opt/docker

cat > /etc/docker/daemon.json <<EOF
{
  "bip": "172.31.0.1/24",
  "data-root": "/mnt/${PT_PRE}4/docker/",
  "log-level": "warn",
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "5" },
  "registry-mirrors": ["https://mirror.baidubce.com/", "https://hub-mirror.c.163.com"]
}
EOF

/etc/init.d/dockerd enable  2>/dev/null || true
/etc/init.d/dockerd start   2>/dev/null || true

# 同步 dockerman UCI 配置（若存在且 jq 可用）
if [ -f /etc/init.d/dockerman ] && [ -x /usr/bin/jq ]; then
    data_root=$(jq -r '."data-root"'          /etc/docker/daemon.json)
    bip=$(jq -r '."bip" // "172.31.0.1/24"'  /etc/docker/daemon.json)
    log_level=$(jq -r '."log-level" // "warn"' /etc/docker/daemon.json)
    _iptables=$(jq -r '."iptables" // "true"'  /etc/docker/daemon.json)

    uci -q get dockerd.globals >/dev/null 2>&1 || { uci set dockerd.globals='globals'; uci commit; }
    uci delete dockerd.globals.alt_config_file 2>/dev/null || true
    [ -n "$data_root" ] && uci set dockerd.globals.data_root="$data_root"
    [ -n "$bip"       ] && uci set dockerd.globals.bip="$bip"
    [ -n "$log_level" ] && uci set dockerd.globals.log_level="$log_level"
    [ -n "$_iptables" ] && uci set dockerd.globals.iptables="$_iptables"

    # registry-mirrors 作为列表同步
    while IFS= read -r reg; do
        [ -n "$reg" ] && uci add_list dockerd.globals.registry_mirrors="$reg"
    done <<EOF
$(jq -r '."registry-mirrors"[]' /etc/docker/daemon.json 2>/dev/null)
EOF

    uci set dockerd.globals.auto_start='1'
    uci commit

    /etc/init.d/dockerman enable 2>/dev/null || true
    /etc/init.d/dockerman start  2>/dev/null || true
fi

# ── 更新 NFS 配置（若已安装）─────────────────────────────────────────────────
if [ -f /etc/exports ]; then
    cat > /etc/exports <<EOF

/mnt     *(ro,fsid=0,sync,nohide,no_subtree_check,insecure,no_root_squash)
/mnt/${PT_PRE}4  *(rw,fsid=1,sync,no_subtree_check,no_root_squash)
EOF
fi

if [ -f /etc/config/nfs ]; then
    cat > /etc/config/nfs <<EOF
config share
        option clients '*'
        option enabled '1'
        option path '/mnt'
        option options 'ro,fsid=0,sync,nohide,no_subtree_check,insecure,no_root_squash'

config share
        option enabled '1'
        option path '/mnt/${PT_PRE}4'
        option clients '*'
        option options 'rw,fsid=1,sync,no_subtree_check,no_root_squash'
EOF
fi

sync
touch "$SENTINEL_FILE"
echo "[disk_init] 完成！"
