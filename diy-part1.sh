#!/usr/bin/env bash
# 执行时机：clone 源码之后、feeds update 之前
# 工作目录：openwrt 源码根目录（../ 即 GitHub 仓库根目录）
set -e

echo "[diy-part1] 源码 HEAD: $(git rev-parse --short HEAD)"
echo "[diy-part1] 保持官方源码自带 feeds.conf.default，不整库注入第三方 feed"
echo "[diy-part1] 三个插件以「单包源码」方式接入 package/，避免整库同名冲突"

# ============================================================================
# 用户点名要的三个包：luci-app-diskman / luci-app-homeproxy / luci-theme-argon
#
# 关键概念澄清（上一轮说得过于笼统，这里更正）：
#   「25.12 用 apk，第三方 ipk feed 不可用」指的是**预编译的 .ipk 二进制包**
#   装不上（apk 装不了 ipk）。但**源码 Makefile 形式的包不受影响**——包格式由
#   CONFIG_USE_APK=y 决定，作用于整个工具链，构建系统会把源码 feed 编成 .apk。
#   所以正解是：把源码接进构建树，让同一套 luci-base / 内核统一编译，依赖自动解析。
#
#   反过来，直接拿 ImmortalWrt 现成的 .apk 装到官方 OpenWrt 上反而有风险：
#   那些 luci-* 包绑定 ImmortalWrt 自己的 luci-base 版本，kmod 包绑定它的内核，
#   跨发行版装容易依赖冲突。同源码编译才是最稳的。
#
# 选源依据（已逐个核对 Makefile 的 include 路径与 po/zh_Hans 目录）：
#   - argon      : jerrykuku/luci-theme-argon@master，仓库根即包目录，
#                  include $(TOPDIR)/feeds/luci/luci.mk，已内建 CONFIG_USE_APK 判断
#   - diskman    : sbwml/luci-app-diskman@main（JS/ucode 重写版，专为 25.12），
#                  仓库在 luci-app-diskman/ 子目录，include 为绝对路径
#                  （不用 lisaac 老版：它依赖 luci-lib-ipkg，25.12 已无此包）
#   - homeproxy  : immortalwrt/luci@openwrt-25.12 的 applications/luci-app-homeproxy，
#                  Makefile 写的是 include ../../luci.mk（相对路径），放到 package/
#                  后会指错，故用 sed 改成绝对路径
#
# 三个包都有 po/zh_Hans/，构建时会自动生成 luci-i18n-*-zh-cn 中文包。
# 依赖（sing-box / kmod-nft-tproxy / ucode-mod-digest / parted / btrfs-progs /
# wget-ssl / coreutils* 等）由 Makefile 的 LUCI_DEPENDS 自动选中，无需手写进 .config。
# ============================================================================
EXTRA_APPS="${EXTRA_APPS:-true}"

if [ "$EXTRA_APPS" = "true" ]; then
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT

  # --- 1) Argon 主题 -------------------------------------------------------
  echo "[diy-part1] 拉取 luci-theme-argon ..."
  git clone -q --depth 1 https://github.com/jerrykuku/luci-theme-argon.git "$TMP/argon"
  rm -rf package/luci-theme-argon
  cp -a "$TMP/argon" package/luci-theme-argon
  rm -rf package/luci-theme-argon/.git

  # --- 2) DiskMan（ucode 适配版）-------------------------------------------
  echo "[diy-part1] 拉取 luci-app-diskman (sbwml/ucode 版) ..."
  git clone -q --depth 1 https://github.com/sbwml/luci-app-diskman.git "$TMP/diskman"
  rm -rf package/luci-app-diskman
  cp -a "$TMP/diskman/luci-app-diskman" package/luci-app-diskman
  rm -rf package/luci-app-diskman/.git

  # --- 3) HomeProxy（ImmortalWrt 25.12 分支单包）----------------------------
  echo "[diy-part1] 拉取 luci-app-homeproxy (ImmortalWrt openwrt-25.12) ..."
  git clone -q --depth 1 --filter=blob:none --sparse \
    -b openwrt-25.12 https://github.com/immortalwrt/luci.git "$TMP/iwrt-luci"
  git -C "$TMP/iwrt-luci" sparse-checkout set applications/luci-app-homeproxy
  rm -rf package/luci-app-homeproxy
  cp -a "$TMP/iwrt-luci/applications/luci-app-homeproxy" package/luci-app-homeproxy
  # include ../../luci.mk 只有在 feeds/luci/applications/ 下才成立，改成绝对路径
  sed -i 's|include ../../luci.mk|include $(TOPDIR)/feeds/luci/luci.mk|' \
    package/luci-app-homeproxy/Makefile

  echo "[diy-part1] 三个包源码已放入 package/："
  ls -d package/luci-theme-argon package/luci-app-diskman package/luci-app-homeproxy
  echo "[diy-part1] 依赖由 LUCI_DEPENDS 自动解析；若 make defconfig 报"
  echo "            'has a dependency on xxx, which does not exist'，见 THIRDPARTY_APPS.md"
else
  echo "[diy-part1] EXTRA_APPS=false，跳过三个第三方包（编译失败时可用它一键回退）"
fi

# ============================================================================
# 华为云 ECS / KVM VPS 适配
# 构建系统会把源码根下的 files/ 原样拷进 rootfs，这里生成首次启动配置
# 注意：不要同时在仓库根目录放 files/ 目录，工作流会把它 mv 进来造成嵌套
# ============================================================================
mkdir -p files/etc/uci-defaults
cp ../huaweicloud/99-cloud-init.sh files/etc/uci-defaults/99-huaweicloud.sh
chmod 644 files/etc/uci-defaults/99-huaweicloud.sh
echo "[diy-part1] 已注入 99-huaweicloud.sh（lan 改 DHCP / 关 LAN DHCP 服务器）"

# root 密码：由 workflow 的 root_password 输入经 env 传入，不写进仓库
# 官方镜像 /etc/shadow 里 root 是空密码，SSH 通常拒绝空密码登录，必须设置
if [ -n "${ROOT_PASSWORD:-}" ]; then
  HASH="$(openssl passwd -6 "$ROOT_PASSWORD")"
  mkdir -p files/etc
  cp package/base-files/files/etc/shadow files/etc/shadow
  if grep -q '^root::' files/etc/shadow; then
    sed -i "s|^root::|root:${HASH}:|" files/etc/shadow
    echo "[diy-part1] 已注入 root 密码哈希（SHA-512 crypt）"
  else
    echo "[diy-part1] ⚠ 官方 shadow 里 root 不是空密码，跳过注入，请用 VNC 确认"
  fi
else
  echo "[diy-part1] ⚠ 未设置 root_password：镜像保持官方空密码，首次启动请用 VNC 控制台执行 passwd"
fi

# 可选 SSH 公钥：把公钥放进 huaweicloud/authorized_keys 即自动注入
if [ -f ../huaweicloud/authorized_keys ] \
   && grep -Eq '^(ssh-|ecdsa-)' ../huaweicloud/authorized_keys; then
  mkdir -p files/etc/dropbear
  cp ../huaweicloud/authorized_keys files/etc/dropbear/authorized_keys
  chmod 600 files/etc/dropbear/authorized_keys
  echo "[diy-part1] 已注入 SSH 公钥"
fi

# ============================================================================
# 根治「根只读 → 配置保存不了」：覆盖镜像自带的 fstab
#
# 官方 x86 ext4 combined 镜像的 /etc/config/fstab 里有一条 target='/' 且
# enabled=1 的条目，UUID 指向根分区自己。fstools 的 mount_root 在 PREINIT 阶段
# 调用 mount_extroot() 读到它，判定为 extroot 配置，打印
# "mount_root: switched to extroot" 后提前 return 0，跳过正常挂载：
#   /dev/root on /rom type ext4 (ro,noatime)
#   /dev/vda2  on /   type ext4 (ro,relatime)
# 于是 /etc/config 只读，uci commit 静默失败，LuCI 一直显示「未保存的配置: N」，
# 重启后配置全丢。删掉这条自挂载即可，/ 由内核以 rw 挂好。
#
# 构建系统会把源码根下 files/ 原样拷进 rootfs，所以覆盖是在镜像层面根治，
# 不依赖开机后再改（开机时根已经 ro，uci-defaults 也写不进去）。
# 另放一个 99- 开头的 uci-defaults 做兜底，防以后在 LuCI 挂载点页面又被勾回去。
# ============================================================================
mkdir -p files/etc/config
cp ../huaweicloud/fstab files/etc/config/fstab
chmod 644 files/etc/config/fstab
cp ../huaweicloud/99-disable-root-mount.sh files/etc/uci-defaults/99-disable-root-mount.sh
chmod 644 files/etc/uci-defaults/99-disable-root-mount.sh
echo "[diy-part1] 已注入修正版 fstab（无 target=/ 自挂载）+ 99-disable-root-mount.sh 兜底"

# 如需改用 GitHub 加速 feeds，或添加第三方插件源，可在此覆盖 feeds.conf.default，例如：
# cat > feeds.conf.default <<'EOF'
# src-git packages https://github.com/openwrt/packages.git;openwrt-25.12
# src-git luci https://github.com/openwrt/luci.git;openwrt-25.12
# src-git routing https://github.com/openwrt/routing.git;openwrt-25.12
# src-git telephony https://github.com/openwrt/telephony.git;openwrt-25.12
# src-git helloworld https://github.com/fw876/helloworld.git;master
# EOF
