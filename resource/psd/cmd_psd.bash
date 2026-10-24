#resource/cmd_psd.bash
cmd_psd() {
    local length=16
    local count=1
    local charset=""
    local use_alnum=0
    local use_upper=0
    local use_lower=0
    local use_digit=0
    local use_special=0
    local custom_charset=""

    # 如果无参数,直接生成默认密码(保持旧行为)
    if [ $# -eq 0 ]; then
        length=16
        charset="[:graph:]"
        password=$(tr -dc "$charset" < /dev/urandom 2>/dev/null | head -c "$length")
        [ -n "$password" ] && cecho "$password" || err "生成失败"
        return $?
    fi

    # 解析参数
    while [ $# -gt 0 ]; do
        case "$1" in
            -n)
                if [[ $2 =~ ^[0-9]+$ ]] && [ $2 -gt 0 ]; then
                    length="$2"
                    shift 2
                else
                    err "选项 -n 需要正整数"
                    return 1
                fi
                ;;
            -C|--count)
                if [[ $2 =~ ^[0-9]+$ ]] && [ $2 -gt 0 ]; then
                    count="$2"
                    shift 2
                else
                    err "选项 -C 需要正整数"
                    return 1
                fi
                ;;
            -a)
                use_alnum=1
                shift
                ;;
            -u)
                use_upper=1
                shift
                ;;
            -l)
                use_lower=1
                shift
                ;;
            -d)
                use_digit=1
                shift
                ;;
            -s)
                use_special=1
                shift
                ;;
            -c)
                if [ -z "$2" ]; then
                    err "选项 -c 需要指定字符集"
                    return 1
                fi
                custom_charset="$2"
                shift 2
                ;;
            -h|--help)
                cecho "用法: PSD [-n 长度] [-C 数量] [-a] [-u] [-l] [-d] [-s] [-c 字符集]"
                cecho "  -n 长度      密码长度 (默认 16)"
                cecho "  -C 数量      生成多个密码 (默认 1)"
                cecho "  -a           仅使用字母和数字 (快捷选项)"
                cecho "  -u           仅使用大写字母"
                cecho "  -l           仅使用小写字母"
                cecho "  -d           仅使用数字"
                cecho "  -s           仅使用特殊字符 (!@#$%^&*()_+-=[]{}|;:,.<>?/~)"
                cecho "  -c 字符集    自定义字符集 (覆盖其他字符集选项)"
                cecho "  若不指定任何字符集选项,默认使用可打印字符 (不含空格)"
                cecho "  多个选项可组合,如 -u -d 表示大写字母+数字"
                return 0
                ;;
            -*)
                err "未知选项: $1"
                return 1
                ;;
            *)
                # 兼容旧用法:直接数字作为长度
                if [[ $1 =~ ^[0-9]+$ ]] && [ -z "$custom_length" ]; then
                    length="$1"
                    shift
                else
                    err "多余的参数: $1"
                    return 1
                fi
                ;;
        esac
    done

    # ---------- 确定字符集 ----------
    # 优先级:自定义 > -a > 组合选项 (-u/-l/-d/-s) > 默认(可打印)
    if [ -n "$custom_charset" ]; then
        charset="$custom_charset"
    elif [ $use_alnum -eq 1 ]; then
        charset='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    else
        # 构建组合字符集
        local combined=""
        [ $use_upper -eq 1 ] && combined+='ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        [ $use_lower -eq 1 ] && combined+='abcdefghijklmnopqrstuvwxyz'
        [ $use_digit -eq 1 ] && combined+='0123456789'
        [ $use_special -eq 1 ] && combined+='!@#$%^&*()_+-=[]{}|;:,.<>?/~'
        if [ -n "$combined" ]; then
            charset="$combined"
        else
            # 未指定任何选项,默认使用所有可打印字符(不含空格)
            charset='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+-=[]{}|;:,.<>?/~'
        fi
    fi

    # ---------- 生成密码 ----------
    local password
    local generated_count=0
    local success=0

    # 生成函数(使用 /dev/urandom 或备选)
    _gen_one() {
        local len="$1"
        local pool="$2"
        local pwd=""
        # 优先使用 /dev/urandom + tr
        if [ -r /dev/urandom ]; then
            pwd=$(tr -dc "$pool" < /dev/urandom 2>/dev/null | head -c "$len")
        elif command -v openssl >/dev/null 2>&1; then
            # openssl rand 可能输出二进制,用 base64 后截取,但 base64 字符集有限,所以只适用于字母数字,特殊字符需单独处理
            # 这里我们采用更通用的方式:使用 openssl rand 生成随机字节,然后转成十六进制取模
            # 但为简化,如果池中字符不超过 62 个(字母数字),可用 base64
            local pool_clean=$(echo "$pool" | tr -d '\\')
            if [[ "$pool" =~ ^[A-Za-z0-9]+$ ]]; then
                pwd=$(openssl rand -base64 $((len*3/4)) 2>/dev/null | tr -dc "$pool_clean" | head -c "$len")
            else
                # 特殊字符,回退到 $RANDOM 方法
                local pool_len=${#pool}
                for ((i=0; i<len; i++)); do
                    local idx=$((RANDOM % pool_len))
                    pwd="${pwd}${pool:$idx:1}"
                done
            fi
        else
            # 纯 Bash 随机
            local pool_len=${#pool}
            for ((i=0; i<len; i++)); do
                local idx=$((RANDOM % pool_len))
                pwd="${pwd}${pool:$idx:1}"
            done
        fi
        echo "$pwd"
    }

    # 循环生成 count 个密码
    for ((i=1; i<=count; i++)); do
        password=$(_gen_one "$length" "$charset")
        if [ -n "$password" ] && [ ${#password} -eq "$length" ]; then
            cecho "$password"
            success=1
        else
            # 如果生成失败(如长度不足),尝试用纯 Bash 方法重试一次
            local pool_len=${#charset}
            password=""
            for ((j=0; j<length; j++)); do
                local idx=$((RANDOM % pool_len))
                password="${password}${charset:$idx:1}"
            done
            if [ ${#password} -eq "$length" ]; then
                cecho "$password"
                success=1
            else
                err "生成第 $i 个密码失败"
                return 1
            fi
        fi
    done

    [ $success -eq 1 ] && return 0 || return 1
}