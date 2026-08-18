#resource/cmd_whoami_op.bash
cmd_whoami_op() {
    # ---------- 获取当前用户名 ----------
    # 优先使用 $_WHOAMI, 失败则回退到 id -un, 最后显示 unknown
    local user="$($_WHOAMI 2>/dev/null || id -un 2>/dev/null || echo 'unknown')"
    local user_level=""

    # ---------- 权限状态检测 ------------
    # 1. ROOT 权限 
    if [ "$(id -u 2>/dev/null)" = "0" ] || [ "$(whoami 2>/dev/null)" = "root" ]; then
        user_level="ROOT用户"
    else
        # 2. Shizuku 环境(shell 用户 + app_process + shizuku)
        # 适配不同 Android 版本的 ps, 使用 $_PS 和 $_GREP
        local shizuku_detected=0
        if $_PS -A -o user,args 2>/dev/null | $_GREP -v grep | $_GREP -qE '^shell.*shizuku' 2>/dev/null; then
            shizuku_detected=1
        elif $_PS -e -o user,args 2>/dev/null | $_GREP -v grep | $_GREP -qE '^shell.*shizuku' 2>/dev/null; then
            shizuku_detected=1
        elif $_PS 2>/dev/null | $_GREP -v grep | $_GREP -qE 'shell.*shizuku' 2>/dev/null; then
            shizuku_detected=1
        fi

        if [ $shizuku_detected -eq 1 ]; then
            user_level="ADB调试 (Shizuku激活)"
        else
            # 3. 常规 ADB 调试环境
            local is_adb=0
            local tcp_port=""

            # 3.1 环境变量或父进程(最直接)
            if [ -n "$ADB_SHELL" ] || [ -n "$ASH_STARTED" ] || \
               (echo "$PPID" | xargs ps -o comm= 2>/dev/null | $_GREP -qi 'adbd'); then
                is_adb=1
            fi

            # 3.2 补充: 系统属性(用于显示端口信息, 但不作为唯一判断依据)
            local prop_tcpport=$(getprop service.adb.tcp.port 2>/dev/null)
            local prop_state=$(getprop init.svc.adbd 2>/dev/null)
            if [ "$prop_state" = "running" ]; then
                is_adb=1
            fi
            if [ -n "$prop_tcpport" ] && [ "$prop_tcpport" -gt 0 ] 2>/dev/null; then
                is_adb=1
                tcp_port="$prop_tcpport"
            fi

            # 4. 综合判断
            if [ $is_adb -eq 1 ]; then
                user_level="ADB调试"
                if [ -n "$tcp_port" ]; then
                    user_level="ADB调试 (网络调试已开启, 端口:$tcp_port)"
                fi
            else
                user_level="普通用户"
            fi
        fi
    fi

    # ---------- 统一输出 ----------
    cecho "当前用户: $user"
    cecho "当前权限状态: $user_level"
}