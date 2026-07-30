#resource/cmd_urlencode.bash
cmd_urlencode() {
    local file_mode=0 input=""

    # 解析选项
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--file)
                file_mode=1
                shift
                if [[ -z "$1" ]] || [[ "$1" == -* ]]; then
                    err "选项 -f 需要指定文件路径"
                    return 1
                fi
                input="$1"
                shift
                ;;
            --)
                shift
                break
                ;;
            -*)
                err "未知选项: $1"
                return 1
                ;;
            *)
                # 非选项视为字符串
                if [[ -z "$input" ]] && [[ $file_mode -eq 0 ]]; then
                    input="$1"
                    shift
                else
                    err "多余的参数: $1"
                    return 1
                fi
                ;;
        esac
    done

    if [[ -z "$input" ]]; then
        err "用法: URLENCODE <字符串>/-f <文件>"
        cecho "  URLENCODE <字符串>           编码字符串"
        cecho "  URLENCODE -f <文件>          编码文件内容(按UTF-8字节)"
        return 1
    fi

    # 如果是文件模式, 检查文件存在
    if [[ $file_mode -eq 1 ]]; then
        if [[ ! -f "$input" ]]; then
            err "文件不存在: $input"
            return 1
        fi
    fi

    local encoded=""
    # 优先使用 xxd 按字节编码(最标准)
    if command -v xxd >/dev/null 2>&1; then
        if [[ $file_mode -eq 1 ]]; then
            encoded=$(xxd -p -c 256 "$input" | sed 's/\(..\)/%\1/g' | tr '[:lower:]' '[:upper:]')
        else
            encoded=$(printf '%s' "$input" | xxd -p -c 256 | sed 's/\(..\)/%\1/g' | tr '[:lower:]' '[:upper:]')
        fi
        # 还原安全字符(. _ ~ -)
        encoded=$(echo "$encoded" | sed -e 's/%2D/-/g' -e 's/%2E/./g' -e 's/%5F/_/g' -e 's/%7E/~/g')
        cecho "$encoded"
        return 0
    fi

    # 回退: 使用 od 逐字节
    if command -v od >/dev/null 2>&1; then
        if [[ $file_mode -eq 1 ]]; then
            encoded=$(od -An -tx1 < "$input" | tr -d ' \n' | sed 's/\(..\)/%\1/g')
        else
            encoded=$(printf '%s' "$input" | od -An -tx1 | tr -d ' \n' | sed 's/\(..\)/%\1/g')
        fi
        cecho "$encoded"
        return 0
    fi

    # 最终回退(仅支持 ASCII, 非 ASCII 会错误)
    err "警告: 未找到 xxd 或 od, 回退到不完整的 ASCII 编码, 多字节字符将错误编码"
    local c
    for (( i=0; i<${#input}; i++ )); do
        c="${input:i:1}"
        case "$c" in
            [a-zA-Z0-9._~-]) encoded+="$c" ;;
            *) printf -v hex '%02X' "'$c" ; encoded+="%$hex" ;;
        esac
    done
    cecho "$encoded"
}