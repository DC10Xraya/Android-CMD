#resource/cmd_download.bash
# ---------- DOWNLOAD 命令 ----------
cmd_download() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -eq 0 ]; then
    cecho -b "用法: DOWNLOAD <URL> <本地路径>"
    cecho "示例: DOWNLOAD https://speed.cloudflare.com/__down?bytes=10000000 /storage/emulated/0/download/114514.txt"
    cecho -c "#C0C0C0" "(按Ctrl+C终止下载并删除未完成文件)"
    return 0
    fi

    local url="$1"
    local local_path="$2"

    # 验证 URL 格式
    if ! echo "$url" | grep -qE '^https?://'; then
        err "无效的 URL,必须以 http:// 或 https:// 开头"
        return 1
    fi

    # 提取主机名
    local host
    host=$(echo "$url" | sed -e 's|^https\?://||' -e 's|/.*$||')
    if [ -z "$host" ]; then
        err "无法解析主机名"
        return 1
    fi

    # 检查本地路径
    local target_dir
    target_dir=$(dirname "$local_path")
    if [ ! -d "$target_dir" ]; then
        mkdir -p "$target_dir" 2>/dev/null || {
            err "无法创建目录: $target_dir"
            return 1
        }
    fi
    if [ ! -w "$target_dir" ]; then
        err "目标目录不可写: $target_dir"
        return 1
    fi
    if [ -e "$local_path" ]; then
        confirm "文件 $local_path 已存在,是否覆盖?" || { cecho "操作已取消"; return 0; }
        rm -f "$local_path" 2>/dev/null
    fi

    # 检测下载工具
    local dl_tool=""
    if command -v curl >/dev/null 2>&1; then
        dl_tool="curl"
    elif command -v wget >/dev/null 2>&1; then
        dl_tool="wget"
    else
        err "未找到 curl 或 wget,无法下载"
        return 1
    fi

    # ping 测试主机
    cecho "正在测试主机 $host ..."
    if ! ping -c 1 -W 3 "$host" >/dev/null 2>&1; then
        cecho "主机 $host 不可达"
        confirm "是否仍要尝试下载?" || { cecho "下载已取消"; return 0; }
    else
        cecho "主机 $host 可达"
    fi

    # 创建临时文件
    local tmp_base="${TMP_DIR:-/storage/emulated/0/tmp}"
    mkdir -p "$tmp_base" || {
        err "无法创建临时目录: $tmp_base"
        return 1
    }
    local tmp_file=$(mktemp -p "$tmp_base" 2>/dev/null || echo "$tmp_base/download_$$.tmp")
    if [ -z "$tmp_file" ]; then
        err "无法创建临时文件"
        return 1
    fi
    rm -f "$tmp_file" 2>/dev/null
    touch "$tmp_file" || {
        err "无法创建临时文件: $tmp_file"
        return 1
    }

    # 保存旧陷阱,设置自己的 INT 陷阱
    local old_trap=$(trap -p INT)
    local download_interrupted=0

    # 清理函数(使用普通版 _kill_process_tree)
    download_cleanup() {
        if [ -n "$download_pid" ] && kill -0 "$download_pid" 2>/dev/null; then
            _kill_process_tree "$download_pid"
        fi
        rm -f "$tmp_file" 2>/dev/null
    }

    # 中断处理: 设置标志
    trap 'download_interrupted=1' INT

    # 启动下载
    cecho -b "开始下载"
    local cmd=""
    if [ "$dl_tool" = "curl" ]; then
        cmd="curl -L -o \"$tmp_file\" \"$url\""
    else
        cmd="wget -O \"$tmp_file\" \"$url\""
    fi

    eval "$cmd" 2>/dev/null &
    local download_pid=$!

    # 获取当前时间戳(确保为数字)
    local start_time
    start_time=$(date +%s 2>/dev/null || echo 0)
    [ -z "$start_time" ] && start_time=0

    local last_size=0
    local speed=0
    local last_update=$start_time
    local cur_size=0

    # 主循环
    while kill -0 "$download_pid" 2>/dev/null; do
        # 检查 Ctrl+C 标志
        if [ $download_interrupted -eq 1 ]; then
            download_cleanup
            if [ -n "$old_trap" ]; then eval "$old_trap"; else trap - INT; fi
            printf "\n"  # 换行,避免与提示符粘连
            cecho -b "下载已终止"
            return 0
        fi

        # 获取当前已下载大小
        cur_size=$($_STAT -c %s "$tmp_file" 2>/dev/null || stat -c %s "$tmp_file" 2>/dev/null || ls -l "$tmp_file" | awk '{print $5}' 2>/dev/null)
        [ -z "$cur_size" ] && cur_size=0

        # 计算速度(若无法计算则置0)
        local now
        now=$(date +%s 2>/dev/null || echo 0)
        [ -z "$now" ] && now=0

        if [ $now -gt $last_update ] && [ $cur_size -ge $last_size ]; then
            speed=$(( (cur_size - last_size) / (now - last_update) ))
        else
            speed=0
        fi
        last_size=$cur_size
        last_update=$now

        # 计算已用时间
        local elapsed=$((now - start_time))
        [ $elapsed -lt 0 ] && elapsed=0

        # 格式化速度显示
        local speed_display="0"
        if [ $speed -gt 0 ]; then
            speed_display="$(numfmt --to=iec $speed 2>/dev/null || echo "$speed")/s"
        fi

        local progress_str="已下载: $(numfmt --to=iec $cur_size 2>/dev/null || echo "$cur_size B")"
        progress_str="$progress_str | 用时: ${elapsed}s"
        progress_str="$progress_str | 速度: $speed_display"

        printf "\r\033[K%s" "$progress_str"

        sleep 0.3
    done

    # 下载进程结束,等待退出码
    wait "$download_pid" 2>/dev/null
    local exit_code=$?
    printf "\n"

    # 恢复旧陷阱
    if [ -n "$old_trap" ]; then eval "$old_trap"; else trap - INT; fi

    # 判断是否因用户中断而结束(即使标志未捕获到)
    if [ $download_interrupted -eq 1 ] || [ $exit_code -eq 130 ]; then
        download_cleanup
        cecho -b "下载已终止"
        return 0
    fi

    if [ $exit_code -eq 0 ]; then
        # 下载成功,移动文件
        mv "$tmp_file" "$local_path" 2>/dev/null || {
            err "移动文件失败,请检查目标路径权限"
            rm -f "$tmp_file"
            return 1
        }
        # 获取最终文件大小
        local final_size
        final_size=$(stat -c %s "$local_path" 2>/dev/null || ls -l "$local_path" | awk '{print $5}')
        [ -z "$final_size" ] && final_size=0

        local total_time=$(( $(date +%s) - start_time ))
        [ $total_time -lt 1 ] && total_time=1

        local avg_speed=$((final_size / total_time))
        local avg_speed_display="0"
        if [ $avg_speed -gt 0 ]; then
            avg_speed_display="$(numfmt --to=iec $avg_speed 2>/dev/null || echo "$avg_speed")/s"
        fi

        cecho -b "下载完成: $local_path"
        cecho "数据大小: $(numfmt --to=iec $final_size 2>/dev/null || echo "$final_size B") / 所用时间: ${total_time}s / 平均速度: $avg_speed_display"
        return 0
    else
        rm -f "$tmp_file"
        err "下载失败 (退出码: $exit_code)"
        return $exit_code
    fi
}