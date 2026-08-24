#resource/cmd_diskt.bash
cmd_diskt() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        cecho -b "用法: DISKT [选项]"
        cecho "  快速估算 TMPDIR 目录下的磁盘性能"
        cecho "  选项:"
        cecho "    -s SIZE    测试文件大小 (MB, 默认 1024)"
        cecho "    -b BS      顺序块大小 (MB, 默认 64)"
        cecho "    -r BS      随机块大小 (MB, 默认 8)"
        cecho "    -n COUNT   随机操作次数 (默认 50)"
        cecho "    -c         缓存模式 (不使用 fsync)"
        cecho "    -p         使用 cp 测试实际文件复制速度"
        cecho "    -h, --help 显示本帮助"
        err "  注意: 结果仅供参考, 精确测试建议使用 AndroBench"
        return 0
    fi

    local file_size_mb=1024
    local seq_bs_mb=64
    local rand_bs_mb=8
    local rand_count=50
    local cache_mode=0
    local cp_mode=0

    while [ $# -gt 0 ]; do
        case "$1" in
            -s) file_size_mb="$2"; shift 2 ;;
            -b) seq_bs_mb="$2"; shift 2 ;;
            -r) rand_bs_mb="$2"; shift 2 ;;
            -n) rand_count="$2"; shift 2 ;;
            -c) cache_mode=1; shift ;;
            -p) cp_mode=1; shift ;;
            *) err "未知选项: $1, 使用 DISKT -h 查看帮助"; return 1 ;;
        esac
    done

    # ---------- 信号处理 ----------
    local old_int_trap=$(trap -p INT)
    local old_exit_trap=$(trap -p EXIT)
    local test_file="" test_file2=""

    _cleanup_diskt() {
        [ -n "$test_file" ] && rm -f "$test_file" 2>/dev/null
        [ -n "$test_file2" ] && rm -f "$test_file2" 2>/dev/null
    }
    # 确保函数返回时清理
    trap '_cleanup_diskt' RETURN
    # EXIT 陷阱作为最后防线
    trap '_cleanup_diskt; eval "$old_int_trap" 2>/dev/null || trap - INT; eval "$old_exit_trap" 2>/dev/null || trap - EXIT' EXIT
    # 中断时清理并返回
    trap '_cleanup_diskt; return 130' INT
    # -----------------------------

    for tool in dd date awk cp; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            err "缺少必要工具: $tool"
            return 1  # RETURN 陷阱会触发
        fi
    done

    local test_dir="$TMP_DIR"
    if [ ! -d "$test_dir" ] || [ ! -w "$test_dir" ]; then
        err "临时目录不可用: $test_dir, 请设置 TMPDIR"
        return 1
    fi

    test_file="$test_dir/disktest_$$"
    test_file2="$test_dir/disktest2_$$"
    local seq_bs_bytes=$((seq_bs_mb * 1024 * 1024))
    local rand_bs_bytes=$((rand_bs_mb * 1024 * 1024))
    local total_bytes=$((file_size_mb * 1024 * 1024))
    local seq_count=$((total_bytes / seq_bs_bytes))
    [ $seq_count -eq 0 ] && seq_count=1

    local avail_kb=$(df -k "$test_dir" 2>/dev/null | awk 'NR==2 {print $4}')
    if [ -n "$avail_kb" ] && [ $((avail_kb * 1024)) -lt $((total_bytes * 3)) ]; then
        err "可用空间不足: 需要至少 $((total_bytes * 3 / 1024 / 1024)) MB, 当前仅有 ${avail_kb}KB"
        return 1
    fi

    _time_cmd() {
        local start=$(date +%s%N 2>/dev/null || date +%s)
        eval "$@"
        local ret=$?
        local end=$(date +%s%N 2>/dev/null || date +%s)
        if [ -z "$start" ] || [ -z "$end" ]; then echo "0"; return $ret; fi
        if [[ "$start" =~ ^[0-9]+$ ]] && [ ${#start} -eq 10 ]; then
            echo "$((end - start)).0"
        else
            local diff=$(( (end - start) / 1000000000 ))
            local frac=$(( (end - start) % 1000000000 ))
            echo "${diff}.${frac}"
        fi
        return $ret
    }

    if [ $cp_mode -eq 1 ]; then
        cecho "复制测试 (生成 ${file_size_mb}MB 文件并复制)..."
        dd if=/dev/urandom of="$test_file" bs=1M count=$file_size_mb 2>/dev/null
        local time_cp=$( _time_cmd "cp '$test_file' '$test_file2'" )
        local speed_cp=$(awk "BEGIN {printf \"%.2f\", $file_size_mb / $time_cp}")
        cecho "文件复制: ${speed_cp} MB/s (耗时 ${time_cp}s)"
        local time_read_cp=$( _time_cmd "dd if='$test_file2' of=/dev/null bs=1M 2>/dev/null" )
        local speed_read_cp=$(awk "BEGIN {printf \"%.2f\", $file_size_mb / $time_read_cp}")
        cecho "复制后读取: ${speed_read_cp} MB/s (耗时 ${time_read_cp}s)"
        return 0  # RETURN 陷阱会清理
    fi

    # ---------- 顺序写 ----------
    cecho "顺序写测试 (${file_size_mb} MB, 块大小 ${seq_bs_mb}MB)..."
    local dd_write_opts="bs=$seq_bs_bytes count=$seq_count"
    if [ $cache_mode -eq 0 ]; then
        dd_write_opts="$dd_write_opts conv=fsync"
        local write_label="(fsync)"
    else
        local write_label="(缓存)"
    fi
    local time_w=$( _time_cmd "dd if=/dev/zero of='$test_file' $dd_write_opts 2>/dev/null" )
    local ret_w=$?
    if [ $ret_w -ne 0 ]; then err "顺序写失败"; return 1; fi
    local speed_w=$(awk "BEGIN {printf \"%.2f\", $file_size_mb / $time_w}")
    cecho "顺序写: ${speed_w} MB/s (耗时 ${time_w}s) ${write_label}"

    # ---------- 顺序读 ----------
    cecho "顺序读测试..."
    if ! dd if=/dev/null of=/dev/null iflag=direct 2>/dev/null; then
        err "警告: 设备不支持 direct I/O, 读测试可能受缓存影响"
    fi
    sync 2>/dev/null
    local time_r=$( _time_cmd "dd if='$test_file' of=/dev/null bs=$seq_bs_bytes 2>/dev/null" )
    if [ $? -ne 0 ]; then err "顺序读失败"; return 1; fi
    local speed_r=$(awk "BEGIN {printf \"%.2f\", $file_size_mb / $time_r}")
    cecho "顺序读: ${speed_r} MB/s (耗时 ${time_r}s)"

    # ---------- 随机写 ----------
    cecho "随机写测试 (${rand_count} 次, 块大小 ${rand_bs_mb}MB)..."
    local total_rand_bytes=$((rand_count * rand_bs_bytes))
    local max_offset=$((total_bytes - rand_bs_bytes))
    if [ $max_offset -le 0 ]; then err "测试文件太小, 无法随机测试"; return 1; fi
    local offsets=()
    for i in $(seq 1 $rand_count); do
        local off=$(( (RANDOM << 15) + RANDOM ))
        off=$(( off % max_offset ))
        off=$(( off / rand_bs_bytes * rand_bs_bytes ))
        offsets+=($off)
    done
    local start_wr=$(date +%s%N 2>/dev/null || date +%s)
    for off in "${offsets[@]}"; do
        dd if=/dev/zero of="$test_file" bs=$rand_bs_bytes count=1 seek=$((off / rand_bs_bytes)) conv=notrunc 2>/dev/null
        if [ $? -ne 0 ]; then err "随机写失败"; return 1; fi
    done
    sync 2>/dev/null
    local end_wr=$(date +%s%N 2>/dev/null || date +%s)
    local time_wr=$(awk "BEGIN {printf \"%.2f\", ($end_wr - $start_wr) / 1e9}")
    local speed_wr=$(awk "BEGIN {printf \"%.2f\", $total_rand_bytes / 1024 / 1024 / $time_wr}")
    cecho "随机写: ${speed_wr} MB/s (耗时 ${time_wr}s)"

    # ---------- 随机读 ----------
    cecho "随机读测试 (${rand_count} 次, 块大小 ${rand_bs_mb}MB)..."
    local start_rd=$(date +%s%N 2>/dev/null || date +%s)
    for off in "${offsets[@]}"; do
        dd if="$test_file" of=/dev/null bs=$rand_bs_bytes count=1 skip=$((off / rand_bs_bytes)) 2>/dev/null
        if [ $? -ne 0 ]; then err "随机读失败"; return 1; fi
    done
    local end_rd=$(date +%s%N 2>/dev/null || date +%s)
    local time_rd=$(awk "BEGIN {printf \"%.2f\", ($end_rd - $start_rd) / 1e9}")
    local speed_rd=$(awk "BEGIN {printf \"%.2f\", $total_rand_bytes / 1024 / 1024 / $time_rd}")
    cecho "随机读: ${speed_rd} MB/s (耗时 ${time_rd}s)"

    # 汇总
    cecho "$CMD_delimiter"
    cecho -b "测速结果:"
    cecho "  顺序写: ${speed_w} MB/s ${write_label}"
    cecho "  顺序读: ${speed_r} MB/s"
    cecho "  随机写: ${speed_wr} MB/s"
    cecho "  随机读: ${speed_rd} MB/s"
    err "  注意: 结果仅供参考, 精确测试建议使用 AndroBench"
    cecho "$CMD_delimiter"

    return 0   # RETURN 陷阱会清理
}