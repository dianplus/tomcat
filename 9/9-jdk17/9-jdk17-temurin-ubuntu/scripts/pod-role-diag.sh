#!/bin/bash
# pod-role-diag.sh
set -e

echo "=== Pod角色诊断 ==="
echo "诊断时间: $(date)"
echo ""

# 检测可用的网络工具，优先使用 ss
if command -v ss >/dev/null 2>&1; then
    NET_TOOL="ss"
elif command -v netstat >/dev/null 2>&1; then
    NET_TOOL="netstat"
else
    echo "错误: 未找到 ss 或 netstat 命令" >&2
    exit 1
fi

# 1. 监听端口分析
echo "1. 监听端口分析:"
if [ "$NET_TOOL" = "ss" ]; then
    LISTEN_PORTS=$(ss -tlnp 2>/dev/null | grep LISTEN | wc -l)
    echo "   LISTEN端口数量: $LISTEN_PORTS"
    ss -tlnp 2>/dev/null | grep LISTEN | awk '{print "   - " $4 " (" $6 ")"}'
else
    LISTEN_PORTS=$(netstat -tlnp 2>/dev/null | grep LISTEN | wc -l)
    echo "   LISTEN端口数量: $LISTEN_PORTS"
    netstat -tlnp 2>/dev/null | grep LISTEN | awk '{print "   - " $4 " (" $7 ")"}'
fi

# 2. 连接方向分析
echo -e "\n2. 连接方向分析:"
if [ "$NET_TOOL" = "ss" ]; then
    INBOUND=$(ss -anp 2>/dev/null | grep ESTAB | awk '{print $5}' | grep -v "127.0.0.1" | grep -v ":::" | awk -F: '{print $1}' | sort | uniq | wc -l)
    OUTBOUND=$(ss -anp 2>/dev/null | grep ESTAB | awk '{print $4}' | grep -E ":(80|443|8080|8443|3306|6379|8123|9000)" | wc -l)
else
    INBOUND=$(netstat -anp 2>/dev/null | grep ESTAB | awk '{print $5}' | grep -v "127.0.0.1" | grep -v ":::" | awk -F: '{print $1}' | sort | uniq | wc -l)
    OUTBOUND=$(netstat -anp 2>/dev/null | grep ESTAB | awk '{print $4}' | grep -E ":(80|443|8080|8443|3306|6379|8123|9000)" | wc -l)
fi

echo "   入站连接来源IP数: $INBOUND"
echo "   出站连接到标准端口: $OUTBOUND"

# 3. 连接状态统计
echo -e "\n3. 连接状态统计:"
if [ "$NET_TOOL" = "ss" ]; then
    # ss 输出格式: State Recv-Q Send-Q Local Address:Port Peer Address:Port
    ss -an 2>/dev/null | awk '/^ESTAB|^TIME-WAIT|^CLOSE-WAIT|^FIN-WAIT|^SYN-SENT|^SYN-RECV|^LISTEN/ {print $1}' | sort | uniq -c | sort -rn | while read count state; do
        echo "   $state: $count"
    done
else
    netstat -an 2>/dev/null | awk '/^tcp/ {print $6}' | sort | uniq -c | sort -rn | while read count state; do
        echo "   $state: $count"
    done
fi

# 4. 端口使用模式
echo -e "\n4. 端口使用模式:"
if [ "$NET_TOOL" = "ss" ]; then
    EPHEMERAL_PORTS=$(ss -an 2>/dev/null | grep ESTAB | awk '{print $4}' | grep -E ':(1[0-9]{4}|[2-5][0-9]{4}|6[0-4][0-9]{3}|65[0-3][0-9]{2}|654[0-9]{2}|655[0-2][0-9]|6553[0-5])' | wc -l)
    FIXED_PORTS=$(ss -an 2>/dev/null | grep ESTAB | awk '{print $4}' | grep -E ':(80|443|8080|8443|3306|5432|6379|9092|8123|9000)' | wc -l)
else
    EPHEMERAL_PORTS=$(netstat -an 2>/dev/null | grep ESTAB | awk '{print $4}' | grep -E ':(1[0-9]{4}|[2-5][0-9]{4}|6[0-4][0-9]{3}|65[0-3][0-9]{2}|654[0-9]{2}|655[0-2][0-9]|6553[0-5])' | wc -l)
    FIXED_PORTS=$(netstat -an 2>/dev/null | grep ESTAB | awk '{print $4}' | grep -E ':(80|443|8080|8443|3306|5432|6379|9092|8123|9000)' | wc -l)
fi

echo "   临时端口连接: $EPHEMERAL_PORTS"
echo "   固定端口连接: $FIXED_PORTS"

# 5. 目标IP分析
echo -e "\n5. 目标IP分析:"
echo "   连接到的不同目标IP:"
if [ "$NET_TOOL" = "ss" ]; then
    ss -anp 2>/dev/null | grep ESTAB | awk '{print $5}' | grep -v "127.0.0.1" | grep -v ":::" | awk -F: '{print $1}' | sort | uniq -c | sort -rn | head -5
else
    netstat -anp 2>/dev/null | grep ESTAB | awk '{print $5}' | grep -v "127.0.0.1" | grep -v ":::" | awk -F: '{print $1}' | sort | uniq -c | sort -rn | head -5
fi

# 6. 角色判断
echo -e "\n6. 角色判断结果:"

if [ $LISTEN_PORTS -gt 2 ] && [ $INBOUND -gt $OUTBOUND ]; then
    echo "   🔵 主要角色: 服务端 (Service)"
    echo "   特征: 多监听端口, 大量入站连接"
elif [ $EPHEMERAL_PORTS -gt $FIXED_PORTS ] && [ $OUTBOUND -gt $INBOUND ]; then
    echo "   🟢 主要角色: 客户端 (Client)" 
    echo "   特征: 大量临时端口, 主要出站连接"
else
    echo "   🟡 主要角色: 混合模式 (Hybrid)"
    echo "   特征: 平衡的服务和客户端行为"
fi

# 7. 连接趋势
echo -e "\n7. 连接趋势:"
if [ "$NET_TOOL" = "ss" ]; then
    TIME_WAIT_COUNT=$(ss -an 2>/dev/null | grep TIME-WAIT | wc -l)
    ESTAB_COUNT=$(ss -an 2>/dev/null | grep ESTAB | wc -l)
else
    TIME_WAIT_COUNT=$(netstat -an 2>/dev/null | grep TIME_WAIT | wc -l)
    ESTAB_COUNT=$(netstat -an 2>/dev/null | grep ESTAB | wc -l)
fi
echo "   ESTABLISHED: $ESTAB_COUNT, TIME_WAIT: $TIME_WAIT_COUNT"

if [ $TIME_WAIT_COUNT -gt $((ESTAB_COUNT * 2)) ]; then
    echo "   ⚠️  检测到大量TIME_WAIT, 建议客户端优化"
fi
