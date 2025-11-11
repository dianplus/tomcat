#!/bin/bash
set -e

echo "应用Sysctl优化..."

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 检测内核版本，用于确定 tcp_tw_reuse 支持的值
# - Linux 2.4+ : 支持取值 0, 1
# - Linux 2.6+ : 完全支持取值 0, 1, 2
# - Linux 4.1+ : tcp_tw_recycle 开始弃用，但 tcp_tw_reuse 保持稳定
KERNEL_VERSION=$(uname -r)
KERNEL_MAJOR=$(echo "$KERNEL_VERSION" | cut -d. -f1)
KERNEL_MINOR=$(echo "$KERNEL_VERSION" | cut -d. -f2)

# 判断是否支持 tcp_tw_reuse=2 (需要 Linux 2.6+)
# 比较逻辑: 主版本号 > 2，或主版本号 = 2 且次版本号 >= 6
if [ "$KERNEL_MAJOR" -gt 2 ] || ([ "$KERNEL_MAJOR" -eq 2 ] && [ "$KERNEL_MINOR" -ge 6 ]); then
    TCP_TW_REUSE_SUPPORT_2=1
else
    TCP_TW_REUSE_SUPPORT_2=0
fi

# 通用优化
sysctl -w net.ipv4.tcp_timestamps=1
sysctl -w net.ipv4.tcp_tw_recycle=0

# 注意: net.ipv4.tcp_max_tw_buckets 是节点级别的参数，不在 Pod 命名空间控制范围内
# 如果需要在 Pod 中修改，需要集群管理员在 kubelet 中启用 --allowed-unsafe-sysctls
# 此参数应在节点级别配置（如 node-net-optim-32c256g.sh），这里尝试设置但允许失败
if ! sysctl -w net.ipv4.tcp_max_tw_buckets=2000000 2>/dev/null; then
    echo "  警告: 无法设置 net.ipv4.tcp_max_tw_buckets (节点级参数，需集群管理员启用)"
    echo "  建议: 在节点级别配置此参数，或联系集群管理员启用 --allowed-unsafe-sysctls"
fi

# 根据角色应用特定优化
ROLE=$("${SCRIPT_DIR}/pod-role-diag-simp.sh" 2>/dev/null | grep "角色:" | awk '{print $2}') || ROLE="混合"

case $ROLE in
    "客户端")
        echo "应用客户端优化"
        sysctl -w net.ipv4.tcp_tw_reuse=1
        sysctl -w net.ipv4.tcp_fin_timeout=3
        ;;
    "服务端")
        echo "应用服务端优化"
        # tcp_tw_reuse=2 仅在 Linux 2.6+ 内核中支持
        # 对于服务端，使用 2 可以更积极地复用 TIME_WAIT 套接字
        if [ $TCP_TW_REUSE_SUPPORT_2 -eq 1 ]; then
            sysctl -w net.ipv4.tcp_tw_reuse=2
        else
            echo "  警告: 内核版本 < 2.6，tcp_tw_reuse 使用 1 替代 2"
            sysctl -w net.ipv4.tcp_tw_reuse=1
        fi
        sysctl -w net.ipv4.tcp_fin_timeout=10
        ;;
    *)
        echo "应用混合模式优化"
        sysctl -w net.ipv4.tcp_tw_reuse=1
        sysctl -w net.ipv4.tcp_fin_timeout=5
        ;;
esac

echo "优化完成"
