# resource/cmd_netneig.bash
cmd_netneig() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    err "用法: NETNEIG"
    cecho "扫描当前局域网下的所有存活主机 (自动探测子网)"
    return 0
    fi
    # 获取本机 IP 段
    local subnet=$(ip -4 addr show 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | grep -v '127.0.0' | head -1)
    if [ -z "$subnet" ]; then
        subnet="192.168.1.0/24"
    fi
    # 提取前三段作为网络前缀
    local base=$(echo "$subnet" | cut -d/ -f1 | cut -d. -f1-3)
    #复用scan
    cmd_scan "$base" .1 .254
}