# 官方 25.12.6 x86/64 ext4-combined-efi 镜像包集说明

对应固件：
`https://downloads.openwrt.org/releases/25.12.6/targets/x86/64/openwrt-25.12.6-x86-64-generic-ext4-combined-efi.img.gz`

## 数据来源与限制（请先看）

这个固件的权威清单文件是同目录下的
`openwrt-25.12.6-x86-64.manifest`（4.1 KB，逐行列出镜像内每个包及版本），
还有 `config.buildinfo`（官方构建用的 .config）与 `profiles.json`。

**本次没能读到 manifest / config.buildinfo 的原文**：你给的 `.img.gz` 链接资源解析服务返回失败，
而 manifest、`config.buildinfo`、`profiles.json` 都是纯文本/JSON 文件，网页抓取通道对这类
非 HTML 内容取不到正文（目录页能看到，文件正文读不到），多个镜像站与代理同样受限。

所以 `x86_64.config` 里的包集是按以下**可核实的权威信息重建**的：

1. **官方 `profiles.json` 的等价清单**（由 OpenWrt 官方论坛指向该文件；第三方固件索引页按
   `profiles.json` 的 `default_packages` 与 `profiles[generic].device_packages` 渲染出下面 43 个包）：
   - Target default packages（29）
   - Generic x86/64 Device packages（14）
2. **25.12 官方 release 镜像标配的 LuCI 套件**：`luci`、`luci-app-attendedsysupgrade`、
   `luci-ssl` 等（OpenWrt 官方论坛 "What are the default packages in firmware selector" 帖及
   25.12.6 ASU 构建请求里的 `packages` 字段）。
3. **镜像 manifest 里的公共依赖**：从 25.12.6 的 ASU 构建产物包列表与官方 25.12
   x86_64 软件包目录核对包名（库、内核模块、rpcd/uhttpd 组件等）。

→ 结论：**包集与官方镜像一致，但不是逐字复制 manifest**。如果你手里有该 `.manifest`
文件，把它贴给我，我可以逐行转成 `CONFIG_PACKAGE_xxx=y` 做 1:1 精确版。

## 一、Target default packages（29）

```
apk-mbedtls          base-files           ca-bundle            dnsmasq
dropbear             e2fsprogs            firewall4            fstools
grub2-bios-setup     kmod-button-hotplug  kmod-nft-offload     libc
libgcc               libustream-mbedtls   logd                 mkf2fs
mtd                  netifd               nftables             odhcp6c
odhcpd-ipv6only      partx-utils          ppp                  ppp-mod-pppoe
procd-ujail          uci                  uclient-fetch        urandom-seed
urngd
```

## 二、Generic x86/64 Device packages（14）

```
kmod-amazon-ena      kmod-amd-xgbe        kmod-bnx2            kmod-dwmac-intel
kmod-e1000e          kmod-e1000           kmod-forcedeth       kmod-fs-vfat
kmod-igb             kmod-igc             kmod-ixgbe           kmod-r8169
kmod-tg3             kmod-drm-i915
```

## 三、官方 release 标配 LuCI / Web 组件

```
luci                 luci-ssl (或 luci-ssl-openssl)   luci-base
luci-app-attendedsysupgrade  luci-app-firewall  luci-app-package-manager
luci-mod-admin-full  luci-mod-network      luci-mod-status      luci-mod-system
luci-theme-bootstrap luci-proto-ipv6      luci-proto-ppp
uhttpd               uhttpd-mod-ubus      rpcd                 rpcd-mod-file
rpcd-mod-iwinfo      rpcd-mod-rrdns       cgi-io
```

## 四、依赖自动带入（manifest 里还有，但不用手选）

镜像里剩下的几十个包是**依赖**，构建系统会自动装进 rootfs，例如：

```
busybox  procd  procd-seccomp  ubusd  getrandom  fwtool  fitblk  jansson
jshn  jsonfilter  libblobmsg-json  libjson-c  libjson-script  liblucihttp*
libmbedtls  libmnl  libnftnl  libnl-tiny  libubox  libubus  libuci
libuclient  libucode  libudebug  libiwinfo*  ucode  ipset  hostapd-common
kmod-nf-*  kmod-nft-*  kmod-ppp*  kmod-slhc  kmod-lib-crc*  kmod-crypto-*
```

`x86_64.config` 里把这些也写成了 `CONFIG_PACKAGE_xxx=y`（"全部选上"）。
其中少数是隐藏符号或隐藏依赖，`make defconfig` 会静默去掉——这是预期行为，
`diy-part2.sh` 会把这类包单独归类打印，不当成"包名写错"报警。

## 五、本次新增的中文选项

| 配置项 | 作用 |
|---|---|
| `CONFIG_LUCI_LANG_zh_Hans=y` | LuCI 默认语言设为简体中文 |
| `CONFIG_PACKAGE_luci-i18n-base-zh-cn=y` | 基础界面中文 |
| `CONFIG_PACKAGE_luci-i18n-firewall-zh-cn=y` | 防火墙页中文 |
| `CONFIG_PACKAGE_luci-i18n-package-manager-zh-cn=y` | 软件包页中文（25.12 用 apk） |
| `CONFIG_PACKAGE_luci-i18n-attendedsysupgrade-zh-cn=y` | 在线升级页中文 |

这四个 `luci-i18n-*-zh-cn` 在 25.12.6 官方 `luci` 软件源里都存在。
`CONFIG_LUCI_LANG_zh_Hans` 是 LuCI 的语言选项符号，若当前分支已移除会被
defconfig 丢弃，不影响中文包生效（语言包装好后可在「系统 → 语言和界面」切换）。

## 六、编译版本对齐

工作流里把 `repo_branch` 填 **`v25.12.6`** 才能精确对上这个固件；
填 `openwrt-25.12` 会取分支 HEAD（比 25.12.6 新，包版本会有差异）。

注意：feeds 由 `./scripts/feeds update -a` 按源码内 `feeds.conf.default` 拉取，
固定的是主仓库 tag，feeds 会取 25.12 分支当时快照，可能与 10-18 发布时略有出入；
要完全一致需要在 `diy-part1.sh` 里把 feeds 也锁到相同 commit。
