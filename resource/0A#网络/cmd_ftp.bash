#resource/cmd_ftp.bash
# ---------- FTP 功能命令 ----------
cmd_ftp() {
    if [ $# -eq 0 ] || [ "$1" != "connect" ]; then
        err "用法: FTP connect <URL>  连接到 FTP 服务器,进入交互模式"
        cecho "示例: FTP connect ftp://demo:password@test.rebex.net:21"
        cecho -b "子命令:(进入交互模式后使用)"
        cecho -b "常规:"
        cecho "exit/ftp -退出交互模式"
        cecho "pwd -显示当前目录 ; cd <目录> -改变目录"
        cecho "ls -列出目录内容 #高亮为文件夹"
        cecho "type <远程文件> -分页预览文本文件"
        echo ""
        cecho "get <远程文件> <本地路径> -下载"  
        cecho -c "#C0C0C0" "#本地路径未指定时使用:/storage/emulated/0/Download/"
        cecho "put <本地文件> <远程路径> -上传"
        cecho -c "#C0C0C0" "#远程路径未指定时将上传到当前目录并保留文件名"
        echo ""
        cecho -b "管理:"
        cecho "rename/ren/mv <旧名> to <新名>    -重命名/移动"
        cecho "delete/rm <文件>                  -删除文件"
        cecho "mkdir <目录名>                    -创建远程目录"
        cecho "copy/cp <源> to <目标>            -复制文件"
        return 0
    fi
    shift

    if [ $# -ne 1 ]; then
        err "用法: FTP connect <URL>"
        return 1
    fi

    local url="$1"
    if ! echo "$url" | grep -qiE '^ftp://'; then
        err "URL 必须以 ftp:// 开头"
        return 1
    fi

    # 解析 URL
    local host="${url#ftp://}"
    local userpass=""
    if [[ "$host" == *"@"* ]]; then
        userpass="${host%%@*}"
        host="${host#*@}"
    fi
    local path="/"
    if [[ "$host" == *"/"* ]]; then
        path="/${host#*/}"
        host="${host%%/*}"
    fi
    local port=21
    if [[ "$host" == *":"* ]]; then
        port="${host##*:}"
        host="${host%:*}"
    fi

    local ftp_user="anonymous"
    local ftp_pass=""
    if [ -n "$userpass" ]; then
        ftp_user="${userpass%:*}"
        ftp_pass="${userpass#*:}"
    fi

    # ---------- 新增 ping 检测 ----------
    cecho "正在测试主机 $host 可达性..."
    if ! ping -c 1 -W 3 "$host" >/dev/null 2>&1; then
        cecho "主机 $host 不可达"
        if ! confirm "是否仍然进入交互模式?"; then
            return 0
        fi
    else
        cecho "主机 $host 可达"
    fi
    # ---------- 检测结束 ----------

    # 检测 curl
    if ! command -v curl >/dev/null 2>&1; then
        err "需要 curl 支持 FTP"
        return 1
    fi

    # 构建基础 FTP URL
    local base_url="ftp://${ftp_user}${ftp_pass:+:$ftp_pass}@$host:$port"
    local current_path="$path"

    cecho -b "已进入FTP交互模式 (按Ctrl+C取消正在运行的操作,输入exit/ftp退出交互模式)"
    cecho -b "当前目录: $current_path"

    # 保存旧陷阱,设置自己的 INT 陷阱(只设置标志)
    local old_trap=$(trap -p INT)
    local interrupted=0
    trap 'interrupted=1' INT

    while true; do
        printf "\033[36m[FTP]>>> \033[0m"
        read -r input
        if [ -z "$input" ]; then
            continue
        fi

        IFS=' ' read -r -a args <<< "$input"
        local cmd="${args[0],,}"
        shift_arg=("${args[@]:1}")

        case "$cmd" in
            exit|ftp)
                cecho "退出交互模式"
                break
                ;;
            pwd)
                cecho "当前目录: $current_path"
                ;;
            ls)
                local list_url="${base_url}${current_path}"
                [[ "$list_url" != */ ]] && list_url="${list_url}/"
                cecho "列出: $list_url"
                interrupted=0
                local list_output
                list_output=$(curl -s "$list_url" 2>/dev/null)
                local curl_exit=$?
                if [ $interrupted -eq 1 ]; then
                    cecho "已取消"
                    interrupted=0
                    continue
                fi
                if [ $curl_exit -ne 0 ] || [ -z "$list_output" ]; then
                    err "无法列出目录,请检查路径或权限"
                    continue
                fi
                echo "$list_output" | while IFS= read -r line; do
                    [ -z "$line" ] && continue
                    local file=$(echo "$line" | awk '{print $NF}')
                    local first_char=$(echo "$line" | cut -c1)
                    if [ "$first_char" = "d" ]; then
                        _cprint -c 33 "$file"
                    else
                        cecho "$file"
                    fi
                done
                ;;
            cd)
                if [ ${#shift_arg[@]} -eq 0 ]; then
                    err "用法: cd <目录>"
                    continue
                fi
                local new_dir="${shift_arg[0]}"
                if [[ "$new_dir" == /* ]]; then
                    current_path="$new_dir"
                elif [ "$new_dir" == ".." ]; then
                    if [ "$current_path" != "/" ]; then
                        current_path="${current_path%/*}"
                        [ -z "$current_path" ] && current_path="/"
                    fi
                else
                    if [ "$current_path" == "/" ]; then
                        current_path="/$new_dir"
                    else
                        current_path="$current_path/$new_dir"
                    fi
                fi
                current_path=$(echo "$current_path" | sed 's|//*|/|g')
                cecho "当前目录: $current_path"
                ;;
            get)
    if [ ${#shift_arg[@]} -lt 1 ]; then
        err "用法: get <远程文件> [本地路径]"
        continue
    fi
    local remote_file="${shift_arg[0]}"
    local local_path
    if [ ${#shift_arg[@]} -ge 2 ]; then
        local_path="${shift_arg[1]}"
    else
        # 默认下载到 /storage/emulated/0/Download/
        local default_download="/storage/emulated/0/Download"
        mkdir -p "$default_download" 2>/dev/null
        local base_name=$(basename "$remote_file")
        local_path="$default_download/$base_name"
            cecho -c "#C0C0C0" "未指定本地路径,将下载到: $local_path"
    fi
    local remote_url="${base_url}${current_path}"
    [[ "$remote_url" != */ ]] && remote_url="${remote_url}/"
    remote_url="${remote_url}${remote_file}"
    cecho "下载: $remote_url"
    local target_dir=$(dirname "$local_path")
    mkdir -p "$target_dir" 2>/dev/null
    if [ -e "$local_path" ]; then
        confirm "文件 $local_path 已存在,是否覆盖?" || { cecho "跳过"; continue; }
    fi
    interrupted=0
    curl -# -o "$local_path" "$remote_url" 2>/dev/null
    local curl_exit=$?
    if [ $interrupted -eq 1 ]; then
        cecho "下载已取消"
        interrupted=0
        rm -f "$local_path" 2>/dev/null
        continue
    fi
    if [ $curl_exit -eq 0 ]; then
        cecho "下载完成: $local_path"
    else
        err "下载失败"
    fi
    ;;
            put)
    if [ ${#shift_arg[@]} -lt 1 ]; then
        err "用法: put <本地文件> [远程路径]"
        continue
    fi
    local local_file="${shift_arg[0]}"
    if [ ! -f "$local_file" ]; then
        err "本地文件不存在: $local_file"
        continue
    fi
    # 如果未指定远程路径,则使用当前目录 + 本地文件名
    local remote_path
    if [ ${#shift_arg[@]} -eq 1 ]; then
        remote_path=$(basename "$local_file")
        cecho -c "#C0C0C0" "未指定远程路径,将上传到当前目录($current_path)并保留文件名($remote_path)"
    else
        remote_path="${shift_arg[1]}"
    fi
    local remote_url="${base_url}${current_path}"
    [[ "$remote_url" != */ ]] && remote_url="${remote_url}/"
    remote_url="${remote_url}${remote_path}"
    cecho "上传: $local_file -> $remote_url"
    interrupted=0
    curl -# -T "$local_file" "$remote_url" 2>/dev/null
    local curl_exit=$?
    if [ $interrupted -eq 1 ]; then
        cecho "上传已取消"
        interrupted=0
        continue
    fi
    if [ $curl_exit -eq 0 ]; then
        cecho "上传完成: $remote_url"
    else
        err "上传失败"
    fi
    ;;
            type)
                if [ ${#shift_arg[@]} -ne 1 ]; then
                    err "用法: type <远程文件>"
                    continue
                fi
                local remote_file="${shift_arg[0]}"
                local remote_url="${base_url}${current_path}"
                [[ "$remote_url" != */ ]] && remote_url="${remote_url}/"
                remote_url="${remote_url}${remote_file}"
                local tmp_dir="/storage/emulated/0/Download"
                mkdir -p "$tmp_dir" 2>/dev/null
                local tmp_file="$tmp_dir/ftp_preview_$$.tmp"
                cecho "预览: $remote_url"
                interrupted=0
                curl -s -o "$tmp_file" "$remote_url" 2>/dev/null
                local curl_exit=$?
                if [ $interrupted -eq 1 ]; then
                    cecho "预览取消"
                    interrupted=0
                    rm -f "$tmp_file" 2>/dev/null
                    continue
                fi
                if [ $curl_exit -ne 0 ] || [ ! -f "$tmp_file" ]; then
                    err "无法下载预览文件"
                    rm -f "$tmp_file" 2>/dev/null
                    continue
                fi
                if command -v more >/dev/null 2>&1; then
                    cecho "------------------ 预览开始 ------------------"
                    more "$tmp_file" 2>/dev/null
                    cecho "------------------ 预览结束 ------------------"
                    rm -f "$tmp_file" 2>/dev/null
                else
                    cecho "more 命令不可用,请选择操作:"
                    cecho "m=移动, d=删除, n=保留, c=用 cat 查看 (实验性)"
                    while true; do
                        printf "\033[36m选择操作: \033[0m"
                        read -r choice
                        case "$choice" in
                            m|M)
                                printf "请输入目标路径 (目录或文件): "
                                read -r target_path
                                if [ -z "$target_path" ]; then
                                    err "路径不能为空"
                                    continue
                                fi
                                target_dir=$(dirname "$target_path")
                                mkdir -p "$target_dir" 2>/dev/null
                                if mv "$tmp_file" "$target_path" 2>/dev/null; then
                                    cecho "已移动到: $target_path"
                                else
                                    err "移动失败,请检查路径权限"
                                fi
                                break
                                ;;
                            d|D)
                                rm -f "$tmp_file" 2>/dev/null
                                cecho "已删除临时文件"
                                break
                                ;;
                            n|N)
                                cecho "已保留在: $tmp_file"
                                break
                                ;;
                            c|C)
                                cecho "实验性: 使用 cat 查看 (无分页)"
                                cat "$tmp_file" 2>/dev/null | while IFS= read -r line; do
                                    cecho "$line"
                                done
                                rm -f "$tmp_file" 2>/dev/null
                                break
                                ;;
                            *)
                                err "无效选择,请输入 m, d, n 或 c"
                                ;;
                        esac
                    done
                fi
                ;;
rename|ren|mv)
    if [ ${#shift_arg[@]} -lt 3 ]; then
        err "用法: rename/ren/mv <旧名> to <新名>"
        continue
    fi
    # 查找 "to" 的位置
    local to_pos=-1
    local i=0
    while [ $i -lt ${#shift_arg[@]} ]; do
        if [ "${shift_arg[$i]}" = "to" ]; then
            to_pos=$i
            break
        fi
        i=$((i+1))
    done
    if [ $to_pos -eq -1 ]; then
        err "未找到 'to', 用法: ~ <旧名> to <新名>"
        continue
    fi
    # 旧名: 从位置0到to_pos-1
    local old=""
    for ((i=0; i<to_pos; i++)); do
        if [ -n "$old" ]; then
            old="$old ${shift_arg[$i]}"
        else
            old="${shift_arg[$i]}"
        fi
    done
    # 新名: 从to_pos+1到结束
    local new=""
    for ((i=to_pos+1; i<${#shift_arg[@]}; i++)); do
        if [ -n "$new" ]; then
            new="$new ${shift_arg[$i]}"
        else
            new="${shift_arg[$i]}"
        fi
    done
    if [ -z "$old" ] || [ -z "$new" ]; then
        err "旧名和新名都不能为空"
        continue
    fi
    cecho "重命名: $old -> $new"
    interrupted=0
    curl -Q "RNFR $old" -Q "RNTO $new" "${base_url}${current_path}/" 2>/dev/null
    local curl_exit=$?
    if [ $interrupted -eq 1 ]; then
        cecho "操作已取消"
        interrupted=0
        continue
    fi
    if [ $curl_exit -eq 0 ]; then
        cecho "重命名成功"
    else
        err "重命名失败, 请检查权限或路径"
    fi
    ;;
copy|cp)
    if [ ${#shift_arg[@]} -lt 3 ]; then
        err "用法: copy/cp <源> to <目标>"
        continue
    fi
    # 查找 "to" 的位置
    local to_pos=-1
    local i=0
    while [ $i -lt ${#shift_arg[@]} ]; do
        if [ "${shift_arg[$i]}" = "to" ]; then
            to_pos=$i
            break
        fi
        i=$((i+1))
    done
    if [ $to_pos -eq -1 ]; then
        err "未找到 'to', 用法: ~ <源> to <目标>"
        continue
    fi
    # 源: 从位置0到to_pos-1
    local src=""
    for ((i=0; i<to_pos; i++)); do
        if [ -n "$src" ]; then
            src="$src ${shift_arg[$i]}"
        else
            src="${shift_arg[$i]}"
        fi
    done
    # 目标: 从to_pos+1到结束
    local dst=""
    for ((i=to_pos+1; i<${#shift_arg[@]}; i++)); do
        if [ -n "$dst" ]; then
            dst="$dst ${shift_arg[$i]}"
        else
            dst="${shift_arg[$i]}"
        fi
    done
    if [ -z "$src" ] || [ -z "$dst" ]; then
        err "源和目标都不能为空"
        continue
    fi
    cecho "复制: $src -> $dst"
    # 尝试服务器端复制
    interrupted=0
    curl -Q "SITE CP $src $dst" "${base_url}${current_path}/" 2>/dev/null
    local curl_exit=$?
    if [ $interrupted -eq 1 ]; then
        cecho "操作已取消"
        interrupted=0
        continue
    fi
    if [ $curl_exit -eq 0 ]; then
        cecho "复制成功(服务器端)"
    else
        cecho "服务器不支持 SITE CP, 尝试下载再上传..."
        local tmp_base="${TMP_DIR:-/storage/emulated/0/tmp}"
        mkdir -p "$tmp_base" 2>/dev/null || {
            err "无法创建临时目录: $tmp_base"
            continue
        }
        local tmp_file="$tmp_base/ftp_copy_$$.tmp"
        local src_url="${base_url}${current_path}/${src}"
        local dst_url="${base_url}${current_path}/${dst}"
        cecho "下载源文件: $src_url"
        curl -s -o "$tmp_file" "$src_url" 2>/dev/null
        if [ $? -ne 0 ] || [ ! -s "$tmp_file" ]; then
            err "下载源文件失败"
            rm -f "$tmp_file" 2>/dev/null
            continue
        fi
        cecho "上传到目标: $dst_url"
        curl -# -T "$tmp_file" "$dst_url" 2>/dev/null
        local upload_exit=$?
        rm -f "$tmp_file" 2>/dev/null
        if [ $upload_exit -eq 0 ]; then
            cecho "复制完成(通过本地中转)"
        else
            err "上传目标失败, 复制未完成"
        fi
    fi
    ;;
    delete|rm)
    if [ ${#shift_arg[@]} -eq 0 ]; then
        err "用法: delete/rm <文件>"
        continue
    fi
    # 合并所有参数为文件名
    local file=""
    for arg in "${shift_arg[@]}"; do
        if [ -n "$file" ]; then
            file="$file $arg"
        else
            file="$arg"
        fi
    done
    cecho "删除: $file"
    confirm "确定要删除 $file 吗?" || { cecho "已取消"; continue; }
    interrupted=0
    curl -Q "DELE $file" "${base_url}${current_path}/" 2>/dev/null
    local curl_exit=$?
    if [ $interrupted -eq 1 ]; then
        cecho "操作已取消"
        interrupted=0
        continue
    fi
    if [ $curl_exit -eq 0 ]; then
        cecho "删除成功"
    else
        err "删除失败, 请检查权限或文件是否存在"
    fi
    ;;
    mkdir)
    if [ ${#shift_arg[@]} -eq 0 ]; then
        err "用法: mkdir <目录名>"
        continue
    fi
    # 将所有参数合并为一个目录名(支持空格)
    local dir=""
    for arg in "${shift_arg[@]}"; do
        if [ -n "$dir" ]; then
            dir="$dir $arg"
        else
            dir="$arg"
        fi
    done
    local dir_url="${base_url}${current_path}/${dir}"
    cecho "创建目录: $dir"
    interrupted=0
    curl -Q "MKD $dir" "${base_url}${current_path}/" 2>/dev/null
    local curl_exit=$?
    if [ $interrupted -eq 1 ]; then
        cecho "操作已取消"
        interrupted=0
        continue
    fi
    if [ $curl_exit -eq 0 ]; then
        cecho "目录创建成功"
    else
        err "创建目录失败, 请检查权限或名称"
    fi
    ;;
            *)
                err "未知子命令可用: exit/ftp, pwd, cd, ls, type, get, put, rename/ren/mv, delete/rm, mkdir, copy/cp"
                ;;
        esac
    done

    # 恢复旧陷阱
    if [ -n "$old_trap" ]; then eval "$old_trap"; else trap - INT; fi
    return 0
}