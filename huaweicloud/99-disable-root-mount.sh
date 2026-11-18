#!/bin/sh
# /etc/uci-defaults/99-disable-root-mount.sh
# 兜底：镜像里的 fstab 已由 diy-part1.sh 修好（没有 target=/ 条目）。
# 这里防的是「以后有人在 LuCI → 系统 → 挂载点 页面又把根分区那条勾成启用」，
# 下次启动时再禁一次。退出 0 会被系统自动删除；失败则保留并下轮重试。
#
# 背景：fstools 的 mount_root 会把 fstab 中 target='/' 且 enabled=1 的条目
# 当成 extroot 配置，误切换后 / 保持只读，所有配置都保存不了。

[ -f /etc/config/fstab ] || exit 0

CHANGED=0
for s in $(uci show fstab 2>/dev/null | grep -o 'fstab\.@mount\[[0-9]*\]' | sort -u); do
  if [ "$(uci -q get "$s.target")" = "/" ] && [ "$(uci -q get "$s.enabled")" != "0" ]; then
    uci -q set "$s.enabled=0"
    CHANGED=1
  fi
done

if [ "$CHANGED" = 1 ]; then
  if uci -q commit fstab && sync; then
    logger -t fix-fstab "disabled self-root mount entry in /etc/config/fstab"
  else
    echo "fix-fstab: cannot commit (root read-only?), retry next boot" >&2
    exit 1
  fi
fi

exit 0
