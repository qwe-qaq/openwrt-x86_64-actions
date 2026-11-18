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
grep -E '^(CONFIG_TARGET_x86|CONFIG_TARGET_ROOTFS|CONFIG_GRUB|CONFIG_EFI|CONFIG_PACKAGE_luci)' .config | sort | head -40 || true
