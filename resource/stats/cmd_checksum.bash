_resolve_out_file() {
    local target="$1" name="$2"
    if [ -d "$target" ]; then
        printf '%s/%s_%s.txt' "${target%/}" "$name" "$(date +%Y%m%d_%H%M%S)_$$"
    else
        printf '%s' "$target"
    fi
}

cmd_checksum() {
    err "请使用具体命令: sha256, sha1, sha224, sha384, sha512, md5, b2sum, crc32, b64, b32"
    return 1
}

# ---------- 哈希 / 校验 / 编码 合集 ----------
# 包含: md5, sha1, sha224, sha256, sha384, sha512, b2sum, crc32, base64, base32
# ==================================================================
# MD5
# ==================================================================
#resource/cmd_md5.bash
cmd_md5() {
    if [ $# -eq 0 ]; then
        ccat <<'EOF'
//cecho -b "用法: MD5/MD5SUM [参数] [数据...]"
  -f <文件>            计算文件的 MD5 哈希
  -d <字符串>          计算字符串的 MD5 哈希
  -C <目标> <文件...>  校验多个文件, 逐个输出是否符合目标
  -c <目标> <哈希...>  校验多个哈希, 逐个输出是否符合目标
  -u                   输出大写哈希
  -o <文件|目录>       写入文件; 为目录时自动命名 <cmd>_<时间>.txt
  --tag                BSD 风格输出
  --status             不输出任何内容(仅退出码)
  -q                   只输出哈希, 不显示文件名
  -h, --help           显示此帮助
EOF
        err "警告: MD5 已不安全, 仅用于非安全场景 (如快速去重)"
        return 0
    fi

    local mode="" mode_opt=""
    local out_upper=0 out_file="" bsd_tag=0 status_only=0 quiet=0
    local -a positional=()

    while [ $# -gt 0 ]; do
        case "$1" in
            -f|-d|-c|-C)
                if [ -n "$mode" ]; then err "不能同时指定 $mode_opt 和 $1"; return 1; fi
                mode_opt="$1"
                case "$1" in
                    -f) mode="file" ;;
                    -d) mode="string" ;;
                    -c) mode="check_hashes" ;;
                    -C) mode="check_files" ;;
                esac
                shift ;;
            -u) out_upper=1; shift ;;
            --tag) bsd_tag=1; shift ;;
            --status) status_only=1; shift ;;
            -q) quiet=1; shift ;;
            -o)
                if [ -z "${2:-}" ]; then err "缺少输出文件参数"; return 1; fi
                out_file=$(_resolve_out_file "$2" "md5"); shift 2 ;;
            -h|--help)
                ccat <<'EOF'
//cecho -b "用法: MD5/MD5SUM [参数] [数据...]"
  -f <文件>            计算文件的 MD5 哈希
  -d <字符串>          计算字符串的 MD5 哈希
  -C <目标> <文件...>  校验多个文件, 逐个输出是否符合目标
  -c <目标> <哈希...>  校验多个哈希, 逐个输出是否符合目标
  -u                   输出大写哈希
  -o <文件|目录>       写入文件; 为目录时自动命名 <cmd>_<时间>.txt
  --tag                BSD 风格输出
  --status             不输出任何内容(仅退出码)
  -q                   只输出哈希, 不显示文件名
  -h, --help           显示此帮助
EOF
                err "警告: MD5 已不安全, 仅用于非安全场景 (如快速去重)"
                return 0 ;;
            --) shift; while [ $# -gt 0 ]; do positional+=("$1"); shift; done ;;
            -*) err "未知参数: $1, 使用 MD5/MD5SUM -h 查看帮助"; return 1 ;;
            *) positional+=("$1"); shift ;;
        esac
    done

    if [ -z "$mode" ]; then err "缺少模式参数 (-f/-d/-c/-C), 使用 MD5/MD5SUM -h 查看帮助"; return 1; fi
    if [ "$status_only" = "1" ]; then
        case "$mode" in check_files|check_hashes) ;; *) err "--status 只能与 -c/-C 一起使用"; return 1 ;; esac
    fi

    local data="" expected=""
    local -a multi_args=()
    case "$mode" in
        file|string)
            if [ ${#positional[@]} -eq 0 ]; then err "缺少数据参数, 使用 MD5/MD5SUM -h 查看帮助"; return 1; fi
            if [ ${#positional[@]} -gt 1 ]; then err "模式 $mode_opt 只接受一个参数, 多余: ${positional[*]:1}"; return 1; fi
            data="${positional[0]}" ;;
        check_files|check_hashes)
            if [ ${#positional[@]} -lt 1 ]; then err "缺少目标参数, 使用 MD5/MD5SUM -h 查看帮助"; return 1; fi
            expected="${positional[0]}"
            multi_args=("${positional[@]:1}")
            if [ ${#multi_args[@]} -eq 0 ]; then err "缺少待校验参数"; return 1; fi ;;
    esac

    local cmd_sha=""
    if command -v md5sum >/dev/null 2>&1; then
        cmd_sha="md5sum"
    elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | $_GREP -q md5sum; then
        cmd_sha="busybox md5sum"
    elif command -v openssl >/dev/null 2>&1; then
        cmd_sha="openssl md5"
    else
        err "未找到可用的 MD5 计算工具 (md5sum, busybox, openssl)"
        return 1
    fi

    _md5_run() {
        _h_file() {
            if [[ "$cmd_sha" == openssl* ]]; then
                $cmd_sha "$1" 2>/dev/null | $_AWK '{print $NF}'
            else
                $cmd_sha "$1" 2>/dev/null | $_AWK '{print $1}'
            fi
        }
        _h_str() {
            if [[ "$cmd_sha" == openssl* ]]; then
                printf "%s" "$1" | $cmd_sha 2>/dev/null | $_AWK '{print $NF}'
            else
                printf "%s" "$1" | $cmd_sha 2>/dev/null | $_AWK '{print $1}'
            fi
        }
        _case() {
            if [ "$out_upper" = "1" ]; then printf '%s' "$1" | tr 'a-f' 'A-F'; else printf '%s' "$1"; fi
        }
        case "$mode" in
            file)
                [ ! -f "$data" ] && { err "文件不存在: $data"; return 1; }
                local h; h=$(_h_file "$data")
                [ -z "$h" ] && { err "计算 MD5 失败"; return 1; }
                h=$(_case "$h")
                if [ "$quiet" = "1" ]; then printf '%s\n' "$h"
                elif [ "$bsd_tag" = "1" ]; then printf 'MD5 (%s) = %s\n' "$data" "$h"
                else printf '%s  %s\n' "$h" "$data"; fi ;;
            string)
                local h; h=$(_h_str "$data")
                [ -z "$h" ] && { err "计算 MD5 失败"; return 1; }
                h=$(_case "$h")
                if [ "$quiet" = "1" ]; then printf '%s\n' "$h"
                elif [ "$bsd_tag" = "1" ]; then printf 'MD5 ("%s") = %s\n' "$data" "$h"
                else printf '%s\n' "$h"; fi ;;
            check_files)
                local exp_lower; exp_lower=$(printf '%s' "$expected" | tr 'A-Z' 'a-z')
                local failed=0 f h h_lower
                for f in "${multi_args[@]}"; do
                    if [ ! -f "$f" ]; then
                        [ "$status_only" = "1" ] || err "文件不存在: $f"
                        failed=1; continue
                    fi
                    h=$(_h_file "$f")
                    if [ -z "$h" ]; then
                        [ "$status_only" = "1" ] || err "计算 MD5 失败: $f"
                        failed=1; continue
                    fi
                    h_lower=$(printf '%s' "$h" | tr 'A-Z' 'a-z')
                    if [ "$h_lower" = "$exp_lower" ]; then
                        if [ "$status_only" != "1" ]; then
                            if [ "$quiet" = "1" ]; then printf '%s\n' "$f"
                            elif [ "$bsd_tag" = "1" ]; then cecho -c 92 "MD5 ($f) = OK"
                            else cecho -c 92 "$f: 符合"; fi
                        fi
                    else
                        if [ "$status_only" != "1" ] && [ "$quiet" != "1" ]; then
                            if [ "$bsd_tag" = "1" ]; then err "MD5 ($f) = FAILED"
                            else err "$f: 不符合"; fi
                        fi
                        failed=1
                    fi
                done
                return "$failed" ;;
            check_hashes)
                local exp_lower; exp_lower=$(printf '%s' "$expected" | tr 'A-Z' 'a-z')
                local failed=0 h h_lower
                for h in "${multi_args[@]}"; do
                    h_lower=$(printf '%s' "$h" | tr 'A-Z' 'a-z')
                    if [ "$h_lower" = "$exp_lower" ]; then
                        if [ "$status_only" != "1" ]; then
                            if [ "$quiet" = "1" ]; then printf '%s\n' "$h"
                            elif [ "$bsd_tag" = "1" ]; then cecho -c 92 "MD5 ($h) = OK"
                            else cecho -c 92 "$h: 符合"; fi
                        fi
                    else
                        if [ "$status_only" != "1" ] && [ "$quiet" != "1" ]; then
                            if [ "$bsd_tag" = "1" ]; then err "MD5 ($h) = FAILED"
                            else err "$h: 不符合"; fi
                        fi
                        failed=1
                    fi
                done
                return "$failed" ;;
        esac
    }

    local rc=0
    if [ -n "$out_file" ]; then _md5_run > "$out_file" || rc=$?; else _md5_run || rc=$?; fi
    unset -f _md5_run _h_file _h_str _case 2>/dev/null
    return "$rc"
}

# ==================================================================
# SHA1
# ==================================================================
#resource/cmd_sha1.bash
cmd_sha1() {
    if [ $# -eq 0 ]; then
        ccat <<'EOF'
//cecho -b "用法: SHA1 [参数] [数据...]"
  -f <文件>            计算文件的 SHA1 哈希
  -d <字符串>          计算字符串的 SHA1 哈希
  -C <目标> <文件...>  校验多个文件, 逐个输出是否符合目标
  -c <目标> <哈希...>  校验多个哈希, 逐个输出是否符合目标
  -u                   输出大写哈希
  -o <文件|目录>       写入文件; 为目录时自动命名 <cmd>_<时间>.txt
  --tag                BSD 风格输出
  --status             不输出任何内容(仅退出码)
  -q                   只输出哈希, 不显示文件名
  -h, --help           显示此帮助
EOF
        err "警告: SHA1 已不安全, 仅用于非安全场景"
        return 0
    fi

    local mode="" mode_opt=""
    local out_upper=0 out_file="" bsd_tag=0 status_only=0 quiet=0
    local -a positional=()

    while [ $# -gt 0 ]; do
        case "$1" in
            -f|-d|-c|-C)
                if [ -n "$mode" ]; then err "不能同时指定 $mode_opt 和 $1"; return 1; fi
                mode_opt="$1"
                case "$1" in
                    -f) mode="file" ;;
                    -d) mode="string" ;;
                    -c) mode="check_hashes" ;;
                    -C) mode="check_files" ;;
                esac
                shift ;;
            -u) out_upper=1; shift ;;
            --tag) bsd_tag=1; shift ;;
            --status) status_only=1; shift ;;
            -q) quiet=1; shift ;;
            -o)
                if [ -z "${2:-}" ]; then err "缺少输出文件参数"; return 1; fi
                out_file=$(_resolve_out_file "$2" "sha1"); shift 2 ;;
            -h|--help)
                ccat <<'EOF'
//cecho -b "用法: SHA1 [参数] [数据...]"
  -f <文件>            计算文件的 SHA1 哈希
  -d <字符串>          计算字符串的 SHA1 哈希
  -C <目标> <文件...>  校验多个文件, 逐个输出是否符合目标
  -c <目标> <哈希...>  校验多个哈希, 逐个输出是否符合目标
  -u                   输出大写哈希
  -o <文件|目录>       写入文件; 为目录时自动命名 <cmd>_<时间>.txt
  --tag                BSD 风格输出
  --status             不输出任何内容(仅退出码)
  -q                   只输出哈希, 不显示文件名
  -h, --help           显示此帮助
EOF
                err "警告: SHA1 已不安全, 仅用于非安全场景"
                return 0 ;;
            --) shift; while [ $# -gt 0 ]; do positional+=("$1"); shift; done ;;
            -*) err "未知参数: $1, 使用 SHA1 -h 查看帮助"; return 1 ;;
            *) positional+=("$1"); shift ;;
        esac
    done

    if [ -z "$mode" ]; then err "缺少模式参数 (-f/-d/-c/-C), 使用 SHA1 -h 查看帮助"; return 1; fi
    if [ "$status_only" = "1" ]; then
        case "$mode" in check_files|check_hashes) ;; *) err "--status 只能与 -c/-C 一起使用"; return 1 ;; esac
    fi

    local data="" expected=""
    local -a multi_args=()
    case "$mode" in
        file|string)
            if [ ${#positional[@]} -eq 0 ]; then err "缺少数据参数, 使用 SHA1 -h 查看帮助"; return 1; fi
            if [ ${#positional[@]} -gt 1 ]; then err "模式 $mode_opt 只接受一个参数, 多余: ${positional[*]:1}"; return 1; fi
            data="${positional[0]}" ;;
        check_files|check_hashes)
            if [ ${#positional[@]} -lt 1 ]; then err "缺少目标参数, 使用 SHA1 -h 查看帮助"; return 1; fi
            expected="${positional[0]}"
            multi_args=("${positional[@]:1}")
            if [ ${#multi_args[@]} -eq 0 ]; then err "缺少待校验参数"; return 1; fi ;;
    esac

    local cmd_sha=""
    if command -v sha1sum >/dev/null 2>&1; then
        cmd_sha="sha1sum"
    elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | $_GREP -q sha1sum; then
        cmd_sha="busybox sha1sum"
    elif command -v openssl >/dev/null 2>&1; then
        cmd_sha="openssl dgst -sha1"
    else
        err "未找到可用的 SHA1 计算工具 (sha1sum, busybox, openssl)"
        return 1
    fi

    _sha1_run() {
        _h_file() {
            if [[ "$cmd_sha" == openssl* ]]; then
                $cmd_sha "$1" 2>/dev/null | $_AWK '{print $NF}'
            else
                $cmd_sha "$1" 2>/dev/null | $_AWK '{print $1}'
            fi
        }
        _h_str() {
            if [[ "$cmd_sha" == openssl* ]]; then
                printf "%s" "$1" | $cmd_sha 2>/dev/null | $_AWK '{print $NF}'
            else
                printf "%s" "$1" | $cmd_sha 2>/dev/null | $_AWK '{print $1}'
            fi
        }
        _case() {
            if [ "$out_upper" = "1" ]; then printf '%s' "$1" | tr 'a-f' 'A-F'; else printf '%s' "$1"; fi
        }
        case "$mode" in
            file)
                [ ! -f "$data" ] && { err "文件不存在: $data"; return 1; }
                local h; h=$(_h_file "$data")
                [ -z "$h" ] && { err "计算 SHA1 失败"; return 1; }
                h=$(_case "$h")
                if [ "$quiet" = "1" ]; then printf '%s\n' "$h"
                elif [ "$bsd_tag" = "1" ]; then printf 'SHA1 (%s) = %s\n' "$data" "$h"
                else printf '%s  %s\n' "$h" "$data"; fi ;;
            string)
                local h; h=$(_h_str "$data")
                [ -z "$h" ] && { err "计算 SHA1 失败"; return 1; }
                h=$(_case "$h")
                if [ "$quiet" = "1" ]; then printf '%s\n' "$h"
                elif [ "$bsd_tag" = "1" ]; then printf 'SHA1 ("%s") = %s\n' "$data" "$h"
                else printf '%s\n' "$h"; fi ;;
            check_files)
                local exp_lower; exp_lower=$(printf '%s' "$expected" | tr 'A-Z' 'a-z')
                local failed=0 f h h_lower
                for f in "${multi_args[@]}"; do
                    if [ ! -f "$f" ]; then
                        [ "$status_only" = "1" ] || err "文件不存在: $f"
                        failed=1; continue
                    fi
                    h=$(_h_file "$f")
                    if [ -z "$h" ]; then
                        [ "$status_only" = "1" ] || err "计算 SHA1 失败: $f"
                        failed=1; continue
                    fi
                    h_lower=$(printf '%s' "$h" | tr 'A-Z' 'a-z')
                    if [ "$h_lower" = "$exp_lower" ]; then
                        if [ "$status_only" != "1" ]; then
                            if [ "$quiet" = "1" ]; then printf '%s\n' "$f"
                            elif [ "$bsd_tag" = "1" ]; then cecho -c 92 "SHA1 ($f) = OK"
                            else cecho -c 92 "$f: 符合"; fi
                        fi
                    else
                        if [ "$status_only" != "1" ] && [ "$quiet" != "1" ]; then
                            if [ "$bsd_tag" = "1" ]; then err "SHA1 ($f) = FAILED"
                            else err "$f: 不符合"; fi
                        fi
                        failed=1
                    fi
                done
                return "$failed" ;;
            check_hashes)
                local exp_lower; exp_lower=$(printf '%s' "$expected" | tr 'A-Z' 'a-z')
                local failed=0 h h_lower
                for h in "${multi_args[@]}"; do
                    h_lower=$(printf '%s' "$h" | tr 'A-Z' 'a-z')
                    if [ "$h_lower" = "$exp_lower" ]; then
                        if [ "$status_only" != "1" ]; then
                            if [ "$quiet" = "1" ]; then printf '%s\n' "$h"
                            elif [ "$bsd_tag" = "1" ]; then cecho -c 92 "SHA1 ($h) = OK"
                            else cecho -c 92 "$h: 符合"; fi
                        fi
                    else
                        if [ "$status_only" != "1" ] && [ "$quiet" != "1" ]; then
                            if [ "$bsd_tag" = "1" ]; then err "SHA1 ($h) = FAILED"
                            else err "$h: 不符合"; fi
                        fi
                        failed=1
                    fi
                done
                return "$failed" ;;
        esac
    }

    local rc=0
    if [ -n "$out_file" ]; then _sha1_run > "$out_file" || rc=$?; else _sha1_run || rc=$?; fi
    unset -f _sha1_run _h_file _h_str _case 2>/dev/null
    return "$rc"
}

# ==================================================================
# SHA224
# ==================================================================
#resource/cmd_sha224.bash
cmd_sha224() {
    if [ $# -eq 0 ]; then
        ccat <<'EOF'
//cecho -b "用法: SHA224 [参数] [数据...]"
  -f <文件>            计算文件的 SHA224 哈希
  -d <字符串>          计算字符串的 SHA224 哈希
  -C <目标> <文件...>  校验多个文件, 逐个输出是否符合目标
  -c <目标> <哈希...>  校验多个哈希, 逐个输出是否符合目标
  -u                   输出大写哈希
  -o <文件|目录>       写入文件; 为目录时自动命名 <cmd>_<时间>.txt
  --tag                BSD 风格输出
  --status             不输出任何内容(仅退出码)
  -q                   只输出哈希, 不显示文件名
  -h, --help           显示此帮助
EOF
        return 0
    fi

    local mode="" mode_opt=""
    local out_upper=0 out_file="" bsd_tag=0 status_only=0 quiet=0
    local -a positional=()

    while [ $# -gt 0 ]; do
        case "$1" in
            -f|-d|-c|-C)
                if [ -n "$mode" ]; then err "不能同时指定 $mode_opt 和 $1"; return 1; fi
                mode_opt="$1"
                case "$1" in
                    -f) mode="file" ;;
                    -d) mode="string" ;;
                    -c) mode="check_hashes" ;;
                    -C) mode="check_files" ;;
                esac
                shift ;;
            -u) out_upper=1; shift ;;
            --tag) bsd_tag=1; shift ;;
            --status) status_only=1; shift ;;
            -q) quiet=1; shift ;;
            -o)
                if [ -z "${2:-}" ]; then err "缺少输出文件参数"; return 1; fi
                out_file=$(_resolve_out_file "$2" "sha224"); shift 2 ;;
            -h|--help)
                ccat <<'EOF'
//cecho -b "用法: SHA224 [参数] [数据...]"
  -f <文件>            计算文件的 SHA224 哈希
  -d <字符串>          计算字符串的 SHA224 哈希
  -C <目标> <文件...>  校验多个文件, 逐个输出是否符合目标
  -c <目标> <哈希...>  校验多个哈希, 逐个输出是否符合目标
  -u                   输出大写哈希
  -o <文件|目录>       写入文件; 为目录时自动命名 <cmd>_<时间>.txt
  --tag                BSD 风格输出
  --status             不输出任何内容(仅退出码)
  -q                   只输出哈希, 不显示文件名
  -h, --help           显示此帮助
EOF
                return 0 ;;
            --) shift; while [ $# -gt 0 ]; do positional+=("$1"); shift; done ;;
            -*) err "未知参数: $1, 使用 SHA224 -h 查看帮助"; return 1 ;;
            *) positional+=("$1"); shift ;;
        esac
    done

    if [ -z "$mode" ]; then err "缺少模式参数 (-f/-d/-c/-C), 使用 SHA224 -h 查看帮助"; return 1; fi
    if [ "$status_only" = "1" ]; then
        case "$mode" in check_files|check_hashes) ;; *) err "--status 只能与 -c/-C 一起使用"; return 1 ;; esac
    fi

    local data="" expected=""
    local -a multi_args=()
    case "$mode" in
        file|string)
            if [ ${#positional[@]} -eq 0 ]; then err "缺少数据参数, 使用 SHA224 -h 查看帮助"; return 1; fi
            if [ ${#positional[@]} -gt 1 ]; then err "模式 $mode_opt 只接受一个参数, 多余: ${positional[*]:1}"; return 1; fi
            data="${positional[0]}" ;;
        check_files|check_hashes)
            if [ ${#positional[@]} -lt 1 ]; then err "缺少目标参数, 使用 SHA224 -h 查看帮助"; return 1; fi
            expected="${positional[0]}"
            multi_args=("${positional[@]:1}")
            if [ ${#multi_args[@]} -eq 0 ]; then err "缺少待校验参数"; return 1; fi ;;
    esac

    local cmd_sha=""
    if command -v sha224sum >/dev/null 2>&1; then
        cmd_sha="sha224sum"
    elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | $_GREP -q sha224sum; then
        cmd_sha="busybox sha224sum"
    elif command -v openssl >/dev/null 2>&1; then
        cmd_sha="openssl dgst -sha224"
    else
        err "未找到可用的 SHA224 计算工具 (sha224sum, busybox, openssl)"
        return 1
    fi

    _sha224_run() {
        _h_file() {
            if [[ "$cmd_sha" == openssl* ]]; then
                $cmd_sha "$1" 2>/dev/null | $_AWK '{print $NF}'
            else
                $cmd_sha "$1" 2>/dev/null | $_AWK '{print $1}'
            fi
        }
        _h_str() {
            if [[ "$cmd_sha" == openssl* ]]; then
                printf "%s" "$1" | $cmd_sha 2>/dev/null | $_AWK '{print $NF}'
            else
                printf "%s" "$1" | $cmd_sha 2>/dev/null | $_AWK '{print $1}'
            fi
        }
        _case() {
            if [ "$out_upper" = "1" ]; then printf '%s' "$1" | tr 'a-f' 'A-F'; else printf '%s' "$1"; fi
        }
        case "$mode" in
            file)
                [ ! -f "$data" ] && { err "文件不存在: $data"; return 1; }
                local h; h=$(_h_file "$data")
                [ -z "$h" ] && { err "计算 SHA224 失败"; return 1; }
                h=$(_case "$h")
                if [ "$quiet" = "1" ]; then printf '%s\n' "$h"
                elif [ "$bsd_tag" = "1" ]; then printf 'SHA224 (%s) = %s\n' "$data" "$h"
                else printf '%s  %s\n' "$h" "$data"; fi ;;
            string)
                local h; h=$(_h_str "$data")
                [ -z "$h" ] && { err "计算 SHA224 失败"; return 1; }
                h=$(_case "$h")
                if [ "$quiet" = "1" ]; then printf '%s\n' "$h"
                elif [ "$bsd_tag" = "1" ]; then printf 'SHA224 ("%s") = %s\n' "$data" "$h"
                else printf '%s\n' "$h"; fi ;;
            check_files)
                local exp_lower; exp_lower=$(printf '%s' "$expected" | tr 'A-Z' 'a-z')
                local failed=0 f h h_lower
                for f in "${multi_args[@]}"; do
                    if [ ! -f "$f" ]; then
                        [ "$status_only" = "1" ] || err "文件不存在: $f"
                        failed=1; continue
                    fi
                    h=$(_h_file "$f")
                    if [ -z "$h" ]; then
                        [ "$status_only" = "1" ] || err "计算 SHA224 失败: $f"
                        failed=1; continue
                    fi
                    h_lower=$(printf '%s' "$h" | tr 'A-Z' 'a-z')
                    if [ "$h_lower" = "$exp_lower" ]; then
                        if [ "$status_only" != "1" ]; then
                            if [ "$quiet" = "1" ]; then printf '%s\n' "$f"
                            elif [ "$bsd_tag" = "1" ]; then cecho -c 92 "SHA224 ($f) = OK"
                            else cecho -c 92 "$f: 符合"; fi
                        fi
                    else
                        if [ "$status_only" != "1" ] && [ "$quiet" != "1" ]; then
                            if [ "$bsd_tag" = "1" ]; then err "SHA224 ($f) = FAILED"
                            else err "$f: 不符合"; fi
                        fi
                        failed=1
                    fi
                done
                return "$failed" ;;
            check_hashes)
                local exp_lower; exp_lower=$(printf '%s' "$expected" | tr 'A-Z' 'a-z')
                local failed=0 h h_lower
                for h in "${multi_args[@]}"; do
                    h_lower=$(printf '%s' "$h" | tr 'A-Z' 'a-z')
                    if [ "$h_lower" = "$exp_lower" ]; then
                        if [ "$status_only" != "1" ]; then
                            if [ "$quiet" = "1" ]; then printf '%s\n' "$h"
                            elif [ "$bsd_tag" = "1" ]; then cecho -c 92 "SHA224 ($h) = OK"
                            else cecho -c 92 "$h: 符合"; fi
                        fi
                    else
                        if [ "$status_only" != "1" ] && [ "$quiet" != "1" ]; then
                            if [ "$bsd_tag" = "1" ]; then err "SHA224 ($h) = FAILED"
                            else err "$h: 不符合"; fi
                        fi
                        failed=1
                    fi
                done
                return "$failed" ;;
        esac
    }

    local rc=0
    if [ -n "$out_file" ]; then _sha224_run > "$out_file" || rc=$?; else _sha224_run || rc=$?; fi
    unset -f _sha224_run _h_file _h_str _case 2>/dev/null
    return "$rc"
}

# ==================================================================
# SHA256
# ==================================================================
#resource/cmd_sha256.bash
cmd_sha256() {
    if [ $# -eq 0 ]; then
        ccat <<'EOF'
//cecho -b "用法: SHA256 [参数] [数据...]"
  -f <文件>            计算文件的 SHA256 哈希
  -d <字符串>          计算字符串的 SHA256 哈希
  -C <目标> <文件...>  校验多个文件, 逐个输出是否符合目标
  -c <目标> <哈希...>  校验多个哈希, 逐个输出是否符合目标
  -u                   输出大写哈希
  -o <文件|目录>       写入文件; 为目录时自动命名 <cmd>_<时间>.txt
  --tag                BSD 风格输出
  --status             不输出任何内容(仅退出码)
  -q                   只输出哈希, 不显示文件名
  -h, --help           显示此帮助
EOF
        return 0
    fi

    local mode="" mode_opt=""
    local out_upper=0 out_file="" bsd_tag=0 status_only=0 quiet=0
    local -a positional=()

    while [ $# -gt 0 ]; do
        case "$1" in
            -f|-d|-c|-C)
                if [ -n "$mode" ]; then err "不能同时指定 $mode_opt 和 $1"; return 1; fi
                mode_opt="$1"
                case "$1" in
                    -f) mode="file" ;;
                    -d) mode="string" ;;
                    -c) mode="check_hashes" ;;
                    -C) mode="check_files" ;;
                esac
                shift ;;
            -u) out_upper=1; shift ;;
            --tag) bsd_tag=1; shift ;;
            --status) status_only=1; shift ;;
            -q) quiet=1; shift ;;
            -o)
                if [ -z "${2:-}" ]; then err "缺少输出文件参数"; return 1; fi
                out_file=$(_resolve_out_file "$2" "sha256"); shift 2 ;;
            -h|--help)
                ccat <<'EOF'
//cecho -b "用法: SHA256 [参数] [数据...]"
  -f <文件>            计算文件的 SHA256 哈希
  -d <字符串>          计算字符串的 SHA256 哈希
  -C <目标> <文件...>  校验多个文件, 逐个输出是否符合目标
  -c <目标> <哈希...>  校验多个哈希, 逐个输出是否符合目标
  -u                   输出大写哈希
  -o <文件|目录>       写入文件; 为目录时自动命名 <cmd>_<时间>.txt
  --tag                BSD 风格输出
  --status             不输出任何内容(仅退出码)
  -q                   只输出哈希, 不显示文件名
  -h, --help           显示此帮助
EOF
                return 0 ;;
            --) shift; while [ $# -gt 0 ]; do positional+=("$1"); shift; done ;;
            -*) err "未知参数: $1, 使用 SHA256 -h 查看帮助"; return 1 ;;
            *) positional+=("$1"); shift ;;
        esac
    done

    if [ -z "$mode" ]; then err "缺少模式参数 (-f/-d/-c/-C), 使用 SHA256 -h 查看帮助"; return 1; fi
    if [ "$status_only" = "1" ]; then
        case "$mode" in check_files|check_hashes) ;; *) err "--status 只能与 -c/-C 一起使用"; return 1 ;; esac
    fi

    local data="" expected=""
    local -a multi_args=()
    case "$mode" in
        file|string)
            if [ ${#positional[@]} -eq 0 ]; then err "缺少数据参数, 使用 SHA256 -h 查看帮助"; return 1; fi
            if [ ${#positional[@]} -gt 1 ]; then err "模式 $mode_opt 只接受一个参数, 多余: ${positional[*]:1}"; return 1; fi
            data="${positional[0]}" ;;
        check_files|check_hashes)
            if [ ${#positional[@]} -lt 1 ]; then err "缺少目标参数, 使用 SHA256 -h 查看帮助"; return 1; fi
            expected="${positional[0]}"
            multi_args=("${positional[@]:1}")
            if [ ${#multi_args[@]} -eq 0 ]; then err "缺少待校验参数"; return 1; fi ;;
    esac

    local cmd_sha=""
    if command -v sha256sum >/dev/null 2>&1; then
        cmd_sha="sha256sum"
    elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | $_GREP -q sha256sum; then
        cmd_sha="busybox sha256sum"
    elif command -v openssl >/dev/null 2>&1; then
        cmd_sha="openssl dgst -sha256"
    else
        err "未找到可用的 SHA256 计算工具 (sha256sum, busybox, openssl)"
        return 1
    fi

    _sha256_run() {
        _h_file() {
            if [[ "$cmd_sha" == openssl* ]]; then
                $cmd_sha "$1" 2>/dev/null | $_AWK '{print $NF}'
            else
                $cmd_sha "$1" 2>/dev/null | $_AWK '{print $1}'
            fi
        }
        _h_str() {
            if [[ "$cmd_sha" == openssl* ]]; then
                printf "%s" "$1" | $cmd_sha 2>/dev/null | $_AWK '{print $NF}'
            else
                printf "%s" "$1" | $cmd_sha 2>/dev/null | $_AWK '{print $1}'
            fi
        }
        _case() {
            if [ "$out_upper" = "1" ]; then printf '%s' "$1" | tr 'a-f' 'A-F'; else printf '%s' "$1"; fi
        }
        case "$mode" in
            file)
                [ ! -f "$data" ] && { err "文件不存在: $data"; return 1; }
                local h; h=$(_h_file "$data")
                [ -z "$h" ] && { err "计算 SHA256 失败"; return 1; }
                h=$(_case "$h")
                if [ "$quiet" = "1" ]; then printf '%s\n' "$h"
                elif [ "$bsd_tag" = "1" ]; then printf 'SHA256 (%s) = %s\n' "$data" "$h"
                else printf '%s  %s\n' "$h" "$data"; fi ;;
            string)
                local h; h=$(_h_str "$data")
                [ -z "$h" ] && { err "计算 SHA256 失败"; return 1; }
                h=$(_case "$h")
                if [ "$quiet" = "1" ]; then printf '%s\n' "$h"
                elif [ "$bsd_tag" = "1" ]; then printf 'SHA256 ("%s") = %s\n' "$data" "$h"
                else printf '%s\n' "$h"; fi ;;
            check_files)
                local exp_lower; exp_lower=$(printf '%s' "$expected" | tr 'A-Z' 'a-z')
                local failed=0 f h h_lower
                for f in "${multi_args[@]}"; do
                    if [ ! -f "$f" ]; then
                        [ "$status_only" = "1" ] || err "文件不存在: $f"
                        failed=1; continue
                    fi
                    h=$(_h_file "$f")
                    if [ -z "$h" ]; then
                        [ "$status_only" = "1" ] || err "计算 SHA256 失败: $f"
                        failed=1; continue
                    fi
                    h_lower=$(printf '%s' "$h" | tr 'A-Z' 'a-z')
                    if [ "$h_lower" = "$exp_lower" ]; then
                        if [ "$status_only" != "1" ]; then
                            if [ "$quiet" = "1" ]; then printf '%s\n' "$f"
                            elif [ "$bsd_tag" = "1" ]; then cecho -c 92 "SHA256 ($f) = OK"
                            else cecho -c 92 "$f: 符合"; fi
                        fi
                    else
                        if [ "$status_only" != "1" ] && [ "$quiet" != "1" ]; then
                            if [ "$bsd_tag" = "1" ]; then err "SHA256 ($f) = FAILED"
                            else err "$f: 不符合"; fi
                        fi
                        failed=1
                    fi
                done
                return "$failed" ;;
            check_hashes)
                local exp_lower; exp_lower=$(printf '%s' "$expected" | tr 'A-Z' 'a-z')
                local failed=0 h h_lower
                for h in "${multi_args[@]}"; do
                    h_lower=$(printf '%s' "$h" | tr 'A-Z' 'a-z')
                    if [ "$h_lower" = "$exp_lower" ]; then
                        if [ "$status_only" != "1" ]; then
                            if [ "$quiet" = "1" ]; then printf '%s\n' "$h"
                            elif [ "$bsd_tag" = "1" ]; then cecho -c 92 "SHA256 ($h) = OK"
                            else cecho -c 92 "$h: 符合"; fi
                        fi
                    else
                        if [ "$status_only" != "1" ] && [ "$quiet" != "1" ]; then
                            if [ "$bsd_tag" = "1" ]; then err "SHA256 ($h) = FAILED"
                            else err "$h: 不符合"; fi
                        fi
                        failed=1
                    fi
                done
                return "$failed" ;;
        esac
    }

    local rc=0
    if [ -n "$out_file" ]; then _sha256_run > "$out_file" || rc=$?; else _sha256_run || rc=$?; fi
    unset -f _sha256_run _h_file _h_str _case 2>/dev/null
    return "$rc"
}

# ==================================================================
# SHA384
# ==================================================================
#resource/cmd_sha384.bash
cmd_sha384() {
    if [ $# -eq 0 ]; then
        ccat <<'EOF'
//cecho -b "用法: SHA384 [参数] [数据...]"
  -f <文件>            计算文件的 SHA384 哈希
  -d <字符串>          计算字符串的 SHA384 哈希
  -C <目标> <文件...>  校验多个文件, 逐个输出是否符合目标
  -c <目标> <哈希...>  校验多个哈希, 逐个输出是否符合目标
  -u                   输出大写哈希
  -o <文件|目录>       写入文件; 为目录时自动命名 <cmd>_<时间>.txt
  --tag                BSD 风格输出
  --status             不输出任何内容(仅退出码)
  -q                   只输出哈希, 不显示文件名
  -h, --help           显示此帮助
EOF
        return 0
    fi

    local mode="" mode_opt=""
    local out_upper=0 out_file="" bsd_tag=0 status_only=0 quiet=0
    local -a positional=()

    while [ $# -gt 0 ]; do
        case "$1" in
            -f|-d|-c|-C)
                if [ -n "$mode" ]; then err "不能同时指定 $mode_opt 和 $1"; return 1; fi
                mode_opt="$1"
                case "$1" in
                    -f) mode="file" ;;
                    -d) mode="string" ;;
                    -c) mode="check_hashes" ;;
                    -C) mode="check_files" ;;
                esac
                shift ;;
            -u) out_upper=1; shift ;;
            --tag) bsd_tag=1; shift ;;
            --status) status_only=1; shift ;;
            -q) quiet=1; shift ;;
            -o)
                if [ -z "${2:-}" ]; then err "缺少输出文件参数"; return 1; fi
                out_file=$(_resolve_out_file "$2" "sha384"); shift 2 ;;
            -h|--help)
                ccat <<'EOF'
//cecho -b "用法: SHA384 [参数] [数据...]"
  -f <文件>            计算文件的 SHA384 哈希
  -d <字符串>          计算字符串的 SHA384 哈希
  -C <目标> <文件...>  校验多个文件, 逐个输出是否符合目标
  -c <目标> <哈希...>  校验多个哈希, 逐个输出是否符合目标
  -u                   输出大写哈希
  -o <文件|目录>       写入文件; 为目录时自动命名 <cmd>_<时间>.txt
  --tag                BSD 风格输出
  --status             不输出任何内容(仅退出码)
  -q                   只输出哈希, 不显示文件名
  -h, --help           显示此帮助
EOF
                return 0 ;;
            --) shift; while [ $# -gt 0 ]; do positional+=("$1"); shift; done ;;
            -*) err "未知参数: $1, 使用 SHA384 -h 查看帮助"; return 1 ;;
            *) positional+=("$1"); shift ;;
        esac
    done

    if [ -z "$mode" ]; then err "缺少模式参数 (-f/-d/-c/-C), 使用 SHA384 -h 查看帮助"; return 1; fi
    if [ "$status_only" = "1" ]; then
        case "$mode" in check_files|check_hashes) ;; *) err "--status 只能与 -c/-C 一起使用"; return 1 ;; esac
    fi

    local data="" expected=""
    local -a multi_args=()
    case "$mode" in
        file|string)
            if [ ${#positional[@]} -eq 0 ]; then err "缺少数据参数, 使用 SHA384 -h 查看帮助"; return 1; fi
            if [ ${#positional[@]} -gt 1 ]; then err "模式 $mode_opt 只接受一个参数, 多余: ${positional[*]:1}"; return 1; fi
            data="${positional[0]}" ;;
        check_files|check_hashes)
            if [ ${#positional[@]} -lt 1 ]; then err "缺少目标参数, 使用 SHA384 -h 查看帮助"; return 1; fi
            expected="${positional[0]}"
            multi_args=("${positional[@]:1}")
            if [ ${#multi_args[@]} -eq 0 ]; then err "缺少待校验参数"; return 1; fi ;;
    esac

    local cmd_sha=""
    if command -v sha384sum >/dev/null 2>&1; then
        cmd_sha="sha384sum"
    elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | $_GREP -q sha384sum; then
        cmd_sha="busybox sha384sum"
    elif command -v openssl >/dev/null 2>&1; then
        cmd_sha="openssl dgst -sha384"
    else
        err "未找到可用的 SHA384 计算工具 (sha384sum, busybox, openssl)"
        return 1
    fi

    _sha384_run() {
        _h_file() {
            if [[ "$cmd_sha" == openssl* ]]; then
                $cmd_sha "$1" 2>/dev/null | $_AWK '{print $NF}'
            else
                $cmd_sha "$1" 2>/dev/null | $_AWK '{print $1}'
            fi
        }
        _h_str() {
            if [[ "$cmd_sha" == openssl* ]]; then
                printf "%s" "$1" | $cmd_sha 2>/dev/null | $_AWK '{print $NF}'
            else
                printf "%s" "$1" | $cmd_sha 2>/dev/null | $_AWK '{print $1}'
            fi
        }
        _case() {
            if [ "$out_upper" = "1" ]; then printf '%s' "$1" | tr 'a-f' 'A-F'; else printf '%s' "$1"; fi
        }
        case "$mode" in
            file)
                [ ! -f "$data" ] && { err "文件不存在: $data"; return 1; }
                local h; h=$(_h_file "$data")
                [ -z "$h" ] && { err "计算 SHA384 失败"; return 1; }
                h=$(_case "$h")
                if [ "$quiet" = "1" ]; then printf '%s\n' "$h"
                elif [ "$bsd_tag" = "1" ]; then printf 'SHA384 (%s) = %s\n' "$data" "$h"
                else printf '%s  %s\n' "$h" "$data"; fi ;;
            string)
                local h; h=$(_h_str "$data")
                [ -z "$h" ] && { err "计算 SHA384 失败"; return 1; }
                h=$(_case "$h")
                if [ "$quiet" = "1" ]; then printf '%s\n' "$h"
                elif [ "$bsd_tag" = "1" ]; then printf 'SHA384 ("%s") = %s\n' "$data" "$h"
                else printf '%s\n' "$h"; fi ;;
            check_files)
                local exp_lower; exp_lower=$(printf '%s' "$expected" | tr 'A-Z' 'a-z')
                local failed=0 f h h_lower
                for f in "${multi_args[@]}"; do
                    if [ ! -f "$f" ]; then
                        [ "$status_only" = "1" ] || err "文件不存在: $f"
                        failed=1; continue
                    fi
                    h=$(_h_file "$f")
                    if [ -z "$h" ]; then
                        [ "$status_only" = "1" ] || err "计算 SHA384 失败: $f"
                        failed=1; continue
                    fi
                    h_lower=$(printf '%s' "$h" | tr 'A-Z' 'a-z')
                    if [ "$h_lower" = "$exp_lower" ]; then
                        if [ "$status_only" != "1" ]; then
                            if [ "$quiet" = "1" ]; then printf '%s\n' "$f"
                            elif [ "$bsd_tag" = "1" ]; then cecho -c 92 "SHA384 ($f) = OK"
                            else cecho -c 92 "$f: 符合"; fi
                        fi
                    else
                        if [ "$status_only" != "1" ] && [ "$quiet" != "1" ]; then
                            if [ "$bsd_tag" = "1" ]; then err "SHA384 ($f) = FAILED"
                            else err "$f: 不符合"; fi
                        fi
                        failed=1
                    fi
                done
                return "$failed" ;;
            check_hashes)
                local exp_lower; exp_lower=$(printf '%s' "$expected" | tr 'A-Z' 'a-z')
                local failed=0 h h_lower
                for h in "${multi_args[@]}"; do
                    h_lower=$(printf '%s' "$h" | tr 'A-Z' 'a-z')
                    if [ "$h_lower" = "$exp_lower" ]; then
                        if [ "$status_only" != "1" ]; then
                            if [ "$quiet" = "1" ]; then printf '%s\n' "$h"
                            elif [ "$bsd_tag" = "1" ]; then cecho -c 92 "SHA384 ($h) = OK"
                            else cecho -c 92 "$h: 符合"; fi
                        fi
                    else
                        if [ "$status_only" != "1" ] && [ "$quiet" != "1" ]; then
                            if [ "$bsd_tag" = "1" ]; then err "SHA384 ($h) = FAILED"
                            else err "$h: 不符合"; fi
                        fi
                        failed=1
                    fi
                done
                return "$failed" ;;
        esac
    }

    local rc=0
    if [ -n "$out_file" ]; then _sha384_run > "$out_file" || rc=$?; else _sha384_run || rc=$?; fi
    unset -f _sha384_run _h_file _h_str _case 2>/dev/null
    return "$rc"
}

# ==================================================================
# SHA512
# ==================================================================
#resource/cmd_sha512.bash
cmd_sha512() {
    if [ $# -eq 0 ]; then
        ccat <<'EOF'
//cecho -b "用法: SHA512 [参数] [数据...]"
  -f <文件>            计算文件的 SHA512 哈希
  -d <字符串>          计算字符串的 SHA512 哈希
  -C <目标> <文件...>  校验多个文件, 逐个输出是否符合目标
  -c <目标> <哈希...>  校验多个哈希, 逐个输出是否符合目标
  -u                   输出大写哈希
  -o <文件|目录>       写入文件; 为目录时自动命名 <cmd>_<时间>.txt
  --tag                BSD 风格输出
  --status             不输出任何内容(仅退出码)
  -q                   只输出哈希, 不显示文件名
  -h, --help           显示此帮助
EOF
        return 0
    fi

    local mode="" mode_opt=""
    local out_upper=0 out_file="" bsd_tag=0 status_only=0 quiet=0
    local -a positional=()

    while [ $# -gt 0 ]; do
        case "$1" in
            -f|-d|-c|-C)
                if [ -n "$mode" ]; then err "不能同时指定 $mode_opt 和 $1"; return 1; fi
                mode_opt="$1"
                case "$1" in
                    -f) mode="file" ;;
                    -d) mode="string" ;;
                    -c) mode="check_hashes" ;;
                    -C) mode="check_files" ;;
                esac
                shift ;;
            -u) out_upper=1; shift ;;
            --tag) bsd_tag=1; shift ;;
            --status) status_only=1; shift ;;
            -q) quiet=1; shift ;;
            -o)
                if [ -z "${2:-}" ]; then err "缺少输出文件参数"; return 1; fi
                out_file=$(_resolve_out_file "$2" "sha512"); shift 2 ;;
            -h|--help)
                ccat <<'EOF'
//cecho -b "用法: SHA512 [参数] [数据...]"
  -f <文件>            计算文件的 SHA512 哈希
  -d <字符串>          计算字符串的 SHA512 哈希
  -C <目标> <文件...>  校验多个文件, 逐个输出是否符合目标
  -c <目标> <哈希...>  校验多个哈希, 逐个输出是否符合目标
  -u                   输出大写哈希
  -o <文件|目录>       写入文件; 为目录时自动命名 <cmd>_<时间>.txt
  --tag                BSD 风格输出
  --status             不输出任何内容(仅退出码)
  -q                   只输出哈希, 不显示文件名
  -h, --help           显示此帮助
EOF
                return 0 ;;
            --) shift; while [ $# -gt 0 ]; do positional+=("$1"); shift; done ;;
            -*) err "未知参数: $1, 使用 SHA512 -h 查看帮助"; return 1 ;;
            *) positional+=("$1"); shift ;;
        esac
    done

    if [ -z "$mode" ]; then err "缺少模式参数 (-f/-d/-c/-C), 使用 SHA512 -h 查看帮助"; return 1; fi
    if [ "$status_only" = "1" ]; then
        case "$mode" in check_files|check_hashes) ;; *) err "--status 只能与 -c/-C 一起使用"; return 1 ;; esac
    fi

    local data="" expected=""
    local -a multi_args=()
    case "$mode" in
        file|string)
            if [ ${#positional[@]} -eq 0 ]; then err "缺少数据参数, 使用 SHA512 -h 查看帮助"; return 1; fi
            if [ ${#positional[@]} -gt 1 ]; then err "模式 $mode_opt 只接受一个参数, 多余: ${positional[*]:1}"; return 1; fi
            data="${positional[0]}" ;;
        check_files|check_hashes)
            if [ ${#positional[@]} -lt 1 ]; then err "缺少目标参数, 使用 SHA512 -h 查看帮助"; return 1; fi
            expected="${positional[0]}"
            multi_args=("${positional[@]:1}")
            if [ ${#multi_args[@]} -eq 0 ]; then err "缺少待校验参数"; return 1; fi ;;
    esac

    local cmd_sha=""
    if command -v sha512sum >/dev/null 2>&1; then
        cmd_sha="sha512sum"
    elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | $_GREP -q sha512sum; then
        cmd_sha="busybox sha512sum"
    elif command -v openssl >/dev/null 2>&1; then
        cmd_sha="openssl dgst -sha512"
    else
        err "未找到可用的 SHA512 计算工具 (sha512sum, busybox, openssl)"
        return 1
    fi

    _sha512_run() {
        _h_file() {
            if [[ "$cmd_sha" == openssl* ]]; then
                $cmd_sha "$1" 2>/dev/null | $_AWK '{print $NF}'
            else
                $cmd_sha "$1" 2>/dev/null | $_AWK '{print $1}'
            fi
        }
        _h_str() {
            if [[ "$cmd_sha" == openssl* ]]; then
                printf "%s" "$1" | $cmd_sha 2>/dev/null | $_AWK '{print $NF}'
            else
                printf "%s" "$1" | $cmd_sha 2>/dev/null | $_AWK '{print $1}'
            fi
        }
        _case() {
            if [ "$out_upper" = "1" ]; then printf '%s' "$1" | tr 'a-f' 'A-F'; else printf '%s' "$1"; fi
        }
        case "$mode" in
            file)
                [ ! -f "$data" ] && { err "文件不存在: $data"; return 1; }
                local h; h=$(_h_file "$data")
                [ -z "$h" ] && { err "计算 SHA512 失败"; return 1; }
                h=$(_case "$h")
                if [ "$quiet" = "1" ]; then printf '%s\n' "$h"
                elif [ "$bsd_tag" = "1" ]; then printf 'SHA512 (%s) = %s\n' "$data" "$h"
                else printf '%s  %s\n' "$h" "$data"; fi ;;
            string)
                local h; h=$(_h_str "$data")
                [ -z "$h" ] && { err "计算 SHA512 失败"; return 1; }
                h=$(_case "$h")
                if [ "$quiet" = "1" ]; then printf '%s\n' "$h"
                elif [ "$bsd_tag" = "1" ]; then printf 'SHA512 ("%s") = %s\n' "$data" "$h"
                else printf '%s\n' "$h"; fi ;;
            check_files)
                local exp_lower; exp_lower=$(printf '%s' "$expected" | tr 'A-Z' 'a-z')
                local failed=0 f h h_lower
                for f in "${multi_args[@]}"; do
                    if [ ! -f "$f" ]; then
                        [ "$status_only" = "1" ] || err "文件不存在: $f"
                        failed=1; continue
                    fi
                    h=$(_h_file "$f")
                    if [ -z "$h" ]; then
                        [ "$status_only" = "1" ] || err "计算 SHA512 失败: $f"
                        failed=1; continue
                    fi
                    h_lower=$(printf '%s' "$h" | tr 'A-Z' 'a-z')
                    if [ "$h_lower" = "$exp_lower" ]; then
                        if [ "$status_only" != "1" ]; then
                            if [ "$quiet" = "1" ]; then printf '%s\n' "$f"
                            elif [ "$bsd_tag" = "1" ]; then cecho -c 92 "SHA512 ($f) = OK"
                            else cecho -c 92 "$f: 符合"; fi
                        fi
                    else
                        if [ "$status_only" != "1" ] && [ "$quiet" != "1" ]; then
                            if [ "$bsd_tag" = "1" ]; then err "SHA512 ($f) = FAILED"
                            else err "$f: 不符合"; fi
                        fi
                        failed=1
                    fi
                done
                return "$failed" ;;
            check_hashes)
                local exp_lower; exp_lower=$(printf '%s' "$expected" | tr 'A-Z' 'a-z')
                local failed=0 h h_lower
                for h in "${multi_args[@]}"; do
                    h_lower=$(printf '%s' "$h" | tr 'A-Z' 'a-z')
                    if [ "$h_lower" = "$exp_lower" ]; then
                        if [ "$status_only" != "1" ]; then
                            if [ "$quiet" = "1" ]; then printf '%s\n' "$h"
                            elif [ "$bsd_tag" = "1" ]; then cecho -c 92 "SHA512 ($h) = OK"
                            else cecho -c 92 "$h: 符合"; fi
                        fi
                    else
                        if [ "$status_only" != "1" ] && [ "$quiet" != "1" ]; then
                            if [ "$bsd_tag" = "1" ]; then err "SHA512 ($h) = FAILED"
                            else err "$h: 不符合"; fi
                        fi
                        failed=1
                    fi
                done
                return "$failed" ;;
        esac
    }

    local rc=0
    if [ -n "$out_file" ]; then _sha512_run > "$out_file" || rc=$?; else _sha512_run || rc=$?; fi
    unset -f _sha512_run _h_file _h_str _case 2>/dev/null
    return "$rc"
}

# ==================================================================
# B2SUM (BLAKE2b-512)
# ==================================================================
#resource/cmd_b2sum.bash
cmd_b2sum() {
    if [ $# -eq 0 ]; then
        ccat <<'EOF'
//cecho -b "用法: B2SUM/BLAKE2 [参数] [数据...]"
  -f <文件>            计算文件的 BLAKE2 哈希
  -d <字符串>          计算字符串的 BLAKE2 哈希
  -C <目标> <文件...>  校验多个文件, 逐个输出是否符合目标
  -c <目标> <哈希...>  校验多个哈希, 逐个输出是否符合目标
  -u                   输出大写哈希
  -o <文件|目录>       写入文件; 为目录时自动命名 <cmd>_<时间>.txt
  --tag                BSD 风格输出
  --status             不输出任何内容(仅退出码)
  -q                   只输出哈希, 不显示文件名
  -h, --help           显示此帮助
EOF
        return 0
    fi

    local mode="" mode_opt=""
    local out_upper=0 out_file="" bsd_tag=0 status_only=0 quiet=0
    local -a positional=()

    while [ $# -gt 0 ]; do
        case "$1" in
            -f|-d|-c|-C)
                if [ -n "$mode" ]; then err "不能同时指定 $mode_opt 和 $1"; return 1; fi
                mode_opt="$1"
                case "$1" in
                    -f) mode="file" ;;
                    -d) mode="string" ;;
                    -c) mode="check_hashes" ;;
                    -C) mode="check_files" ;;
                esac
                shift ;;
            -u) out_upper=1; shift ;;
            --tag) bsd_tag=1; shift ;;
            --status) status_only=1; shift ;;
            -q) quiet=1; shift ;;
            -o)
                if [ -z "${2:-}" ]; then err "缺少输出文件参数"; return 1; fi
                out_file=$(_resolve_out_file "$2" "b2sum"); shift 2 ;;
            -h|--help)
                ccat <<'EOF'
//cecho -b "用法: B2SUM/BLAKE2 [参数] [数据...]"
  -f <文件>            计算文件的 BLAKE2 哈希
  -d <字符串>          计算字符串的 BLAKE2 哈希
  -C <目标> <文件...>  校验多个文件, 逐个输出是否符合目标
  -c <目标> <哈希...>  校验多个哈希, 逐个输出是否符合目标
  -u                   输出大写哈希
  -o <文件|目录>       写入文件; 为目录时自动命名 <cmd>_<时间>.txt
  --tag                BSD 风格输出
  --status             不输出任何内容(仅退出码)
  -q                   只输出哈希, 不显示文件名
  -h, --help           显示此帮助
EOF
                return 0 ;;
            --) shift; while [ $# -gt 0 ]; do positional+=("$1"); shift; done ;;
            -*) err "未知参数: $1, 使用 B2SUM/BLAKE2 -h 查看帮助"; return 1 ;;
            *) positional+=("$1"); shift ;;
        esac
    done

    if [ -z "$mode" ]; then err "缺少模式参数 (-f/-d/-c/-C), 使用 B2SUM/BLAKE2 -h 查看帮助"; return 1; fi
    if [ "$status_only" = "1" ]; then
        case "$mode" in check_files|check_hashes) ;; *) err "--status 只能与 -c/-C 一起使用"; return 1 ;; esac
    fi

    local data="" expected=""
    local -a multi_args=()
    case "$mode" in
        file|string)
            if [ ${#positional[@]} -eq 0 ]; then err "缺少数据参数, 使用 B2SUM/BLAKE2 -h 查看帮助"; return 1; fi
            if [ ${#positional[@]} -gt 1 ]; then err "模式 $mode_opt 只接受一个参数, 多余: ${positional[*]:1}"; return 1; fi
            data="${positional[0]}" ;;
        check_files|check_hashes)
            if [ ${#positional[@]} -lt 1 ]; then err "缺少目标参数, 使用 B2SUM/BLAKE2 -h 查看帮助"; return 1; fi
            expected="${positional[0]}"
            multi_args=("${positional[@]:1}")
            if [ ${#multi_args[@]} -eq 0 ]; then err "缺少待校验参数"; return 1; fi ;;
    esac

    local cmd_sha=""
    if command -v b2sum >/dev/null 2>&1; then
        cmd_sha="b2sum"
    elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | $_GREP -q b2sum; then
        cmd_sha="busybox b2sum"
    elif command -v openssl >/dev/null 2>&1; then
        cmd_sha="openssl dgst -blake2b512"
    else
        err "未找到可用的 BLAKE2 计算工具 (b2sum, busybox, openssl)"
        return 1
    fi

    _b2_run() {
        _h_file() {
            if [[ "$cmd_sha" == openssl* ]]; then
                $cmd_sha "$1" 2>/dev/null | $_AWK '{print $NF}'
            else
                $cmd_sha "$1" 2>/dev/null | $_AWK '{print $1}'
            fi
        }
        _h_str() {
            if [[ "$cmd_sha" == openssl* ]]; then
                printf "%s" "$1" | $cmd_sha 2>/dev/null | $_AWK '{print $NF}'
            else
                printf "%s" "$1" | $cmd_sha 2>/dev/null | $_AWK '{print $1}'
            fi
        }
        _case() {
            if [ "$out_upper" = "1" ]; then printf '%s' "$1" | tr 'a-f' 'A-F'; else printf '%s' "$1"; fi
        }
        case "$mode" in
            file)
                [ ! -f "$data" ] && { err "文件不存在: $data"; return 1; }
                local h; h=$(_h_file "$data")
                [ -z "$h" ] && { err "计算 BLAKE2 失败"; return 1; }
                h=$(_case "$h")
                if [ "$quiet" = "1" ]; then printf '%s\n' "$h"
                elif [ "$bsd_tag" = "1" ]; then printf 'BLAKE2 (%s) = %s\n' "$data" "$h"
                else printf '%s  %s\n' "$h" "$data"; fi ;;
            string)
                local h; h=$(_h_str "$data")
                [ -z "$h" ] && { err "计算 BLAKE2 失败"; return 1; }
                h=$(_case "$h")
                if [ "$quiet" = "1" ]; then printf '%s\n' "$h"
                elif [ "$bsd_tag" = "1" ]; then printf 'BLAKE2 ("%s") = %s\n' "$data" "$h"
                else printf '%s\n' "$h"; fi ;;
            check_files)
                local exp_lower; exp_lower=$(printf '%s' "$expected" | tr 'A-Z' 'a-z')
                local failed=0 f h h_lower
                for f in "${multi_args[@]}"; do
                    if [ ! -f "$f" ]; then
                        [ "$status_only" = "1" ] || err "文件不存在: $f"
                        failed=1; continue
                    fi
                    h=$(_h_file "$f")
                    if [ -z "$h" ]; then
                        [ "$status_only" = "1" ] || err "计算 BLAKE2 失败: $f"
                        failed=1; continue
                    fi
                    h_lower=$(printf '%s' "$h" | tr 'A-Z' 'a-z')
                    if [ "$h_lower" = "$exp_lower" ]; then
                        if [ "$status_only" != "1" ]; then
                            if [ "$quiet" = "1" ]; then printf '%s\n' "$f"
                            elif [ "$bsd_tag" = "1" ]; then cecho -c 92 "BLAKE2 ($f) = OK"
                            else cecho -c 92 "$f: 符合"; fi
                        fi
                    else
                        if [ "$status_only" != "1" ] && [ "$quiet" != "1" ]; then
                            if [ "$bsd_tag" = "1" ]; then err "BLAKE2 ($f) = FAILED"
                            else err "$f: 不符合"; fi
                        fi
                        failed=1
                    fi
                done
                return "$failed" ;;
            check_hashes)
                local exp_lower; exp_lower=$(printf '%s' "$expected" | tr 'A-Z' 'a-z')
                local failed=0 h h_lower
                for h in "${multi_args[@]}"; do
                    h_lower=$(printf '%s' "$h" | tr 'A-Z' 'a-z')
                    if [ "$h_lower" = "$exp_lower" ]; then
                        if [ "$status_only" != "1" ]; then
                            if [ "$quiet" = "1" ]; then printf '%s\n' "$h"
                            elif [ "$bsd_tag" = "1" ]; then cecho -c 92 "BLAKE2 ($h) = OK"
                            else cecho -c 92 "$h: 符合"; fi
                        fi
                    else
                        if [ "$status_only" != "1" ] && [ "$quiet" != "1" ]; then
                            if [ "$bsd_tag" = "1" ]; then err "BLAKE2 ($h) = FAILED"
                            else err "$h: 不符合"; fi
                        fi
                        failed=1
                    fi
                done
                return "$failed" ;;
        esac
    }

    local rc=0
    if [ -n "$out_file" ]; then _b2_run > "$out_file" || rc=$?; else _b2_run || rc=$?; fi
    unset -f _b2_run _h_file _h_str _case 2>/dev/null
    return "$rc"
}

# ==================================================================
# CRC32
# ==================================================================
#resource/cmd_crc32.bash
cmd_crc32() {
    if [ $# -eq 0 ]; then
        ccat <<'EOF'
//cecho -b "用法: CRC32 [参数] [数据...]"
  -f <文件>            计算文件的 CRC32 校验和
  -d <字符串>          计算字符串的 CRC32 校验和
  -C <目标> <文件...>  校验多个文件, 逐个输出是否符合目标
  -c <目标> <校验和...> 校验多个校验和, 逐个输出是否符合目标
  -u                   输出大写校验和
  -o <文件|目录>       写入文件; 为目录时自动命名 <cmd>_<时间>.txt
  --tag                BSD 风格输出
  --status             不输出任何内容(仅退出码)
  -q                   只输出校验和, 不显示文件名
  -h, --help           显示此帮助
EOF
        return 0
    fi

    local mode="" mode_opt=""
    local out_upper=0 out_file="" bsd_tag=0 status_only=0 quiet=0
    local -a positional=()

    while [ $# -gt 0 ]; do
        case "$1" in
            -f|-d|-c|-C)
                if [ -n "$mode" ]; then err "不能同时指定 $mode_opt 和 $1"; return 1; fi
                mode_opt="$1"
                case "$1" in
                    -f) mode="file" ;;
                    -d) mode="string" ;;
                    -c) mode="check_hashes" ;;
                    -C) mode="check_files" ;;
                esac
                shift ;;
            -u) out_upper=1; shift ;;
            --tag) bsd_tag=1; shift ;;
            --status) status_only=1; shift ;;
            -q) quiet=1; shift ;;
            -o)
                if [ -z "${2:-}" ]; then err "缺少输出文件参数"; return 1; fi
                out_file=$(_resolve_out_file "$2" "crc32"); shift 2 ;;
            -h|--help)
                ccat <<'EOF'
//cecho -b "用法: CRC32 [参数] [数据...]"
  -f <文件>            计算文件的 CRC32 校验和
  -d <字符串>          计算字符串的 CRC32 校验和
  -C <目标> <文件...>  校验多个文件, 逐个输出是否符合目标
  -c <目标> <校验和...> 校验多个校验和, 逐个输出是否符合目标
  -u                   输出大写校验和
  -o <文件|目录>       写入文件; 为目录时自动命名 <cmd>_<时间>.txt
  --tag                BSD 风格输出
  --status             不输出任何内容(仅退出码)
  -q                   只输出校验和, 不显示文件名
  -h, --help           显示此帮助
EOF
                return 0 ;;
            --) shift; while [ $# -gt 0 ]; do positional+=("$1"); shift; done ;;
            -*) err "未知参数: $1, 使用 CRC32 -h 查看帮助"; return 1 ;;
            *) positional+=("$1"); shift ;;
        esac
    done

    if [ -z "$mode" ]; then err "缺少模式参数 (-f/-d/-c/-C), 使用 CRC32 -h 查看帮助"; return 1; fi
    if [ "$status_only" = "1" ]; then
        case "$mode" in check_files|check_hashes) ;; *) err "--status 只能与 -c/-C 一起使用"; return 1 ;; esac
    fi

    local data="" expected=""
    local -a multi_args=()
    case "$mode" in
        file|string)
            if [ ${#positional[@]} -eq 0 ]; then err "缺少数据参数, 使用 CRC32 -h 查看帮助"; return 1; fi
            if [ ${#positional[@]} -gt 1 ]; then err "模式 $mode_opt 只接受一个参数, 多余: ${positional[*]:1}"; return 1; fi
            data="${positional[0]}" ;;
        check_files|check_hashes)
            if [ ${#positional[@]} -lt 1 ]; then err "缺少目标参数, 使用 CRC32 -h 查看帮助"; return 1; fi
            expected="${positional[0]}"
            multi_args=("${positional[@]:1}")
            if [ ${#multi_args[@]} -eq 0 ]; then err "缺少待校验参数"; return 1; fi ;;
    esac

    # CRC32 工具探测: 优先系统 cksum, 其次 busybox 兜底, 均无则报错
    local _CRC_TOOL=""
    if command -v cksum >/dev/null 2>&1; then
        _CRC_TOOL="cksum"
    elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | $_GREP -q cksum; then
        _CRC_TOOL="busybox cksum"
    else
        err "未找到可用的 CRC32 计算工具 (cksum, busybox)"
        return 1
    fi

    _crc_run() {
        _h_file() {
            local out dec
            out=$($_CRC_TOOL "$1" 2>/dev/null) || return 1
            dec=$(printf '%s' "$out" | $_AWK '{print $1}')
            [ -z "$dec" ] && return 1
            printf '%08x' "$dec"
        }
        _h_str() {
            local tmp
            tmp=$(mktemp 2>/dev/null) || return 1
            printf '%s' "$1" > "$tmp"
            _h_file "$tmp"
            local r=$?
            rm -f "$tmp"
            return $r
        }
        _case() {
            if [ "$out_upper" = "1" ]; then printf '%s' "$1" | tr 'a-f' 'A-F'; else printf '%s' "$1"; fi
        }
        _norm() {
            local v="$1"
            v="${v#0x}"; v="${v#0X}"
            printf '%s' "$v" | tr 'A-Z' 'a-z'
        }
        case "$mode" in
            file)
                [ ! -f "$data" ] && { err "文件不存在: $data"; return 1; }
                local h; h=$(_h_file "$data")
                [ -z "$h" ] && { err "计算 CRC32 失败"; return 1; }
                h=$(_case "$h")
                if [ "$quiet" = "1" ]; then printf '%s\n' "$h"
                elif [ "$bsd_tag" = "1" ]; then printf 'CRC32 (%s) = %s\n' "$data" "$h"
                else printf '%s  %s\n' "$h" "$data"; fi ;;
            string)
                local h; h=$(_h_str "$data")
                [ -z "$h" ] && { err "计算 CRC32 失败"; return 1; }
                h=$(_case "$h")
                if [ "$quiet" = "1" ]; then printf '%s\n' "$h"
                elif [ "$bsd_tag" = "1" ]; then printf 'CRC32 ("%s") = %s\n' "$data" "$h"
                else printf '%s\n' "$h"; fi ;;
            check_files)
                local exp_lower; exp_lower=$(_norm "$expected")
                local failed=0 f h h_lower
                for f in "${multi_args[@]}"; do
                    if [ ! -f "$f" ]; then
                        [ "$status_only" = "1" ] || err "文件不存在: $f"
                        failed=1; continue
                    fi
                    h=$(_h_file "$f")
                    if [ -z "$h" ]; then
                        [ "$status_only" = "1" ] || err "计算 CRC32 失败: $f"
                        failed=1; continue
                    fi
                    h_lower=$(printf '%s' "$h" | tr 'A-Z' 'a-z')
                    if [ "$h_lower" = "$exp_lower" ]; then
                        if [ "$status_only" != "1" ]; then
                            if [ "$quiet" = "1" ]; then printf '%s\n' "$f"
                            elif [ "$bsd_tag" = "1" ]; then cecho -c 92 "CRC32 ($f) = OK"
                            else cecho -c 92 "$f: 符合"; fi
                        fi
                    else
                        if [ "$status_only" != "1" ] && [ "$quiet" != "1" ]; then
                            if [ "$bsd_tag" = "1" ]; then err "CRC32 ($f) = FAILED"
                            else err "$f: 不符合"; fi
                        fi
                        failed=1
                    fi
                done
                return "$failed" ;;
            check_hashes)
                local exp_lower; exp_lower=$(_norm "$expected")
                local failed=0 h h_lower
                for h in "${multi_args[@]}"; do
                    h_lower=$(_norm "$h")
                    if [ "$h_lower" = "$exp_lower" ]; then
                        if [ "$status_only" != "1" ]; then
                            if [ "$quiet" = "1" ]; then printf '%s\n' "$h"
                            elif [ "$bsd_tag" = "1" ]; then cecho -c 92 "CRC32 ($h) = OK"
                            else cecho -c 92 "$h: 符合"; fi
                        fi
                    else
                        if [ "$status_only" != "1" ] && [ "$quiet" != "1" ]; then
                            if [ "$bsd_tag" = "1" ]; then err "CRC32 ($h) = FAILED"
                            else err "$h: 不符合"; fi
                        fi
                        failed=1
                    fi
                done
                return "$failed" ;;
        esac
    }

    local rc=0
    if [ -n "$out_file" ]; then _crc_run > "$out_file" || rc=$?; else _crc_run || rc=$?; fi
    unset -f _crc_run _h_file _h_str _case _norm 2>/dev/null
    unset _CRC_TOOL 2>/dev/null
    return "$rc"
}

# ==================================================================
# BASE64
# ==================================================================
#resource/cmd_base64.bash
cmd_base64() {
    if [ $# -eq 0 ]; then
        ccat <<'EOF'
//cecho -b "用法: BASE64/B64 [参数] [数据...]"
  -d, --decode         解码 (Base64 → 原始数据)
  -f, --file <文件>    从文件读取输入
  -o <文件|目录>       写入文件; 为目录时自动命名 <cmd>_<时间>.txt
  -h, --help           显示此帮助
EOF
        return 0
    fi

    local decode=0 file_mode=0 out_file="" input=""
    local -a positional=()

    while [ $# -gt 0 ]; do
        case "$1" in
            -d|--decode) decode=1; shift ;;
            -f|--file)
                if [ -z "${2:-}" ]; then err "缺少文件参数"; return 1; fi
                file_mode=1; input="$2"; shift 2 ;;
            -o)
                if [ -z "${2:-}" ]; then err "缺少输出文件参数"; return 1; fi
                out_file=$(_resolve_out_file "$2" "base64"); shift 2 ;;
            -h|--help)
                ccat <<'EOF'
//cecho -b "用法: BASE64/B64 [参数] [数据...]"
  -d, --decode         解码 (Base64 → 原始数据)
  -f, --file <文件>    从文件读取输入
  -o <文件|目录>       写入文件; 为目录时自动命名 <cmd>_<时间>.txt
  -h, --help           显示此帮助
EOF
                return 0 ;;
            --) shift; while [ $# -gt 0 ]; do positional+=("$1"); shift; done ;;
            -*) err "未知参数: $1, 使用 BASE64/B64 -h 查看帮助"; return 1 ;;
            *) positional+=("$1"); shift ;;
        esac
    done

    if [ "$file_mode" = "0" ]; then
        if [ ${#positional[@]} -eq 0 ]; then err "缺少数据参数, 使用 BASE64/B64 -h 查看帮助"; return 1; fi
        input="${positional[*]}"
    fi
    if [ -z "$input" ]; then err "缺少数据参数, 使用 BASE64/B64 -h 查看帮助"; return 1; fi

    local b64_cmd=""
    if command -v base64 >/dev/null 2>&1; then
        b64_cmd="base64"
    elif command -v openssl >/dev/null 2>&1; then
        b64_cmd="openssl base64"
    elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | $_GREP -q base64; then
        b64_cmd="busybox base64"
    else
        err "未找到 base64 命令 (请安装 coreutils、busybox 或 openssl)"
        return 1
    fi

    local tmp_in="" src_file=""
    if [ "$file_mode" = "1" ]; then
        [ ! -f "$input" ] && { err "文件不存在: $input"; return 1; }
        src_file="$input"
    else
        tmp_in=$(mktemp 2>/dev/null)
        [ -z "$tmp_in" ] && { err "无法创建临时文件"; return 1; }
        printf '%s' "$input" > "$tmp_in"
        src_file="$tmp_in"
    fi

    _b64_do() {
        if [ "$b64_cmd" = "openssl base64" ]; then
            if [ "$decode" = "1" ]; then openssl base64 -d < "$src_file"; else openssl base64 -e < "$src_file"; fi
        else
            if [ "$decode" = "1" ]; then $b64_cmd -d < "$src_file"; else $b64_cmd < "$src_file"; fi
        fi
    }

    local rc=0
    if [ -n "$out_file" ]; then
        _b64_do > "$out_file" || rc=$?
    else
        _b64_do || rc=$?
    fi

    [ -n "$tmp_in" ] && rm -f "$tmp_in"
    unset -f _b64_do 2>/dev/null

    if [ $rc -ne 0 ]; then
        err "Base64 操作失败(错误码 $rc)"
        return $rc
    fi
    return 0
}

# ==================================================================
# BASE32
# ==================================================================
#resource/cmd_base32.bash
cmd_base32() {
    if [ $# -eq 0 ]; then
        ccat <<'EOF'
//cecho -b "用法: BASE32/B32 [参数] [数据...]"
  -d, --decode         解码 (Base32 → 原始数据)
  -f, --file <文件>    从文件读取输入
  -o <文件|目录>       写入文件; 为目录时自动命名 <cmd>_<时间>.txt
  -h, --help           显示此帮助
EOF
        return 0
    fi

    local decode=0 file_mode=0 out_file="" input=""
    local -a positional=()

    while [ $# -gt 0 ]; do
        case "$1" in
            -d|--decode) decode=1; shift ;;
            -f|--file)
                if [ -z "${2:-}" ]; then err "缺少文件参数"; return 1; fi
                file_mode=1; input="$2"; shift 2 ;;
            -o)
                if [ -z "${2:-}" ]; then err "缺少输出文件参数"; return 1; fi
                out_file=$(_resolve_out_file "$2" "base32"); shift 2 ;;
            -h|--help)
                ccat <<'EOF'
//cecho -b "用法: BASE32/B32 [参数] [数据...]"
  -d, --decode         解码 (Base32 → 原始数据)
  -f, --file <文件>    从文件读取输入
  -o <文件|目录>       写入文件; 为目录时自动命名 <cmd>_<时间>.txt
  -h, --help           显示此帮助
EOF
                return 0 ;;
            --) shift; while [ $# -gt 0 ]; do positional+=("$1"); shift; done ;;
            -*) err "未知参数: $1, 使用 BASE32/B32 -h 查看帮助"; return 1 ;;
            *) positional+=("$1"); shift ;;
        esac
    done

    if [ "$file_mode" = "0" ]; then
        if [ ${#positional[@]} -eq 0 ]; then err "缺少数据参数, 使用 BASE32/B32 -h 查看帮助"; return 1; fi
        input="${positional[*]}"
    fi
    if [ -z "$input" ]; then err "缺少数据参数, 使用 BASE32/B32 -h 查看帮助"; return 1; fi

    local b32_cmd=""
    if command -v base32 >/dev/null 2>&1; then
        b32_cmd="base32"
    elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | $_GREP -q base32; then
        b32_cmd="busybox base32"
    else
        err "未找到 base32 命令 (请安装 coreutils 或 busybox)"
        return 1
    fi

    local tmp_in="" src_file=""
    if [ "$file_mode" = "1" ]; then
        [ ! -f "$input" ] && { err "文件不存在: $input"; return 1; }
        src_file="$input"
    else
        tmp_in=$(mktemp 2>/dev/null)
        [ -z "$tmp_in" ] && { err "无法创建临时文件"; return 1; }
        printf '%s' "$input" > "$tmp_in"
        src_file="$tmp_in"
    fi

    _b32_do() {
        if [ "$decode" = "1" ]; then $b32_cmd -d < "$src_file"; else $b32_cmd < "$src_file"; fi
    }

    local rc=0
    if [ -n "$out_file" ]; then
        _b32_do > "$out_file" || rc=$?
    else
        _b32_do || rc=$?
    fi

    [ -n "$tmp_in" ] && rm -f "$tmp_in"
    unset -f _b32_do 2>/dev/null

    if [ $rc -ne 0 ]; then
        err "Base32 操作失败(错误码 $rc)"
        return $rc
    fi
    return 0
}
