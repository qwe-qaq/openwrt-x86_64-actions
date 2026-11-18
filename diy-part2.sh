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

# ① 目标默认包 / 依赖 / 核心组件：构建系统必定带进镜像，Kconfig 里可能没有
#    CONFIG_PACKAGE 符号或会被折叠，被 defconfig 去掉属于预期，不算包名写错。
BUILTIN="apk-mbedtls base-files busybox libc libgcc libmbedtls kernel procd procd-seccomp procd-ujail ubusd getrandom fwtool fitblk jansson jshn jsonfilter libblobmsg-json libjson-c libjson-script liblucihttp liblucihttp-ucode liblucihttp-lua libmnl libnftnl libnl-tiny libubox libubus libuci libuclient libucode libudebug libiwinfo libiwinfo-data ucode ipset hostapd-common ca-bundle dropbear e2fsprogs fstools logd mtd netifd nftables uci uclient-fetch urandom-seed urngd kmod-nf-conntrack kmod-nf-flow kmod-nf-log kmod-nf-nat kmod-nf-reject kmod-nf-reject6 kmod-nfnetlink kmod-nft-core kmod-nft-fib kmod-nft-nat kmod-ppp kmod-pppoe kmod-pppox kmod-slhc kmod-lib-crc-ccitt kmod-crypto-aead kmod-crypto-authenc kmod-crypto-crc32c kmod-crypto-des kmod-crypto-hash kmod-crypto-hmac kmod-crypto-manager kmod-crypto-md5 kmod-crypto-null kmod-crypto-sha1 kmod-crypto-sha256 kmod-crypto-sha512"

# ② 25.12 上游已删除 / 改名 / 内核内建的包：功能仍在，只是不再有独立符号
#    - kmod-nf-conntrack6：nf_conntrack_ipv6 不再是独立内核模块，并入 kmod-nf-conntrack
#    - kmod-nf-log6：Linux 5.13 起 v4/v6 日志统一 nf_log_syslog，并入 kmod-nf-log
#    - kmod-lib-crc32c：6.12 内核 CONFIG_CRC32C 内建
#    - nftables：拆成 nftables-json / nftables-nojson，firewall4 依赖 +nftables-json
REMOVED="kmod-nf-conntrack6 kmod-nf-log6 kmod-lib-crc32c nftables"

# ③ 官方四个 feeds 里根本没有的第三方插件：写了必然被丢弃
THIRDPARTY="luci-app-openclash luci-app-passwall luci-app-ssr-plus luci-app-homeproxy luci-app-istore luci-app-quickstart luci-app-diskman luci-app-ddns-go luci-app-linkease luci-app-lucky luci-app-mosdns luci-theme-argon"

if [ -n "$REQ" ]; then
  LOST="$(echo "$REQ" \
    | grep -E '^CONFIG_PACKAGE_.*=y$' \
    | sed -E 's/^CONFIG_PACKAGE_(.*)=y$/\1/' \
    | while read -r p; do
        grep -qxF "CONFIG_PACKAGE_$p=y" .config \
          || grep -qxF "CONFIG_PACKAGE_$p=m" .config \
          || echo "$p"
      done || true)"

  EXPECTED=""; GONE=""; THIRD=""; MISSING=""
  for p in $LOST; do
    if   [[ " $BUILTIN "    == *" $p "* ]]; then EXPECTED="$EXPECTED  - $p"$'\n'
    elif [[ " $REMOVED "    == *" $p "* ]]; then GONE="$GONE  - $p"$'\n'
    elif [[ " $THIRDPARTY " == *" $p "* ]]; then THIRD="$THIRD  - $p"$'\n'
    else                                            MISSING="$MISSING  - $p"$'\n'
    fi
  done

  [ -n "$EXPECTED" ] && {
    echo "[diy-part2] ℹ 以下 $(echo "$EXPECTED" | grep -c .) 个是目标默认包/依赖，构建系统自动带入（预期）："
    printf '%s' "$EXPECTED"
  }
  [ -n "$GONE" ] && {
    echo "[diy-part2] ℹ 以下 $(echo "$GONE" | grep -c .) 个是 25.12 上游已删除/改名/内核内建的包，功能由其他包提供（预期）："
    printf '%s' "$GONE"
  }
  [ -n "$THIRD" ] && {
    echo "[diy-part2] ⚠ 以下 $(echo "$THIRD" | grep -c .) 个是第三方插件，官方 feeds 里没有："
    printf '%s' "$THIRD"
    echo "            25.12 用 apk，传统第三方 opkg/ipk feed 在 apk 固件上不可用；"
    echo "            要么用提供 .apk 的源装，要么退回 24.10，要么换 ImmortalWrt 源码。"
  }
  [ -n "$MISSING" ] && {
    echo "[diy-part2] ⚠ 以下包名在当前源码分支不存在（检查拼写 / feeds 是否拉全）："
    printf '%s' "$MISSING"
  }
  [ -z "$LOST" ] && echo "[diy-part2] ✅ 所有请求的包都已生效"
fi
echo "[diy-part2] 实际生效的包数量：$(grep -cE '^CONFIG_PACKAGE_.*=y$' .config || true)"
