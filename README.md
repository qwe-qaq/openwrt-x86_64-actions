# 用 GitHub Actions 编译 OpenWrt 官方 x86/64 固件

基于 yhlh9982/Actions-OpenWrt-MT798X 所用的 P3TERX 云编译模板结构改写，源码改为官方 `openwrt/openwrt`，目标改为 x86/64（软路由 / 虚拟机 / 工控机）。

## 文件结构

```
.github/workflows/build-openwrt-x86_64.yml   # 主工作流
x86_64.config                               # 最小 .config，交给 make defconfig 展开
diy-part1.sh                                # feeds update 之前执行（可换 feeds / 加插件源）
diy-part2.sh                                # 载入 .config 之后执行（补 LuCI、跑 defconfig）
README.md
```

## 快速开始

1. 新建（或 fork）一个 GitHub 仓库，把上面文件按相同路径放到**仓库根目录**，尤其不要改 `.github/workflows/` 这个路径。
2. 进入 `Actions` → `Build OpenWrt x86_64 (Official)` → `Run workflow`。
3. 参数说明：
   - `repo_branch`：源码分支或 tag，默认 `openwrt-25.12`（当前稳定系列）；可填 `openwrt-24.10`、`main`（snapshot）或 `v25.12.5` 之类的发布 tag 来锁定版本。
   - `upload_release`：是否同时发到本仓库 Releases（默认开）；`ssh`：调试用，默认关。
4. 编译完成后在 Actions 的 **Artifacts** 下载 `OpenWrt-x86_64-*`，或在 **Releases** 下载。

## 产物

输出目录为 `openwrt/bin/targets/x86/64/`，常见文件：

- `*-generic-ext4-combined.img.gz` / `*-generic-ext4-combined-efi.img.gz`：ext4 可写根分区，适合软路由，可扩容
- `*-generic-squashfs-combined.img.gz` / `*-generic-squashfs-combined-efi.img.gz`：squashfs + overlay，支持重置
- `*-rootfs.img.gz`、`*-initramfs-kernel.bin` 等

x86 平台没有 `factory` / `sysupgrade` 之分，升级时写回同类型镜像即可。

## 与原模板的差异

| 项 | 原模板（MT798X） | 本工作流 |
|---|---|---|
| `REPO_URL` | hanwckf / padavanonly 等 immortalwrt-mt798x 分支 | `https://github.com/openwrt/openwrt` |
| `REPO_BRANCH` | 21.02 / 24.10 / 25.12 的 MT798X 专用分支 | 官方 `openwrt-25.12`（可切 24.10 / main / tag） |
| `CONFIG_FILE` | 各机型 `.config`（含闭源 WiFi 驱动） | `x86_64.config`，仅 x86/64 + 通用镜像格式 |
| feeds | 带 iStore / 第三方插件 | 使用官方源码自带的 `feeds.conf.default` |
| 机型 | wr30u / Q30 / x60 / uax3000e 等 MT798X | Generic x86/64 |

官方源码不含 Lean / ImmortalWrt 的插件，若需要第三方软件包，在 `diy-part1.sh` 里追加 `src-git` 源，并在 `x86_64.config` 末尾加 `CONFIG_PACKAGE_xxx=y`。

## 关于"插件"

`x86_64.config` 现在预置了约 90 个**官方 feeds 里确实存在**的包：LuCI 中文、DDNS / SQM / UPnP / Adblock / banIP / SmartDNS / DoH / FRP / OpenVPN / WireGuard 协议、Statistics / nlbwmon / vnstat2 监控、ttyd / WOL / watchcat / irqbalance、常用命令行工具，以及 x86 网卡 / SATA / USB / 文件系统驱动。

官方四个 feeds 是 `packages / luci / routing / telephony`，官方 LuCI 应用有上百个，但**没有**这些常见第三方插件：

`luci-app-openclash`、`luci-app-passwall`、`luci-app-ssr-plus`、`luci-app-homeproxy`、`luci-app-istore`、`luci-app-quickstart`、`luci-app-diskman`、`luci-app-ddns-go`、`luci-theme-argon`、`luci-app-linkease`、`luci-app-lucky`、`luci-app-mosdns`。

它们不在官方源里，写进 `.config` 也不会报错，只会被 `make defconfig` **静默丢弃**——这就是"编译成功但后台没插件"的最常见原因。为此 `diy-part2.sh` 在 `defconfig` 之后会对比原始 config，打印被丢弃的包名和实际生效的包数量，编译日志里搜 `[diy-part2]` 即可看到。

两个分支差异：`luci-app-package-manager` / `luci-i18n-package-manager-zh-cn` / `luci-proto-wireguard` 属于 25.12（apk 时代）的新包名；24.10 里没有的会被自动丢弃，不影响编译。25.12 起包管理器从 `opkg` 换成 `apk`，装包命令是 `apk add <包名>`。

## 注意事项

- `github.com/openwrt/openwrt` 是官方 Git 仓库的只读镜像，克隆编译完全没问题，只是 PR 不直接合入这里。
- `x86_64.config` 的 target / profile / EFI 部分只写最小必要项：不同 OpenWrt 分支里 x86/64 的 profile 符号名有变化（`TARGET_x86_64_Generic` / `TARGET_x86_64_DEVICE_generic`），交给 `make defconfig` 自动补全省去踩坑；EFI 相关符号同理，两个都写、由 defconfig 取舍。
- 默认开启 `luci` 与 `luci-ssl-openssl`，编译出来的镜像可直接进 Web 管理页；官方默认 LAN 地址为 `192.168.1.1`，未改密码。
- runner 固定 `ubuntu-22.04`（与模板一致）；若改 `ubuntu-24.04`，需把依赖里的 `python3-distutils` 换成等价包。
- 已声明 `permissions: contents: write`，发布 Releases 不需要额外 PAT；如需发到别的仓库，把 Release 那一步换成带 `repository:` 和 PAT 的配置。
- 首次编译会下载工具链与全部源码，通常 1～2 小时；失败时工作流会自动降级到 `make -j1 V=s` 输出详细日志。
