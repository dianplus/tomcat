#!/bin/bash
set -e

echo "开始优化 32核256G Kubernetes 节点网络参数..."

# 备份现有配置
echo "备份当前 sysctl 配置..."
cp /etc/sysctl.conf /etc/sysctl.conf.bak.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true

# 创建优化配置
cat > /etc/sysctl.d/99-k8s-highperf-optimization.conf << 'EOF'
# ============================================================================
# Kubernetes 高性能节点网络优化配置 (32核256G)
# ============================================================================

# ===== 修复 99-k8s.conf 中的问题参数 =====
# 关键修复：重新启用用户命名空间
user.max_user_namespaces = 28633
# 生产环境安全：禁用软锁定panic
kernel.softlockup_panic = 0

# ===== 连接跟踪优化 =====
# 大幅增加连接跟踪表容量，适应高并发
net.netfilter.nf_conntrack_max = 2097152
net.netfilter.nf_conntrack_buckets = 524288

# 优化连接超时设置，平衡连接复用和资源释放
net.netfilter.nf_conntrack_tcp_timeout_established = 86400
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 60
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 120
net.netfilter.nf_conntrack_tcp_timeout_syn_recv = 60
net.netfilter.nf_conntrack_udp_timeout = 60
net.netfilter.nf_conntrack_udp_timeout_stream = 180

# ===== 本地端口范围 =====
# 最大化本地端口范围，支持大量出站连接
net.ipv4.ip_local_port_range = 1024 65535

# ===== TCP 协议优化 =====
# 启用连接复用和快速回收
# tcp_tw_reuse 内核版本支持情况：
#   - Linux 2.4+ : 支持取值 0, 1
#   - Linux 2.6+ : 完全支持取值 0, 1, 2
#   - Linux 4.1+ : tcp_tw_recycle 开始弃用，但 tcp_tw_reuse 保持稳定
# 节点优化使用通用值 1，适用于所有内核版本
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_window_scaling = 1

# TIME_WAIT 连接数限制（节点级别参数，不在 Pod 命名空间内）
# 增加 TIME_WAIT bucket 数量，适应高并发场景
net.ipv4.tcp_max_tw_buckets = 2000000

# 连接队列和积压优化
net.ipv4.tcp_max_syn_backlog = 65536
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 300000

# TCP 内存缓冲区优化 (适应大内存)
net.core.rmem_max = 67108864       # 64MB
net.core.wmem_max = 67108864       # 64MB
net.core.rmem_default = 4194304    # 4MB
net.core.wmem_default = 4194304    # 4MB

net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mem = 786432 1048576 1572864    # 根据 256G 内存调整

# TCP 拥塞控制和快速重传
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_retries2 = 8
net.ipv4.tcp_retries1 = 3
net.ipv4.tcp_fastopen = 3

# ===== 文件描述符和进程限制 =====
# 大幅增加文件描述符限制
fs.file-max = 4194304
fs.nr_open = 1048576

# 增加进程和线程限制
kernel.pid_max = 4194304
kernel.threads-max = 4194304

# ===== 内存管理优化 =====
# 优化大内存系统的内存管理
vm.swappiness = 10                 # 减少交换倾向
vm.dirty_ratio = 20
vm.dirty_background_ratio = 10
vm.vfs_cache_pressure = 1000       # 积极回收 inode/dentry 缓存

# ===== 网络核心优化 =====
# 增加网络核心缓冲区
net.core.optmem_max = 4194304
net.core.rps_sock_flow_entries = 0

# ===== 可选: IPv6 配置 =====
# 如果不需要 IPv6，可以取消注释以下行
# net.ipv6.conf.all.disable_ipv6 = 1
# net.ipv6.conf.default.disable_ipv6 = 1
# net.ipv6.conf.lo.disable_ipv6 = 1

EOF

echo "应用新的 sysctl 配置..."
# 立即应用配置
sysctl -p /etc/sysctl.d/99-k8s-highperf-optimization.conf

# 加载 nf_conntrack 模块（如果尚未加载）
modprobe nf_conntrack 2>/dev/null || true

echo "配置系统服务确保重启后生效..."
# 确保启动时加载
if [ -d /etc/systemd/system ]; then
    cat > /etc/systemd/system/sysctl-optimize.service << 'SERVICE_EOF'
[Unit]
Description=Apply Kubernetes High Performance Network Optimizations
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/sysctl -p /etc/sysctl.d/99-k8s-highperf-optimization.conf
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SERVICE_EOF

    systemctl enable sysctl-optimize.service
fi

# 设置系统级文件描述符限制
echo "配置系统级文件描述符限制..."
echo "* soft nofile 1048576" >> /etc/security/limits.conf
echo "* hard nofile 1048576" >> /etc/security/limits.conf
echo "root soft nofile 1048576" >> /etc/security/limits.conf
echo "root hard nofile 1048576" >> /etc/security/limits.conf

echo "优化完成！"

# 显示关键配置验证
echo ""
echo "=== 配置验证 ==="
echo "连接跟踪表大小: $(cat /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null || echo '未设置')"
echo "本地端口范围: $(sysctl net.ipv4.ip_local_port_range | cut -d'=' -f2)"
echo "文件描述符限制: $(sysctl fs.file-max | cut -d'=' -f2)"
echo "TCP 读写缓冲区: $(sysctl net.core.rmem_max net.core.wmem_max | grep -o '[0-9]*' | tr '\n' ' ')"

echo ""
echo "=== 当前资源使用情况 ==="
echo "当前连接数: $(ss -s | grep 'TCP:' | awk '{print $2}')"
echo "Conntrack 使用: $(cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null || echo 'N/A')/$(cat /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null || echo 'N/A')"
echo "内存使用: $(free -h | grep Mem | awk '{print $3"/"$2}')"
