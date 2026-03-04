#!/bin/sh

# 只执行一次，成功后打标记
if [ -f /etc/rootfs-expanded ]; then
    exit 0
fi

# 找到 root 所在的分区 (参考 openwrt_packit 的实现)
ROOT_PTNAME=$(df / | tail -n1 | awk '{print $1}' | awk -F '/' '{print $3}')
if [ "$ROOT_PTNAME" == "" ] || [ "$ROOT_PTNAME" == "root" ] || [ "$ROOT_PTNAME" == "overlay" ]; then
    ROOT_PTNAME=$(awk '$2 == "/rom" {print $1}' /proc/mounts | awk -F '/' '{print $3}')
fi

if [ -z "$ROOT_PTNAME" ]; then
    echo "找不到根文件系统对应的分区!"
    exit 1
fi

# 找到分区所在的磁盘
case $ROOT_PTNAME in 
       mmcblk?p[0-9]*) DISK_NAME=$(echo $ROOT_PTNAME | awk '{print substr($1, 1, length($1)-2)}');;
           nvme?n?p?) DISK_NAME=$(echo $ROOT_PTNAME | awk '{print substr($1, 1, length($1)-2)}');;
   [hsv]d[a-z][0-9]*) DISK_NAME=$(echo $ROOT_PTNAME | awk '{print substr($1, 1, length($1)-1)}');;
                   *) echo "无法识别 $ROOT_PTNAME 的磁盘类型!"
                      exit 1
                   ;;
esac

PART_NUM=$(echo $ROOT_PTNAME | grep -o -E '[0-9]+$')

if [ -n "$DISK_NAME" ] && [ -n "$PART_NUM" ]; then
    # 扩容分区表
    if command -v parted >/dev/null; then
        parted -s "/dev/$DISK_NAME" resizepart "$PART_NUM" 100%
    elif command -v fdisk >/dev/null; then
        echo -e "d\n$PART_NUM\nn\np\n$PART_NUM\n\n\nw\n" | fdisk "/dev/$DISK_NAME"
    fi

    # 刷新分区缓存让内核重新识别容量
    partprobe "/dev/$DISK_NAME" 2>/dev/null || blockdev --rereadpt "/dev/$DISK_NAME" 2>/dev/null || true

    # 扩容文件系统本身
    if command -v resize2fs >/dev/null; then
        resize2fs "/dev/$ROOT_PTNAME" 2>/dev/null
    fi

    # 成功，打上只执行一次的标记
    touch /etc/rootfs-expanded
fi

exit 0
