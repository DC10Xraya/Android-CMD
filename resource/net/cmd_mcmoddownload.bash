#resource/cmd_mcmoddownload.bash
cmd_mcmoddownload() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cecho -b "用法: MCMODDOWNLOAD"
        cecho "交互式从Modrinth下载MC Java模组"
        cecho "按提示输入版本、加载器、输出目录，然后输入模组列表"
        cecho "(每行一个 mod, Ctrl+D 结束，Ctrl+C 取消)"
        return 0
    fi

    # ---- trap: Ctrl+C 立即返回 ----
    local old_trap=$(trap -p INT)
    trap 'return 130' INT

    # ---- 读取函数 ----
    read_input() {
        local prompt="$1"
        local var_name="$2"
        local input
        if [[ -n "$prompt" ]]; then
            printf "\033[0m%s" "$prompt" >&2
        fi
        IFS= read -r input
        local ret=$?
        if [[ $ret -ne 0 ]]; then
            return 1
        fi
        eval "$var_name=\"$input\""
        return 0
    }

    # ---- 交互输入 ----
    local mc_ver loader output_dir
    if ! read_input "Minecraft JE 版本: " mc_ver; then
        eval "$old_trap" 2>/dev/null || trap - INT
        return 1
    fi
    if [[ -z "$mc_ver" ]]; then
        err "版本不能为空"
        eval "$old_trap" 2>/dev/null || trap - INT
        return 1
    fi

    if ! read_input "加载器 (默认 fabric，可留空): " loader; then
        eval "$old_trap" 2>/dev/null || trap - INT
        return 1
    fi
    [[ -z "$loader" ]] && loader="fabric"

    if ! read_input "输出目录 (留空自动生成): " output_dir; then
        eval "$old_trap" 2>/dev/null || trap - INT
        return 1
    fi
    if [[ -z "$output_dir" ]]; then
        local timestamp=$(date +%Y%m%d_%H%M%S)
        output_dir="$SCRIPT_DIR/mcmod_${mc_ver}_${loader}_${timestamp}"
        _cprint -c 32 -n "将自动创建目录: "
        _cprint -c 32 -u "$output_dir"
        echo ""
    fi

    mkdir -p "$output_dir" 2>/dev/null || {
        err "无法创建目录 $output_dir"
        eval "$old_trap" 2>/dev/null || trap - INT
        return 1
    }
    if [[ ! -w "$output_dir" ]]; then
        err "目录 $output_dir 不可写"
        eval "$old_trap" 2>/dev/null || trap - INT
        return 1
    fi
    cd "$output_dir" || {
        err "无法进入目录 $output_dir"
        eval "$old_trap" 2>/dev/null || trap - INT
        return 1
    }

    # ---- 读取模组列表 ----
    local slugs=()
    cecho "请输入模组列表 (每行一个 mod，按 Ctrl+D 确认，Ctrl+C 取消):"
    while true; do
        local line
        IFS= read -r line
        local ret=$?
        if [[ $ret -ne 0 ]]; then
            break
        fi
        [[ -z "$line" ]] && continue
        slugs+=("$line")
    done

    if [[ ${#slugs[@]} -eq 0 ]]; then
        err "未输入任何模组"
        eval "$old_trap" 2>/dev/null || trap - INT
        return 0
    fi

    # ---- 确认下载 ----
    echo ""
    printf "\033[1;33m确认下载? [Y/n]: \033[0m"
    local confirm_ans
    if ! read_input "" confirm_ans; then
        eval "$old_trap" 2>/dev/null || trap - INT
        return 0
    fi
    case "$confirm_ans" in
        [Yy]) ;;
        *) eval "$old_trap" 2>/dev/null || trap - INT; return 0 ;;
    esac

    # ---- 下载循环 ----
    local success=0 fail=0
    for slug in "${slugs[@]}"; do
        _cprint -c "#C0C0C0" -n "🔍 正在查找: "
        cecho "$slug"

        local api_url="https://api.modrinth.com/v2/project/$slug/version?loaders=%5B%22$loader%22%5D&game_versions=%5B%22$mc_ver%22%5D"
        local response=$(curl -s "$api_url")
        if [[ "$response" == "[]" ]]; then
            err "   ❌ 未找到支持 $mc_ver + $loader 的版本"
            ((fail++))
            continue
        fi

        local url=$(echo "$response" | grep -o '"files":\[[^]]*"url":"[^"]*"' | head -1 | sed 's/.*"url":"\([^"]*\)".*/\1/')
        if [[ -n "$url" ]]; then
            local filename=$(basename "$url")
            _cprint -c 32 "   ✅ 找到: $filename"

            if [[ -f "$filename" ]]; then
                _cprint -c 33 -n "文件 $filename 已存在，覆盖? [Y/n]: "
                local cover_ans
                if ! read_input "" cover_ans; then
                    eval "$old_trap" 2>/dev/null || trap - INT
                    return 0
                fi
                case "$cover_ans" in
                    [Yy]) ;;
                    *) cecho "   ⏭️  跳过"; continue ;;
                esac
            fi

            wget -q --show-progress "$url" -O "$filename"
            if [[ $? -eq 0 ]]; then
                _cprint -c 32 "   ✅ 下载完成"
                ((success++))
            else
                err "   ❌ 下载失败"
                ((fail++))
            fi
        else
            err "   ⚠️  服务器返回非空但未提取到下载链接"
            ((fail++))
        fi
    done

    # ---- 结果 ----
    echo ""
    cecho "=== 完成 ==="
    _cprint -c 32 -n "成功: $success"
    if (( fail > 0 )); then
        err " 失败: $fail"
    else
        _cprint -c 32 " 失败: $fail"
    fi
    _cprint -c 32 -n "文件保存在: "
    _cprint -c 32 -u "$(pwd)"
    echo ""

    eval "$old_trap" 2>/dev/null || trap - INT
}