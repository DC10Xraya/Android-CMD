#resource/cmd_git.bash
# 帮助信息
_git_usage() {
    ccat << "EOF"
//cecho -b "用法:"
  GIT [参数]               优先级: 系统 git; 模拟器
  GIT --sys [参数]         强制使用系统 git (无参数进入交互模式)
  GIT --sim <用户> <仓库> <令牌>  强制使用模拟器(by API)

//cecho -b -c 36 "系统 GIT 交互模式子命令"
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
  get <目标...> [本地目录|ZIP文件]  下载仓库中的文件或文件夹到本地
  (默认/storage/emulated/0/Download)
  rm <目标...>               删除仓库中的文件
  // [描述]                  操作提交说明
//cecho -b -c 35 "get子命令特定标志(用于为下载压缩包)"
    -z/--zip         下载为压缩包标志
    --zl [0-9]       指定压缩包等级
    *没有-z时, 如果第二个参数是zip文件, 也按-z处理
    *如果下载的已是zip文件, 则视为重命名
EOF
}

# ---------- 系统 Git 交互模式 ----------
_git_sys_interactive() {
    echo ""
    cecho -b "已进入系统 Git 交互模式 (按 Ctrl+C 中断, 输入 exit/quit/q/git 退出)"
    
    local old_int=$(trap -p INT)
    local interrupted=0
    trap 'interrupted=1; echo ""' INT

    while true; do
        interrupted=0
        printf "\033[38;5;242m[Git]>>> \033[0m"
        if ! read -r input; then
            if [ "$interrupted" -eq 1 ]; then
                continue
            fi
            echo ""
            cecho "退出交互模式"
            break
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

    # _git_urlencode 结果放 _GIT_URLENC
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
        _GIT_URLENC="${encoded}"
    }

    # _git_get_sha 结果放 _GIT_SHA
    _git_get_sha() {
        local path="$1"
        _GIT_SHA=""
        local url="https://api.github.com/repos/$REPO_USER/$REPO_NAME/contents/$(_git_urlencode "$path"; printf '%s' "$_GIT_URLENC")?ref=$BRANCH"
        local res=$($_CURL -s -H "Authorization: token $TOKEN" "$url")
        if [[ "$res" =~ \"sha\":\ *\"([a-f0-9]+)\" ]]; then
            _GIT_SHA="${BASH_REMATCH[1]}"
        fi
    }

    _git_upload_item() {
        local l_path="$1"
        local r_path="$2"
        
        # 清理路径中多余的斜杠
        r_path=$($_SED 's|//*|/|g; s|^/||; s|/$||' <<< "$r_path")

        if [ -d "$l_path" ]; then
            # 如果是目录, 确定基础目录名
            local base_dir="${r_path:-${l_path##*/}}"
            while IFS= read -r file; do
                local rel="${file#$l_path/}"
                _git_upload_item "$file" "${base_dir}/${rel}"
            done < <($_FIND "$l_path" -type f)
        elif [ -f "$l_path" ]; then
            # 如果是文件, 若没有指定 r_path 则使用原文件名
            r_path="${r_path:-${l_path##*/}}"
            _git_urlencode "$r_path"
            local url_path="$_GIT_URLENC"
            _git_get_sha "$r_path"
            local sha="$_GIT_SHA"
            
            cecho "上传: $l_path -> /$r_path"
            
            local tmp_b64="$TMP_DIR/.git_b64.tmp"
            local tmp_json="$TMP_DIR/.git_json.tmp"
            
            > "$tmp_b64"
            if ! base64 -w 0 "$l_path" > "$tmp_b64" 2>/dev/null; then
                > "$tmp_b64"
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
            
            if [[ "$put_res" == *'"content"'* ]]; then
                cecho -c 32 "  成功"
            else
                local err_msg=""
                if [[ "$put_res" =~ \"message\":\ *\"([^\"]*)\" ]]; then
                    err_msg="${BASH_REMATCH[1]}"
                fi
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

        _git_urlencode "$r_path"
        local url_path="$_GIT_URLENC"
        local url="https://api.github.com/repos/$REPO_USER/$REPO_NAME/contents/${url_path}?ref=$BRANCH"
        local res=$($_CURL -s -H "Authorization: token $TOKEN" "$url")

        if [[ "$res" == *'"message": "Not Found"'* ]]; then
            err "远程不存在: /$r_path"
            return
        fi

        if [[ "$res" == *'"type": "dir"'* ]]; then
            $_MKDIR -p "$l_path" 2>/dev/null
            cecho "创建目录: $l_path"
            local names=()
            local _rest="$res"
            local _m
            while [[ "$_rest" =~ \"name\":\ *\"([^\"]*)\" ]]; do
                names+=("${BASH_REMATCH[1]}")
                _m="${BASH_REMATCH[0]}"
                _rest="${_rest#*"$_m"}"
            done
            local n
            for n in "${names[@]}"; do
                _git_download_item "${r_path}/${n}" "${l_path}/${n}"
            done
        else
            cecho "下载: /$r_path -> $l_path"
            local dl_url="https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/$BRANCH/$url_path"
            if $_CURL -L -s -o "$l_path" "$dl_url"; then
                cecho -c 32 "  成功"
            else
                err "  下载失败"
            fi
        fi
    }

    echo ""
    cecho -b "已进入 Git-Sim 交互模式 (按Ctrl+C中断, 输入exit/git退出)"
    
    local old_int=$(trap -p INT)
    local interrupted=0
    trap 'interrupted=1; echo ""' INT
    rm -f "$TMP_DIR"/.git_*.tmp 2>/dev/null

    while true; do
        interrupted=0
        printf "\033[38;5;242m[Git]>>> \033[0m"
        
        if ! read -r input; then
            if [ "$interrupted" -eq 1 ]; then
                continue
            fi
            echo ""
            cecho "退出交互模式"
            break
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
                _git_urlencode "$CURRENT_PATH"
                local url="https://api.github.com/repos/$REPO_USER/$REPO_NAME/contents/${_GIT_URLENC}?ref=$BRANCH"
                local res=$($_CURL -s -H "Authorization: token $TOKEN" "$url")
                
                if [[ "$res" == *'"message": "Not Found"'* ]]; then
                    err "目录不存在或为空"
                elif [[ "$res" =~ ^[[:space:]]*\[ ]]; then
                    local names=()
                    local types=()
                    local _rest="$res"
                    local _m

                    _rest="$res"
                    while [[ "$_rest" =~ \"name\":\ *\"([^\"]*)\" ]]; do
                        names+=("${BASH_REMATCH[1]}")
                        _m="${BASH_REMATCH[0]}"
                        _rest="${_rest#*"$_m"}"
                    done

                    _rest="$res"
                    while [[ "$_rest" =~ \"type\":\ *\"([^\"]*)\" ]]; do
                        types+=("${BASH_REMATCH[1]}")
                        _m="${BASH_REMATCH[0]}"
                        _rest="${_rest#*"$_m"}"
                    done

                    local i
                    for ((i=0; i<${#names[@]}; i++)); do
                        if [ "${types[$i]}" = "dir" ]; then
                            _cprint -c 33 "${names[$i]}/"
                        else
                            cecho "${names[$i]}"
                        fi
                    done
                else
                    if [[ "$res" =~ \"name\":\ *\"([^\"]*)\" ]]; then
                        cecho "${BASH_REMATCH[1]}"
                    fi
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
                    
                    _git_get_sha "$r_path"
                    local sha="$_GIT_SHA"
                    if [ -z "$sha" ]; then
                        err "文件不存在: /$r_path"
                        continue
                    fi
                    _git_urlencode "$r_path"
                    local url_path="$_GIT_URLENC"
                    cecho "删除: /$r_path"
                    local del_res=$($_CURL -s -X DELETE -H "Authorization: token $TOKEN" -H "Content-Type: application/json" \
                        -d "{\"message\": \"Delete $r_path\", \"sha\": \"$sha\", \"branch\": \"$BRANCH\"}" \
                        "https://api.github.com/repos/$REPO_USER/$REPO_NAME/contents/${url_path}")
                    
                    if [[ "$del_res" == *'"commit"'* ]]; then
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
                        if [[ "$target" == */ ]]; then
                            final_r_path="${final_r_path}${item##*/}"
                        fi
                    else
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
                    err "用法: get <文件/文件夹...> [本地目录|ZIP文件]"
                    err "      get <文件/文件夹...> -z [输出.zip]             # 打包下载"
                    err "      get <文件/文件夹...> --zl <0-9> [输出.zip]    # 打包并指定压缩等级"
                    continue
                fi

                local local_dir="/storage/emulated/0/Download/"
                local zip_mode=0
                local zip_output=""
                local zip_level=""
                local -a targets=()
                local parse_error=0

                # 逐项解析: -z/--zip 与 --zl/--zip-level 为选项, 其余加入 targets
                local ai=0
                while [ $ai -lt ${#args[@]} ]; do
                    local a="${args[$ai]}"
                    if [ "$a" = "-z" ] || [ "$a" = "--zip" ]; then
                        zip_mode=1
                        ai=$((ai+1))
                    elif [ "$a" = "--zl" ] || [ "$a" = "--zip-level" ]; then
                        zip_mode=1
                        if [ $((ai+1)) -lt ${#args[@]} ]; then
                            local lv="${args[$((ai+1))]}"
                            if [[ "$lv" =~ ^[0-9]$ ]]; then
                                zip_level="$lv"
                                ai=$((ai+2))
                            else
                                err "--zl 等级必须是 0-9 之间的整数"
                                parse_error=1
                                break
                            fi
                        else
                            err "--zl 缺少等级参数"
                            parse_error=1
                            break
                        fi
                    else
                        targets+=("$a")
                        ai=$((ai+1))
                    fi
                done

                if [ $parse_error -eq 1 ]; then
                    continue
                fi

                if [ ${#targets[@]} -eq 0 ]; then
                    err "缺少要下载的目标"
                    continue
                fi

                # 仅当无显式 -z/--zl 时, 才做末尾 .zip 自动识别
                if [ $zip_mode -eq 0 ] && [ ${#targets[@]} -gt 1 ]; then
                    local last_idx=$(( ${#targets[@]} - 1 ))
                    local last_arg="${targets[$last_idx]}"
                    if [[ "$last_arg" == *.zip ]]; then
                        local all_zip=1
                        local i
                        for ((i=0; i<last_idx; i++)); do
                            [[ "${targets[$i]}" != *.zip ]] && { all_zip=0; break; }
                        done

                        if [ $all_zip -eq 1 ] && [ ${#targets[@]} -eq 2 ]; then
                            # ---------- 重命名下载 ----------
                            local rename_src="${targets[0]}"
                            local rename_dst="$last_arg"
                            local r_src
                            if [[ "$rename_src" == /* ]]; then
                                r_src="${rename_src#/}"
                            else
                                r_src="${CURRENT_PATH:+$CURRENT_PATH/}$rename_src"
                            fi

                            local rename_dir="${rename_dst%/*}"
                            [ "$rename_dir" = "$rename_dst" ] && rename_dir="."
                            [ -n "$rename_dir" ] && [ "$rename_dir" != "." ] && $_MKDIR -p "$rename_dir" 2>/dev/null

                            if [ -e "$rename_dst" ]; then
                                confirm "文件 $rename_dst 已存在, 是否覆盖?" || { cecho "跳过"; continue; }
                                rm -f "$rename_dst" 2>/dev/null
                            fi

                            cecho "重命名下载: /$r_src -> $rename_dst"
                            _git_download_item "$r_src" "$rename_dst"
                            continue
                        elif [ $all_zip -eq 1 ] && [ ${#targets[@]} -gt 2 ]; then
                            err "多个 .zip 目标不能重命名到同一文件, 请指定目录或使用 -z 打包"
                            continue
                        else
                            zip_mode=1
                            zip_output="$last_arg"
                            unset "targets[$last_idx]"
                        fi
                    fi
                fi

                # 末尾目录识别: 目录(带尾斜杠或已存在)作为 local_dir
                if [ ${#targets[@]} -gt 1 ]; then
                    local last_idx=$(( ${#targets[@]} - 1 ))
                    local last_arg="${targets[$last_idx]}"
                    if [ -d "$last_arg" ] || [[ "$last_arg" == */ ]]; then
                        local_dir="$last_arg"
                        unset "targets[$last_idx]"
                    fi
                fi

                # 目录尾斜杠规范化
                case "$local_dir" in
                    */) ;;
                    *)  local_dir="$local_dir/" ;;
                esac

                # 打包模式: 校验 zip 与自动命名
                if [ $zip_mode -eq 1 ]; then
                    if ! command -v zip >/dev/null 2>&1; then
                        err "打包下载需要 zip 命令, 当前系统未安装"
                        continue
                    fi
                    if [ -z "$zip_output" ]; then
                        local base_name="${targets[0]##*/}"
                        [ -z "$base_name" ] && base_name="download"
                        zip_output="${local_dir%/}/${base_name}.zip"
                    fi
                fi

                $_MKDIR -p "$local_dir" 2>/dev/null

                # ================= 打包下载 =================
                if [ $zip_mode -eq 1 ]; then
                    local pack_tmp="$TMP_DIR/git_pack_$$_${RANDOM}_$(date +%s)"
                    $_MKDIR -p "$pack_tmp" 2>/dev/null || {
                        err "无法创建临时打包目录: $pack_tmp"
                        continue
                    }

                    local target
                    for target in "${targets[@]}"; do
                        if [ "${interrupted:-0}" -eq 1 ]; then
                            break
                        fi
                        local r_src
                        if [[ "$target" == /* ]]; then
                            r_src="${target#/}"
                        else
                            r_src="${CURRENT_PATH:+$CURRENT_PATH/}$target"
                        fi
                        _git_download_item "$r_src" "$pack_tmp/"
                    done

                    if [ "${interrupted:-0}" -eq 1 ]; then
                        rm -rf "$pack_tmp" 2>/dev/null
                        continue
                    fi

                    local -a zip_items=()
                    shopt -s dotglob nullglob
                    local _it
                    for _it in "$pack_tmp"/*; do
                        [ -e "$_it" ] && zip_items+=("${_it##*/}")
                    done
                    shopt -u dotglob nullglob

                    if [ ${#zip_items[@]} -eq 0 ]; then
                        err "没有下载到任何文件, 无法打包"
                        rm -rf "$pack_tmp" 2>/dev/null
                        continue
                    fi

                    case "$zip_output" in
                        /*) ;;
                        *)  zip_output="$PWD/$zip_output" ;;
                    esac

                    local zip_dir="${zip_output%/*}"
                    [ "$zip_dir" = "$zip_output" ] && zip_dir="."
                    [ -n "$zip_dir" ] && [ "$zip_dir" != "." ] && $_MKDIR -p "$zip_dir" 2>/dev/null

                    if [ -e "$zip_output" ]; then
                        confirm "文件 $zip_output 已存在, 是否覆盖?" || {
                            cecho "跳过"
                            rm -rf "$pack_tmp" 2>/dev/null
                            continue
                        }
                        rm -f "$zip_output" 2>/dev/null
                    fi

                    local -a zip_args=(-r -q)
                    if [ -n "$zip_level" ]; then
                        zip_args+=("-$zip_level")
                    fi

                    cecho "打包: $zip_output"
                    [ -n "$zip_level" ] && cecho -c 90 "  压缩等级: $zip_level"
                    ( cd "$pack_tmp" && zip "${zip_args[@]}" "$zip_output" "${zip_items[@]}" )
                    local zip_ret=$?
                    rm -rf "$pack_tmp" 2>/dev/null

                    if [ $zip_ret -eq 0 ] && [ -f "$zip_output" ]; then
                        cecho -c 32 "打包完成: $zip_output"
                    else
                        err "打包失败 (退出码: $zip_ret)"
                    fi
                    continue
                fi

                # ================= 普通下载 =================
                local target
                for target in "${targets[@]}"; do
                    if [ "${interrupted:-0}" -eq 1 ]; then
                        break
                    fi
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