# 用 GitHub Actions 编译 OpenWrt 官方 x86/64 固件

基于 yhlh9982/Actions-OpenWrt-MT798X 所用的 P3TERX 云编译模板结构改写，源码改为官方 `openwrt/openwrt`，目标改为 x86/64（软路由 / 虚拟机 / 工控机）。

**当前配置目标**：复刻官方固件
`openwrt-25.12.6-x86-64-generic-ext4-combined-efi.img.gz` 里的全部预装包，并加上中文选项。

## 文件结构

```
.github/workflows/build-openwrt-x86_64.yml   # 主工作流
x86_64.config                               # 官方镜像全包 + 中文的 .config
OFFICIAL_IMAGE_PACKAGES.md                  # 包清单、来源与限制说明
diy-part1.sh                                # feeds update 之前执行（可换 feeds / 加插件源）
diy-part2.sh                                # 载入 .config 之后执行（跑 defconfig + 包核对）
README.md
```

## 快速开始

1. 新建（或 fork）一个 GitHub 仓库，把上面文件按相同路径放到**仓库根目录**，尤其不要改 `.github/workflows/` 这个路径。
2. 进入 `Actions` → `Build OpenWrt x86_64 (Official)` → `Run workflow`。
3. 参数说明：
   - `repo_branch`：默认 **`v25.12.6`**（精确对上用户指定的 25.12.6 官方镜像）；若该 tag 拉取失败，改填 `openwrt-25.12`（分支 HEAD）或 `openwrt-24.10` / `main`。
   - `upload_release`：是否同时发到本仓库 Releases（默认开）；`ssh`：调试用，默认关。
4. 编译完成后在 Actions 的 **Artifacts** 下载 `OpenWrt-x86_64-*`，或在 **Releases** 下载。

## 产物

输出目录为 `openwrt/bin/targets/x86/64/`。本配置对齐 ext4 + EFI 形态，主要产物：

- `*-generic-ext4-combined-efi.img.gz`：**本次对标的镜像**
- `*-generic-ext4-combined.img.gz`：BIOS/GRUB 版 ext4
- `*-generic-ext4-rootfs.img.gz`、`*-generic-initramfs-kernel.bin` 等

x86 平台没有 `factory` / `sysupgrade` 之分，升级时写回同类型镜像即可。`CONFIG_TARGET_ROOTFS_PARTSIZE=512` 比官方默认大，方便直接塞软件包，需要与原镜像一致可改回 104。

## 这次的 config 里有什么

- **官方 `profiles.json` 的 43 个包**：29 个 target 默认包 + 14 个 Generic x86/64 设备驱动
- **25.12 官方 release 标配 LuCI 套件**：luci、luci-app-attendedsysupgrade、luci-app-firewall、luci-app-package-manager、uhttpd/rpcd 等
- **镜像 manifest 里的公共依赖**：库、kmod-nf-*、kmod-crypto-* 等，也显式写成 `CONFIG_PACKAGE_xxx=y`
- **中文选项（本次新增）**：
  - `CONFIG_LUCI_LANG_zh_Hans=y`
  - `luci-i18n-base-zh-cn`、`luci-i18n-firewall-zh-cn`、`luci-i18n-package-manager-zh-cn`、`luci-i18n-attendedsysupgrade-zh-cn`

完整清单与来源依据见 `OFFICIAL_IMAGE_PACKAGES.md`。

⚠️ **重要限制**：该固件的权威清单文件 `openwrt-25.12.6-x86-64.manifest` 是纯文本，
本次资源解析/网页抓取通道读不到它的正文（目录页可见、文件正文不可读）。
所以包集是按官方 `profiles.json` 默认包 + 25.12 release LuCI 标配 + 官方包目录核对**重建**的，
不是逐字复制 manifest。若你手上有该 `.manifest` 文件，贴过来即可生成 1:1 精确版。

## 与原模板的差异

| 项 | 原模板（MT798X） | 本工作流 |
|---|---|---|
| `REPO_URL` | hanwckf / padavanonly 等 immortalwrt-mt798x 分支 | `https://github.com/openwrt/openwrt` |
| `REPO_BRANCH` | 21.02 / 24.10 / 25.12 的 MT798X 专用分支 | 官方 `v25.12.6` tag（可切分支） |
| `CONFIG_FILE` | 各机型 `.config`（含闭源 WiFi 驱动） | `x86_64.config`：官方镜像全包 + 中文 |
| feeds | 带 iStore / 第三方插件 | 使用官方源码自带的 `feeds.conf.default` |
| 机型 | wr30u / Q30 / x60 / uax3000e 等 MT798X | Generic x86/64 |

官方四个 feeds 是 `packages / luci / routing / telephony`，官方 LuCI 应用有上百个，但**没有**
`luci-app-openclash`、`luci-app-passwall`、`luci-app-ssr-plus`、`luci-app-istore`、
`luci-app-diskman`、`luci-app-ddns-go`、`luci-theme-argon` 这类第三方插件。
它们写进 `.config` 也不会报错，只会被 `make defconfig` **静默丢弃**——这就是"编译成功但后台没插件"的最常见原因。
需要它们在 `diy-part1.sh` 里追加对应 `src-git` 源，再打开 `CONFIG_PACKAGE_xxx=y`。

## 包核对机制

`diy-part2.sh` 在 `make defconfig` 之后会对比原始 config，把没生效的包分成两类打印：

- `ℹ 目标默认包/依赖`：构建系统自动带进镜像，Kconfig 里没有对应符号，属于预期
- `⚠ 可选包缺失`：包名写错或该分支/feed 没有，需要检查

编译日志里搜 `[diy-part2]` 即可看到，末尾还会打印实际生效的包数量。

## 注意事项

- `github.com/openwrt/openwrt` 是官方 Git 仓库的只读镜像，克隆编译完全没问题，只是 PR 不直接合入这里。
- `x86_64.config` 的 target / profile / EFI 部分只写最小必要项：不同 OpenWrt 分支里 x86/64 的 profile 符号名有变化（`TARGET_x86_64_Generic` / `TARGET_x86_64_DEVICE_generic`），交给 `make defconfig` 自动补全省去踩坑；EFI 相关符号同理，两个都写、由 defconfig 取舍。
- 25.12 起包管理器从 `opkg` 换成 `apk`，装包命令是 `apk add <包名>`；`luci-app-package-manager` / `luci-i18n-package-manager-zh-cn` 是 25.12 的新包名。
- 固定的是主仓库 `v25.12.6` tag，feeds 仍按源码内 `feeds.conf.default` 拉取 25.12 分支快照，可能与 10-18 发布时的 feeds 略有差异；要完全一致需在 `diy-part1.sh` 里把 feeds 也锁到相同 commit。
- 中文语言包装好后，若界面没自动切中文，去「系统 → 语言和界面」手动选简体中文。
- 默认 LAN 地址为 `192.168.1.1`，未改密码。
- runner 固定 `ubuntu-22.04`（与模板一致）；若改 `ubuntu-24.04`，需把依赖里的 `python3-distutils` 换成等价包。
- 已声明 `permissions: contents: write`，发布 Releases 不需要额外 PAT。
- 首次编译会下载工具链与全部源码，通常 1～2 小时；失败时工作流会自动降级到 `make -j1 V=s` 输出详细日志。
