#!/bin/sh
# /etc/uci-defaults/99-huaweicloud.sh
# 首次启动执行一次，返回 0 后由系统自动删除
# 目的：让 OpenWrt 在华为云 ECS / 普通 KVM VPS 上开机就能拿到 VPC 内网 IP
#
# 官方 x86/64 镜像默认：br-lan 静态 192.168.1.1 + 开启 LAN 侧 DHCP 服务器
# 这在云 VPC 里会：1) 拿不到地址  2) 与 VPC 自带 DHCP 冲突
# 必须改成 DHCP 客户端，并关掉自己的 DHCP 服务器。
#
# 逐条 uci 而非 batch：不同版本里 batch 对引号、缺失 option 的处理不一致，
# 单条命令即使某条失败也不会连累其余设置。

# 防重复：已经是 dhcp 就跳过
[ "$(uci -q get network.lan.proto)" = "dhcp" ] && exit 0

# 单网卡云主机不用 br-lan，直接 eth0，保证 DHCP 用云端口绑定的那个 MAC
uci -q set network.lan.device=eth0
uci -q set network.lan.proto=dhcp
uci -q delete network.lan.ipaddr
uci -q delete network.lan.netmask
uci -q delete network.lan.ip6assign
uci -q commit network

# 关掉 LAN 侧 DHCP 服务器：云 VPC 自带 DHCP，虚机里绝不能再开一个
uci -q set dhcp.lan.ignore=1
uci -q commit dhcp

# 兜底：允许 root 用密码登录 SSH
uci -q set dropbear.@dropbear[0].PasswordAuth=on
uci -q set dropbear.@dropbear[0].RootPasswordAuth=on
uci -q commit dropbear

uci -q set system.@system[0].hostname=OpenWrt-Cloud
uci -q commit system

exit 0
