# R66S OpenWrt 固件

基于 GitHub Actions 自动编译的 R66S 固件，支持 ImmortalWrt 和 LEDE 双分支。

## 固件类型

| 类型 | 源码 | 分支 | 适用设备 |
|------|------|------|----------|
| ImmortalWrt (r66s) | [immortalwrt](https://github.com/immortalwrt/immortalwrt) | openwrt-24.10 | FastRhino R66S |
| LEDE (r66s) | [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede) | master | FastRhino R66S |
| ImmortalWrt (flippy) | [immortalwrt](https://github.com/immortalwrt/immortalwrt) | openwrt-24.10 | ARMv8 通用 |
| LEDE (flippy) | [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede) | master | ARMv8 通用 |

## 内置插件

| 分类 | 插件 |
|------|------|
| 网络代理 | [OpenClash](https://github.com/vernesong/OpenClash)、[Passwall](https://github.com/Openwrt-Passwall/openwrt-passwall)、[SSR Plus+](https://github.com/fw876/helloworld) |
| DNS 服务 | [MosDNS](https://github.com/sbwml/luci-app-mosdns)、[AdGuard Home](https://github.com/AdguardTeam/AdGuardHome) |
| 内网穿透 | [DDNSTO](https://github.com/linkease/nas-packages) |
| 系统工具 | TTYD 终端 |
| ARMv8 专属 | [luci-app-amlogic](https://github.com/ophub/luci-app-amlogic)（仅 flippy） |

## 默认配置

| 项目 | 值 |
|------|-----|
| 管理 IP | `192.168.100.1` |
| 用户名 | `root` |
| 密码 | `password` |
| 默认主题 | Argon |
| 主机名 | `OpenWrt` |

## 触发编译

- **手动触发**: Actions → Build OpenWrt for R66S → Run workflow
- **Star 触发**: 对本仓库点 Star
- **定时触发**: 每日 UTC 20:00（北京时间次日 04:00）自动编译
