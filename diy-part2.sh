#!/usr/bin/env bash
# 执行时机：feeds install 之后、make download 之前
# 工作目录：openwrt 源码根目录
set -e

# 显式追加 LuCI 集合；若当前分支没有对应包，make defconfig 会自动丢弃该符号
for sym in \
  CONFIG_PACKAGE_luci=y \
  CONFIG_PACKAGE_luci-ssl-openssl=y; do
  grep -qxF "$sym" .config || echo "$sym" >> .config
done

# 让 Kconfig 依据当前源码分支补全 target / profile / 镜像符号
make defconfig

echo "[diy-part2] 生效的目标与 LuCI 配置："
grep -E '^(CONFIG_TARGET_x86|CONFIG_TARGET_ROOTFS|CONFIG_GRUB|CONFIG_EFI|CONFIG_PACKAGE_luci)' .config | sort | head -60 || true

# ---------------------------------------------------------------------------
# 核对：原始 x86_64.config 里写了、但 defconfig 后不存在的包
# （包名写错 / 该分支或该 feed 没有这个包时，Kconfig 会静默丢弃，不报错）
# ---------------------------------------------------------------------------
WS="${GITHUB_WORKSPACE:-..}"
REQ="$(git -C "$WS" show "HEAD:${CONFIG_FILE:-x86_64.config}" 2>/dev/null || true)"
if [ -n "$REQ" ]; then
  LOST="$(echo "$REQ" \
    | grep -E '^CONFIG_PACKAGE_.*=y$' \
    | sed -E 's/^CONFIG_PACKAGE_(.*)=y$/\1/' \
    | while read -r p; do
        grep -qxF "CONFIG_PACKAGE_$p=y" .config \
          || grep -qxF "CONFIG_PACKAGE_$p=m" .config \
          || echo "  - $p"
      done || true)"
  if [ -n "$LOST" ]; then
    echo "[diy-part2] ⚠ 以下包在当前源码分支不存在，已被 defconfig 丢弃（检查包名或加第三方 feed）："
    echo "$LOST"
  else
    echo "[diy-part2] ✅ 所有请求的包都已生效"
  fi
fi
echo "[diy-part2] 实际生效的包数量：$(grep -cE '^CONFIG_PACKAGE_.*=y$' .config || true)"
