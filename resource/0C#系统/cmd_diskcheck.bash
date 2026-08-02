#resource/cmd_diskcheck.bash
# ---------- 磁盘速度检测（使用 Emoji 彩色符号） ----------
cmd_diskcheck() {
    local timeout_ms=2000
    local writable_only=0
    local quiet=0
    local args=("$@")

    # 解析参数
    while [ $# -gt 0 ]; do
        case "$1" in
            -w|--writable) writable_only=1; shift ;;
            -q|--quiet)    quiet=1; shift ;;
            [0-9]*)        timeout_ms="$1"; shift ;;
            *)             shift ;;
        esac
    done
    cecho "准备中...可能需要一定时间,按Ctrl+C随时终止"
    # 信号处理
    local old_trap=$(trap -p INT)
    local -a temp_files=()
    local interrupted=0

    _cleanup_diskcheck() {
        for f in "${temp_files[@]}"; do
            [ -f "$f" ] && rm -f "$f" 2>/dev/null
        done
        temp_files=()
    }
    trap 'interrupted=1; _cleanup_diskcheck; return 130' INT

    # 收集所有非虚拟挂载点
    local mount_points=()
    while IFS= read -r line; do
        local mp=$(echo "$line" | awk '{print $2}')
        if [[ "$mp" != "/dev" && "$mp" != "/sys" && "$mp" != "/proc" &&
              "$mp" != "/tmp" && "$mp" != "/mnt" && "$mp" != "/storage/self" &&
              ! "$mp" =~ ^/dev/ && ! "$mp" =~ ^/sys/ && ! "$mp" =~ ^/proc/ ]]; then
            if [ $writable_only -eq 1 ]; then
                if touch "$mp/.writetest_$$" 2>/dev/null; then
                    rm -f "$mp/.writetest_$$" 2>/dev/null
                    mount_points+=("$mp")
                fi
            else
                if ls "$mp" >/dev/null 2>&1; then
                    mount_points+=("$mp")
                fi
            fi
        fi
    done < /proc/mounts

    if [ ${#mount_points[@]} -eq 0 ]; then
        echo "未找到任何可读挂载点"
        eval "$old_trap" 2>/dev/null || trap - INT
        return 1
    fi

    echo "磁盘速度检测 (超时: ${timeout_ms}ms)  $([ $writable_only -eq 1 ] && echo "(仅可写)" || echo "(全部可读)")"
    echo "----------------------------------------"

    # 测试单个挂载点（读 10MB 数据, 尝试绕过缓存）
    _test_mountpoint() {
        local mp="$1"
        local tempfile="$mp/.speedtest_$$"
        local test_file=""
        local use_readonly=0

        # 尝试写入测试（若可写）
        if touch "$tempfile" 2>/dev/null && dd if=/dev/zero of="$tempfile" bs=1M count=10 2>/dev/null; then
            test_file="$tempfile"
            temp_files+=("$tempfile")
        else
            # 不可写 -> 寻找一个大小适中的文件（至少 1MB）
            local found=""
            for f in "build.prop" "default.prop"; do
                if [ -f "$mp/$f" ] && [ -r "$mp/$f" ]; then
                    local sz=$(stat -c%s "$mp/$f" 2>/dev/null || echo 0)
                    if [ "$sz" -gt 102400 ] && [ "$sz" -lt 20971520 ]; then
                        found="$mp/$f"
                        break
                    fi
                fi
            done
            if [ -z "$found" ]; then
                found=$(find "$mp" -maxdepth 3 -type f -size +1M -size -20M 2>/dev/null | head -1)
            fi
            if [ -n "$found" ] && [ -r "$found" ]; then
                test_file="$found"
                use_readonly=1
            else
                return  # 静默跳过
            fi
        fi

        # 读取测试（10MB）
        local start_time end_time
        local dd_opts="bs=1M count=10"
        if dd if=/dev/zero of=/dev/null iflag=direct 2>/dev/null; then
            dd_opts="$dd_opts iflag=direct"
        fi

        if date +%s%N >/dev/null 2>&1; then
            start_time=$(date +%s%N)
            dd if="$test_file" of=/dev/null $dd_opts 2>/dev/null
            end_time=$(date +%s%N)
            local elapsed_ns=$((end_time - start_time))
            local elapsed_ms=$((elapsed_ns / 1000000))
        else
            start_time=$(date +%s)
            dd if="$test_file" of=/dev/null $dd_opts 2>/dev/null
            end_time=$(date +%s)
            local elapsed_ms=$(( (end_time - start_time) * 1000 ))
        fi

        # 清理临时文件
        if [ "$test_file" = "$tempfile" ]; then
            rm -f "$tempfile" 2>/dev/null
        fi

        # 判断速度和 Emoji
        local icon="🔴"
        local display_speed="N/A"
        if [ $elapsed_ms -eq 0 ] || [ $elapsed_ms -gt $timeout_ms ]; then
            display_speed=">${timeout_ms}ms"
            icon="🔴"
        else
            local speed=$(echo "scale=2; (10 * 1000) / $elapsed_ms" | bc 2>/dev/null || echo "0")
            [ -z "$speed" ] && speed=0
            display_speed="${speed} MB/s"
            if (( $(echo "$speed > 50" | bc -l) )); then
                icon="🟢"
            elif (( $(echo "$speed > 20" | bc -l) )); then
                icon="🟡"
            else
                icon="🔴"
            fi
        fi

        # 输出（路径截断至 40 字符）
        local display_path="$mp"
        if [ ${#display_path} -gt 40 ]; then
            display_path="...${display_path: -37}"
        fi

        if [ $quiet -eq 1 ]; then
            printf "%-40s : %s\n" "$display_path" "$icon"
        else
            printf "%-40s : %8s  %s\n" "$display_path" "$display_speed" "$icon"
        fi
    }

    for mp in "${mount_points[@]}"; do
        [ $interrupted -eq 1 ] && break
        _test_mountpoint "$mp"
    done

    _cleanup_diskcheck
    eval "$old_trap" 2>/dev/null || trap - INT
    [ $interrupted -eq 1 ] && return 130
    return 0
}