#resource/cmd_urldecode.bash
cmd_urldecode() {
    local file_mode=0 input=""

    # 解析选项(与之前相同)
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
        err "用法: URLDECODE <URL编码字符串>/-f <文件>"
        cecho "  URLDECODE <URL编码字符串>           解码字符串"
        cecho "  URLDECODE -f <文件>                  解码文件内容(按UTF-8字节)"
        return 1
    fi

    # 文件模式读取内容
    if [[ $file_mode -eq 1 ]]; then
        if [[ ! -f "$input" ]]; then
            err "文件不存在: $input"
            return 1
        fi
        input=$(cat "$input" 2>/dev/null)
        if [[ -z "$input" ]]; then
            err "文件为空或读取失败"
            return 1
        fi
    fi

    # 替换 + 为空格
    input="${input//+/ }"

    # 优先使用 xxd 解码(最安全可靠)
    if command -v xxd >/dev/null 2>&1; then
        # 将 %XX 转为十六进制字节流, 然后 xxd -r -p 还原
        printf '%s' "$input" | sed 's/%\([0-9A-Fa-f]\{2\}\)/\1/g' | xxd -r -p 2>/dev/null
        local ret=$?
        if [[ $ret -eq 0 ]]; then
            printf '\n'   # 补换行
            return 0
        fi
        # 若失败, 回退到 printf 方法(见下文)
    fi

    # 回退: 手动构建 decoded 字符串, 用 printf '%b' 安全输出(转义反斜杠)
    local decoded=""
    local i=0
    while [[ $i -lt ${#input} ]]; do
        local c="${input:i:1}"
        if [[ "$c" == '%' ]]; then
            local hex="${input:i+1:2}"
            # 构建 \x 转义序列
            printf -v ch '\\x%02x' "0x$hex" 2>/dev/null
            decoded+="$ch"
            i=$((i+3))
        else
            # 普通字符, 若为反斜杠则转义为两个反斜杠
            if [[ "$c" == '\' ]]; then
                decoded+='\\\\'
            else
                decoded+="$c"
            fi
            i=$((i+1))
        fi
    done

    # 使用 printf '%b' 解释转义序列, 同时避免额外换行问题
    printf '%b\n' "$decoded"
}