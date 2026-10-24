#resource/cmd_git.bash
# 帮助信息
_git_usage() {
    ccat << "EOF"
//cecho -b "用法:"
  GIT [参数]               优先级: 系统 git; 模拟器
  GIT --sys [参数]         强制使用系统 git (无参数进入交互模式)
  GIT --sim <用户> <仓库> <令牌>  强制使用模拟器(by API)

//cecho -b -c 36 "系统 GIT 交互模式子命令:"
  exit/quit/q/git           退出交互模式
  [系统命令...]             看我干嘛qwq

//cecho -b -c 36 "GIT API 模拟器"
//cecho -b "用法: GIT <用户名> <仓库> <令牌>"
//cecho -b "交互模式子命令:"
  exit/git                  退出交互模式
//cecho "常规操作:"
  pwd                       显示当前所在的仓库目录
  cd <目录>                 进入仓库中的子目录
  ls                        列出当前目录下的文件及文件夹(高亮为文件夹)
  branch [分支名]           查看或切换当前操作的分支 (默认 main)
//cecho "文件操作:"
  put <本地路径...> [目标]  上传本地文件或文件夹到仓库
  cp <本地文件> <目标>      强制将本地文件覆盖到指定目标 (一一对应)
  get <目标...> [本地目录]  下载仓库中的文件或文件夹到本地
  (默认/storage/emulated/0/Download)
  rm <目标...>               删除仓库中的文件
  // [描述]                  操作提交说明
EOF
}

# ---------- 系统 Git 交互模式 ----------
_git_sys_interactive() {
    echo ""
    cecho -b "已进入系统 Git 交互模式 (按 Ctrl+C 中断, 输入 exit/quit/q/git 退出)"
    
    local old_int=$(trap -p INT)
    trap 'echo ""' INT

    while true; do
        printf "\033[38;5;242m[Git]>>> \033[0m"
        if ! read -r input; then
            echo ""
            continue
        fi
        [ -z "$input" ] && continue

        parse_line "$input"
        if [ ${#PARSED_ARGS[@]} -eq 0 ]; then
            continue
        fi
        local cmd="${PARSED_ARGS[0],,}"
        local args=("${PARSED_ARGS[@]:1}")

        if [ "$cmd" = "exit" ] || [ "$cmd" = "quit" ] || [ "$cmd" = "q" ] || [ "$cmd" = "git" ]; then
            cecho "退出交互模式"
            break
        fi

        # 透传给系统 git
        git "$cmd" "${args[@]}"
    done

    eval "$old_int" 2>/dev/null || trap - INT
}

# ---------- 模拟器 (API) 交互模式 ----------
_git_sim_interactive() {
    local REPO_USER="$1"
    local REPO_NAME="$2"
    local TOKEN="$3"
    local BRANCH="main"
    local CURRENT_PATH=""

    cecho "正在校验 GitHub 令牌..."
    local http_code=$($_CURL -s -o /dev/null -w "%{http_code}" -H "Authorization: token $TOKEN" "https://api.github.com/user")
    
    if [ "$http_code" != "200" ]; then
        err "令牌无效或网络错误 (HTTP $http_code)"
        if ! confirm "是否仍然进入交互模式"; then
            return 1
        fi
    else
        cecho -c 32 "令牌校验通过"
    fi

    _git_urlencode() {
        local string="$1"
        local strlen=${#string}
        local encoded=""
        local pos c o
        for (( pos=0 ; pos<strlen ; pos++ )); do
            c=${string:$pos:1}
            case "$c" in
                [-_.~a-zA-Z0-9/] ) o="${c}" ;;
                * )               printf -v o '%%%02x' "'$c"
            esac
            encoded+="${o}"
        done
        echo "${encoded}"
    }

    _git_get_sha() {
        local path="$1"
        local url="https://api.github.com/repos/$REPO_USER/$REPO_NAME/contents/$(_git_urlencode "$path")?ref=$BRANCH"
        local res=$($_CURL -s -H "Authorization: token $TOKEN" "$url")
        if echo "$res" | $_GREP -q '"sha":'; then
            echo "$res" | $_GREP -o '"sha": "[a-f0-9]*' | head -1 | $_CUT -d '"' -f 4
        fi
    }

    _git_upload_item() {
        local l_path="$1"
        local r_path="$2"
        
        # 清理路径中多余的斜杠
        r_path=$($_SED 's|//*|/|g; s|^/||; s|/$||' <<< "$r_path")

        if [ -d "$l_path" ]; then
            # 如果是目录，确定基础目录名
            local base_dir="${r_path:-${l_path##*/}}"
            $_FIND "$l_path" -type f | while read -r file; do
                local rel="${file#$l_path/}"
                _git_upload_item "$file" "${base_dir}/${rel}"
            done
        elif [ -f "$l_path" ]; then
            # 如果是文件，若没有指定 r_path 则使用原文件名
            r_path="${r_path:-${l_path##*/}}"
            local url_path=$(_git_urlencode "$r_path")
            local sha=$(_git_get_sha "$r_path")
            
            cecho "上传: $l_path -> /$r_path"
            
            local tmp_b64="$TMP_DIR/.git_b64.tmp"
            local tmp_json="$TMP_DIR/.git_json.tmp"
            
            if base64 -w 0 "$l_path" > /dev/null 2>&1; then
                base64 -w 0 "$l_path" > "$tmp_b64"
            else
                base64 "$l_path" | tr -d '\n' > "$tmp_b64"
            fi
            
            echo -n "{\"message\": \"Upload $r_path\", \"content\": \"" > "$tmp_json"
            $_CAT "$tmp_b64" >> "$tmp_json"
            echo -n "\", \"branch\": \"$BRANCH\"" >> "$tmp_json"
            if [ -n "$sha" ]; then
                echo -n ", \"sha\": \"$sha\"" >> "$tmp_json"
            fi
            echo -n "}" >> "$tmp_json"
            
            local put_res=$($_CURL -s -X PUT -H "Authorization: token $TOKEN" -H "Content-Type: application/json" \
                "https://api.github.com/repos/$REPO_USER/$REPO_NAME/contents/${url_path}" \
                --data-binary @"$tmp_json")
                
            rm -f "$tmp_b64" "$tmp_json"
            
            if echo "$put_res" | $_GREP -q '"content"'; then
                cecho -c 32 "  成功"
            else
                local err_msg=$(echo "$put_res" | $_GREP -o '"message": "[^"]*' | head -1 | $_CUT -d '"' -f 4)
                if [ -n "$err_msg" ]; then
                    err "  上传失败 (API报错): $err_msg"
                else
                    err "  上传失败 (网络中断或响应异常)"
                fi
            fi
        fi
    }

    _git_download_item() {
        local r_path="$1"
        local l_path="$2"
        
        if [[ "$l_path" == */ ]]; then
            l_path="${l_path}${r_path##*/}"
        fi

        local url_path=$(_git_urlencode "$r_path")
        local url="https://api.github.com/repos/$REPO_USER/$REPO_NAME/contents/${url_path}?ref=$BRANCH"
        local res=$($_CURL -s -H "Authorization: token $TOKEN" "$url")

        if echo "$res" | $_GREP -q '"message": "Not Found"'; then
            err "远程不存在: /$r_path"
            return
        fi

        if echo "$res" | $_GREP -q '"type": "dir"'; then
            $_MKDIR -p "$l_path" 2>/dev/null
            cecho "创建目录: $l_path"
            local names=()
            while IFS= read -r name; do names+=("$name"); done < <(echo "$res" | $_GREP -o '"name": "[^"]*"' | $_CUT -d '"' -f 4)
            local n
            for n in "${names[@]}"; do
                _git_download_item "${r_path}/${n}" "${l_path}/${n}"
            done
        else
            cecho "下载: /$r_path -> $l_path"
            local dl_url="https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/$BRANCH/$url_path"
            $_CURL -L -s -o "$l_path" "$dl_url"
            if [ $? -eq 0 ]; then
                cecho -c 32 "  成功"
            else
                err "  下载失败"
            fi
        fi
    }

    echo ""
    cecho -b "已进入 Git-Sim 交互模式 (按Ctrl+C中断, 输入exit/git退出)"
    
    local old_int=$(trap -p INT)
    trap 'echo ""' INT
    rm -f "$TMP_DIR"/.git_*.tmp 2>/dev/null

    while true; do
        printf "\033[38;5;242m[Git]>>> \033[0m"
        
        if ! read -r input; then
            echo ""
            continue
        fi
        [ -z "$input" ] && continue

        parse_line "$input"
        if [ ${#PARSED_ARGS[@]} -eq 0 ]; then
            continue
        fi
        local cmd="${PARSED_ARGS[0],,}"
        local raw_args=("${PARSED_ARGS[@]:1}")
        
        local args=()
        local comment=""
        local stop_parsing=0
        for arg in "${raw_args[@]}"; do
            if [ "$stop_parsing" -eq 1 ]; then
                comment="$comment $arg"
            elif [[ "$arg" == //* ]]; then
                stop_parsing=1
                comment="${arg#//}"
            elif [ "$arg" = "//" ]; then
                stop_parsing=1
            else
                args+=("$arg")
            fi
        done

        if [ "$cmd" = "exit" ] || [ "$cmd" = "quit" ] || [ "$cmd" = "q" ] || [ "$cmd" = "git" ]; then
            cecho "退出交互模式"
            break
        fi

        if [ -n "$comment" ]; then
            cecho -c 90 "任务说明: $comment"
        fi

        case "$cmd" in
            pwd)
                [ -z "$CURRENT_PATH" ] && cecho "/" || cecho "/$CURRENT_PATH"
                ;;
            cd)
                local target="${args[0]}"
                if [ -z "$target" ] || [ "$target" = "/" ]; then
                    CURRENT_PATH=""
                elif [ "$target" = ".." ]; then
                    CURRENT_PATH="${CURRENT_PATH%/*}"
                elif [[ "$target" == /* ]]; then
                    CURRENT_PATH="${target#/}"
                else
                    CURRENT_PATH="${CURRENT_PATH:+$CURRENT_PATH/}$target"
                fi
                CURRENT_PATH=$($_SED 's|//*|/|g; s|^/||; s|/$||' <<< "$CURRENT_PATH")
                cecho "当前目录: /$CURRENT_PATH"
                ;;
            branch)
                if [ ${#args[@]} -eq 0 ]; then
                    cecho "当前分支: $BRANCH"
                else
                    BRANCH="${args[0]}"
                    cecho "已切换分支为: $BRANCH"
                fi
                ;;
            ls)
                local url="https://api.github.com/repos/$REPO_USER/$REPO_NAME/contents/$(_git_urlencode "$CURRENT_PATH")?ref=$BRANCH"
                local res=$($_CURL -s -H "Authorization: token $TOKEN" "$url")
                
                if echo "$res" | $_GREP -q '"message": "Not Found"'; then
                    err "目录不存在或为空"
                elif echo "$res" | $_GREP -q '^\['; then
                    local names=()
                    local types=()
                    while IFS= read -r line; do names+=("$line"); done < <(echo "$res" | $_GREP -o '"name": "[^"]*"' | $_CUT -d '"' -f 4)
                    while IFS= read -r line; do types+=("$line"); done < <(echo "$res" | $_GREP -o '"type": "[^"]*"' | $_CUT -d '"' -f 4)

                    local i
                    for ((i=0; i<${#names[@]}; i++)); do
                        if [ "${types[$i]}" = "dir" ]; then
                            _cprint -c 33 "${names[$i]}/"
                        else
                            cecho "${names[$i]}"
                        fi
                    done
                else
                    local name=$(echo "$res" | $_GREP -o '"name": "[^"]*"' | $_CUT -d '"' -f 4)
                    [ -n "$name" ] && cecho "$name"
                fi
                ;;
            rm)
                if [ ${#args[@]} -eq 0 ]; then
                    err "用法: rm <文件/文件夹...>"
                    continue
                fi
                for target in "${args[@]}"; do
                    local r_path
                    if [[ "$target" == /* ]]; then
                        r_path="${target#/}"
                    else
                        r_path="${CURRENT_PATH:+$CURRENT_PATH/}$target"
                    fi
                    
                    local sha=$(_git_get_sha "$r_path")
                    if [ -z "$sha" ]; then
                        err "文件不存在: /$r_path"
                        continue
                    fi
                    local url_path=$(_git_urlencode "$r_path")
                    cecho "删除: /$r_path"
                    local del_res=$($_CURL -s -X DELETE -H "Authorization: token $TOKEN" -H "Content-Type: application/json" \
                        -d "{\"message\": \"Delete $r_path\", \"sha\": \"$sha\", \"branch\": \"$BRANCH\"}" \
                        "https://api.github.com/repos/$REPO_USER/$REPO_NAME/contents/${url_path}")
                    
                    if echo "$del_res" | $_GREP -q '"commit"'; then
                        cecho -c 32 "  删除成功"
                    else
                        err "  删除失败 (如果是目录, 请先清空内部文件)"
                    fi
                done
                ;;
            put)
                if [ ${#args[@]} -eq 0 ]; then
                    err "用法: put <本地文件/文件夹...> [目标路径]"
                    continue
                fi
                local target=""
                if [ ${#args[@]} -gt 1 ]; then
                    local last_arg="${args[${#args[@]}-1]}"
                    if [ ! -e "$last_arg" ]; then
                        target="$last_arg"
                        unset "args[${#args[@]}-1]"
                    fi
                fi
                
                for item in "${args[@]}"; do
                    if [ ! -e "$item" ]; then
                        err "本地不存在: $item"
                        continue
                    fi
                    
                    local final_r_path=""
                    if [ -n "$target" ]; then
                        if [[ "$target" == /* ]]; then
                            final_r_path="${target#/}"
                        else
                            final_r_path="${CURRENT_PATH:+$CURRENT_PATH/}$target"
                        fi
                        # 如果目标以 / 结尾，说明是目录，自动补上原文件名/目录名
                        if [[ "$target" == */ ]]; then
                            final_r_path="${final_r_path}${item##*/}"
                        fi
                    else
                        # 如果没指定目标，直接传至当前目录并保留原名
                        final_r_path="${CURRENT_PATH:+$CURRENT_PATH/}${item##*/}"
                    fi
                    
                    _git_upload_item "$item" "$final_r_path"
                done
                ;;
            cp)
                if [ ${#args[@]} -lt 2 ]; then
                    err "用法: cp <本地文件> <远程目标> [本地文件 远程目标...]"
                    err "提示: 如果只需将文件传到当前目录并保留原名, 请直接使用 put <本地文件>"
                    continue
                fi
                local idx=0
                while [ $idx -lt ${#args[@]} ]; do
                    local l_src="${args[$idx]}"
                    local r_dst="${args[$((idx+1))]}"
                    idx=$((idx+2))
                    
                    if [ ! -e "$l_src" ]; then
                        err "本地不存在: $l_src"
                        continue
                    fi
                    
                    local r_target
                    if [[ "$r_dst" == /* ]]; then
                        r_target="${r_dst#/}"
                    else
                        r_target="${CURRENT_PATH:+$CURRENT_PATH/}$r_dst"
                    fi
                    
                    _git_upload_item "$l_src" "$r_target"
                done
                ;;
            get)
                if [ ${#args[@]} -eq 0 ]; then
                    err "用法: get <文件/文件夹...> [本地目录, 默认 /storage/emulated/0/Download/]"
                    continue
                fi
                local local_dir="/storage/emulated/0/Download/"
                if [ ${#args[@]} -gt 1 ]; then
                    local last_arg="${args[${#args[@]}-1]}"
                    if [[ "$last_arg" == */ ]] || [ -d "$last_arg" ]; then
                        local_dir="$last_arg"
                        unset "args[${#args[@]}-1]"
                    fi
                fi
                $_MKDIR -p "$local_dir" 2>/dev/null
                for target in "${args[@]}"; do
                    local r_src
                    if [[ "$target" == /* ]]; then
                        r_src="${target#/}"
                    else
                        r_src="${CURRENT_PATH:+$CURRENT_PATH/}$target"
                    fi
                    _git_download_item "$r_src" "$local_dir"
                done
                ;;
            *)
                err "未知命令, 可用: branch, put, rm, cp, get, cd, pwd, ls, exit"
                ;;
        esac
    done

    eval "$old_int" 2>/dev/null || trap - INT
    return 0
}


# ---------- 主入口函数 ----------
cmd_git() {
    local mode=""
    
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        _git_usage
        return 0
    fi

    if [ "$1" = "--sys" ]; then
        mode="sys"
        shift
    elif [ "$1" = "--sim" ]; then
        mode="sim"
        shift
    fi

    # 检查系统是否存在 git
    local has_sys_git=0
    command -v git >/dev/null 2>&1 && has_sys_git=1

    # 默认行为
    if [ -z "$mode" ]; then
        if [ $has_sys_git -eq 1 ]; then
            mode="sys"
        elif [ $# -ge 3 ]; then
            mode="sim"
        else
            _git_usage
            return 1
        fi
    fi

    if [ "$mode" = "sys" ]; then
        if [ $has_sys_git -eq 0 ]; then
            err "系统未安装 git 命令"
            return 1
        fi
        if [ $# -eq 0 ]; then
            _git_sys_interactive
        else
            git "$@"
        fi
    elif [ "$mode" = "sim" ]; then
        if [ $# -lt 3 ]; then
            err "模拟器需要 3 个参数: <用户名> <仓库> <令牌>"
            return 1
        fi
        _git_sim_interactive "$@"
    fi
}