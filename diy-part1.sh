#!/usr/bin/env bash
# 执行时机：clone 源码之后、feeds update 之前
# 工作目录：openwrt 源码根目录
set -e

echo "[diy-part1] 源码 HEAD: $(git rev-parse --short HEAD)"
echo "[diy-part1] 保持官方源码自带 feeds.conf.default，不注入第三方插件源"

# 如需改用 GitHub 加速 feeds，或添加第三方插件源，可在此覆盖 feeds.conf.default，例如：
# cat > feeds.conf.default <<'EOF'
# src-git packages https://github.com/openwrt/packages.git;openwrt-25.12
# src-git luci https://github.com/openwrt/luci.git;openwrt-25.12
# src-git routing https://github.com/openwrt/routing.git;openwrt-25.12
# src-git telephony https://github.com/openwrt/telephony.git;openwrt-25.12
# src-git helloworld https://github.com/fw876/helloworld.git;master
# EOF
