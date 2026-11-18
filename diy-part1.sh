#!/usr/bin/env bash
# 执行时机：clone 源码之后、feeds update 之前
# 工作目录：openwrt 源码根目录（../ 即 GitHub 仓库根目录）
set -e

echo "[diy-part1] 源码 HEAD: $(git rev-parse --short HEAD)"
echo "[diy-part1] 保持官方源码自带 feeds.conf.default，不注入第三方插件源"

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

# 如需改用 GitHub 加速 feeds，或添加第三方插件源，可在此覆盖 feeds.conf.default，例如：
# cat > feeds.conf.default <<'EOF'
# src-git packages https://github.com/openwrt/packages.git;openwrt-25.12
# src-git luci https://github.com/openwrt/luci.git;openwrt-25.12
# src-git routing https://github.com/openwrt/routing.git;openwrt-25.12
# src-git telephony https://github.com/openwrt/telephony.git;openwrt-25.12
# src-git helloworld https://github.com/fw876/helloworld.git;master
# EOF
