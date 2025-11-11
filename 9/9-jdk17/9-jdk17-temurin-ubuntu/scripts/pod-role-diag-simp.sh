#!/bin/bash
set -e

echo "=== Pod角色诊断 ==="
echo "诊断时间: $(date)"

# 检测可用的网络工具，优先使用 ss
if command -v ss >/dev/null 2>&1; then
    NET_TOOL="ss"
elif command -v netstat >/dev/null 2>&1; then
    NET_TOOL="netstat"
else
    echo "错误: 未找到 ss 或 netstat 命令" >&2
    exit 1
fi

# 监听端口分析
if [ "$NET_TOOL" = "ss" ]; then
    LISTEN_PORTS=$(ss -tlnp 2>/dev/null | grep LISTEN | wc -l)
else
    LISTEN_PORTS=$(netstat -tlnp 2>/dev/null | grep LISTEN | wc -l)
fi
echo "LISTEN端口数量: $LISTEN_PORTS"

# 连接方向分析
if [ "$NET_TOOL" = "ss" ]; then
    INBOUND=$(ss -anp 2>/dev/null | grep ESTAB | awk '{print $5}' | grep -v "127.0.0.1" | awk -F: '{print $1}' | sort | uniq | wc -l)
    OUTBOUND=$(ss -anp 2>/dev/null | grep ESTAB | awk '{print $4}' | grep -E ":(80|443|8080|8443|3306|6379|8123|9000)" | wc -l)
else
    INBOUND=$(netstat -anp 2>/dev/null | grep ESTAB | awk '{print $5}' | grep -v "127.0.0.1" | awk -F: '{print $1}' | sort | uniq | wc -l)
    OUTBOUND=$(netstat -anp 2>/dev/null | grep ESTAB | awk '{print $4}' | grep -E ":(80|443|8080|8443|3306|6379|8123|9000)" | wc -l)
fi

echo "入站连接来源IP数: $INBOUND"
echo "出站连接到标准端口: $OUTBOUND"

# 角色判断
if [ $LISTEN_PORTS -gt 2 ] && [ $INBOUND -gt $OUTBOUND ]; then
    echo "角色: 服务端"
elif [ $OUTBOUND -gt 20 ]; then
    echo "角色: 客户端"
else
    echo "角色: 混合"
fi
