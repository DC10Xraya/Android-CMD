#!/bin/bash
# Android CMD(VER: ⤸)
CMD_VER="0.30_pre2"
# https://github.com/DC10Xraya/Android-CMD
# tip: 终端长度65获得最佳观感(帮助菜单在这个情况下制作)
# ------CMDINFO------
cmd_info() {
cecho -b "--- 关于 Android CMD ---"
    ccat << EOF
版本: $CMD_VER
作者: DC10Xray
许可证: MIT   Copyright (c) 2026 DC10Xray
//cecho -c "#6CA8F1" -u "https://github.com/DC10Xraya/Android-CMD/releases"
EOF
    cecho -b "--- MIT ---"
    ccat << "EOF"
//cecho -b "MIT License"

Copyright (c) 2026 DC10Xray

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

EOF
}
# 说虽然现在ccat没定义, 但是等到用户输入这个命令的时候就已经定义完了

# 进程数限制
_ORIG_ULIMIT_U="$(ulimit -u 2>/dev/null)"
_restore_ulimit() {
    [ -n "$_ORIG_ULIMIT_U" ] || return 0
    ulimit -u "$_ORIG_ULIMIT_U" 2>/dev/null
}
trap '_restore_ulimit' EXIT
ulimit -u 1024

err() { printf "\033[31m%s\033[0m\n" "$*" >&2; }
CMD_RUNNING_Err_title="----------------CMD ERROR----------------"
CMD_Target="要求:必须由 bash 4.0+ 执行, 且支持数组特性"

# bash 
if [ -z "$BASH_VERSION" ]; then
    err "$CMD_RUNNING_Err_title"
    err "请使用 bash 执行!"
    err "$CMD_Target"
    exit 64
fi
if ! (arr=(1 2); (( ${#arr[@]} == 2 ))) 2>/dev/null; then
    err "$CMD_RUNNING_Err_title"
    err "当前 bash 版本过低(4.0-)或功能不完整(不支持数组)"
    err "$CMD_Target"
    exit 70
fi

# 检测 busybox applet 列表(提前缓存, 供工具选择和缺失检测复用)
_BUSYBOX_APPLETS=""
_BB_ARR=()
if command -v busybox >/dev/null 2>&1; then
    _BUSYBOX_APPLETS="$(busybox --list 2>/dev/null)"
    if [ -n "$_BUSYBOX_APPLETS" ]; then
        mapfile -t _BB_ARR <<< "$_BUSYBOX_APPLETS"
    fi
fi

# 纯 bash 判断 busybox 是否提供某 applet (避免 fork grep)
_bb_has() {
    local name="$1" a
    for a in "${_BB_ARR[@]}"; do
        [ "$a" = "$name" ] && return 0
    done
    return 1
}

# 必须工具 (优先真实系统命令, 其次 busybox 兜底)
MISSING=""
for cmd in awk grep sed cat cut head tail bc; do
    if command -v "$cmd" >/dev/null 2>&1; then
        continue
    fi
    if _bb_has "$cmd"; then
        continue
    fi
    MISSING="$MISSING $cmd"
done
if [ -n "$MISSING" ]; then
    err "$CMD_RUNNING_Err_title"
    err "缺少以下必须命令: $MISSING"
    err "请安装对应的软件包, 否则无法启动"
    exit 127
fi

# ------- 工具检测 -------
# 万年不变的检测工具还是变了
init_tools() {
    # 选择工具: 优先系统独立命令, 其次 busybox 兜底
    _pick_tool() {
        local name="$1"
        if command -v "$name" >/dev/null 2>&1; then
            printf '%s' "$name"
        elif _bb_has "$name"; then
            printf 'busybox %s' "$name"
        else
            # 不存在则保留原名, 调用时会返回 127, 由上层处理
            printf '%s' "$name"
        fi
    }

    _AWK="$(_pick_tool awk)";           _CAT="$(_pick_tool cat)"
    _CUT="$(_pick_tool cut)";           _DATE="$(_pick_tool date)"
    _GREP="$(_pick_tool grep)";         _HEAD="$(_pick_tool head)"
    _HOSTNAME="$(_pick_tool hostname)"; _IFCONFIG="$(_pick_tool ifconfig)"
    _IP="$(_pick_tool ip)";             _LS="$(_pick_tool ls)"
    _MKDIR="$(_pick_tool mkdir)";       _MV="$(_pick_tool mv)"
    _CP="$(_pick_tool cp)";             _RM="$(_pick_tool rm)"
    _RMDIR="$(_pick_tool rmdir)";       _NETSTAT="$(_pick_tool netstat)"
    _PS="$(_pick_tool ps)";             _PING="$(_pick_tool ping)"
    _UPTIME="$(_pick_tool uptime)";     _WHOAMI="$(_pick_tool whoami)"
    _FREE="$(_pick_tool free)";         _DF="$(_pick_tool df)"
    _UNAME="$(_pick_tool uname)";       _SED="$(_pick_tool sed)"
    _FIND="$(_pick_tool find)";         _SORT="$(_pick_tool sort)"
    _TAIL="$(_pick_tool tail)";         _STAT="$(_pick_tool stat)"
    _WGET="$(_pick_tool wget)";         _CURL="$(_pick_tool curl)"

    unset -f _pick_tool
}
init_tools

# 网络工具可用性
# 优先级: 真实系统命令 > busybox 兜底
HAS_CURL=0
HAS_WGET=0

if [ -n "$_CURL" ]; then
    $_CURL --help >/dev/null 2>&1
    [ $? -ne 127 ] && HAS_CURL=1
fi
if [ -n "$_WGET" ]; then
    $_WGET --help >/dev/null 2>&1
    [ $? -ne 127 ] && HAS_WGET=1
fi

if [ $((HAS_CURL + HAS_WGET)) -eq 0 ]; then
    err "$CMD_RUNNING_Err_title"
    err "需要 curl 或 wget 中的至少一个, 但均未找到"
    err "请安装 curl 或 wget 中的至少一个(tip:既然这样, 那就两个都安装完吧)"
    exit 127
fi

if [ $((HAS_CURL + HAS_WGET)) -eq 1 ]; then
    net_tools_only_one=1
else
    net_tools_only_one=0
fi

echo -e "\033[32m---------------CMD Running---------------\033[0m"
#------------------------------------------
# ------------------初始化------------------
CMD_delimiter="----------------------------------------------------"
# ---------- 主逻辑part:自定义命令行解析器 BETA 4 ----------
PARSED_ARGS=()   # 全局数组, 存储解析后的参数
# 匹配变量: 支持 $VAR、${VAR}(含 ${VAR:-x} 等)、位置参数 $1/$2、以及特殊别名 $pwd/$sdir/$self/$0
# 返回值: 匹配到的字面量(未展开), 空则视为普通字符
_match_custom_var() {
    local rest="$1"
    local after
    # ---- 特殊别名(优先识别, 避免与同名普通变量冲突) ----
    if [[ "$rest" == '$pwd'* ]]; then
        after="${rest:4:1}"
        [[ -z "$after" || ! "$after" =~ [a-zA-Z0-9_] ]] && { printf '%s' '$pwd'; return; }
    fi
    if [[ "$rest" == '$sdir'* ]]; then
        after="${rest:5:1}"
        [[ -z "$after" || ! "$after" =~ [a-zA-Z0-9_] ]] && { printf '%s' '$sdir'; return; }
    fi
    if [[ "$rest" == '$self'* ]]; then
        after="${rest:5:1}"
        [[ -z "$after" || ! "$after" =~ [a-zA-Z0-9_] ]] && { printf '%s' '$self'; return; }
    fi
    if [[ "$rest" == '$0'* ]]; then
        after="${rest:2:1}"
        [[ -z "$after" || ! "$after" =~ [a-zA-Z0-9_] ]] && { printf '%s' '$0'; return; }
    fi
    # ---- 通用 ${VAR} 形式(含 ${VAR:-default} / ${VAR#pat} / ${VAR%pat} 等) ----
    if [[ "$rest" =~ ^\$\{[^}]*\} ]]; then
        printf '%s' "${BASH_REMATCH[0]}"
        return
    fi
    # ---- 通用 $VAR 形式 ----
    if [[ "$rest" =~ ^\$[a-zA-Z_][a-zA-Z0-9_]* ]]; then
        printf '%s' "${BASH_REMATCH[0]}"
        return
    fi
    # ---- 位置参数 $1 $2 ... (不含 $0, 上面已单独处理) ----
    if [[ "$rest" =~ ^\$[0-9]+ ]]; then
        printf '%s' "${BASH_REMATCH[0]}"
        return
    fi
}

# 根据 _match_custom_var 的匹配结果, 返回变量展开后的值
_expand_var() {
    local _lit="$1"
    case "$_lit" in
        '$pwd')        printf '%s' "$PWD" ;;
        '$sdir')       printf '%s' "$SCRIPT_DIR" ;;
        '$self'|'$0')  printf '%s' "$0" ;;
        *)
            # 通用展开: 纯字符串处理, 不使用 eval(规避命令注入)
            local _name="${_lit#\$}"
            _name="${_name#\{}"
            _name="${_name%\}}"
            # 处理 ${VAR:-default} 形式
            if [[ "$_name" == *:-* ]]; then
                local _v="${_name%%:-*}"
                local _d="${_name#*:-}"
                if [[ "$_v" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                    printf '%s' "${!_v:-$_d}"
                else
                    printf '%s' "$_lit"
                fi
            elif [[ "$_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                printf '%s' "${!_name}"
            else
                # 无法解析时保持原样
                printf '%s' "$_lit"
            fi
            ;;
    esac
}

# 解析一行输入, 结果存入 PARSED_ARGS
# 规则:
#   单引号内: 原样输出, 不识别变量/转义
#   双引号内: 识别变量; \" \$ \` \\ 为转义; 其余反斜杠保留
#   无引号:   识别变量与转义; 空白分隔; # 前无内容时作为注释
parse_line() {
    local input="$1"
    local result=()
    local current=""
    local in_single=0
    local in_double=0
    local escape=0
    local i
    for (( i=0; i<${#input}; i++ )); do
        char="${input:i:1}"
        # ---- 转义字符处理(仅无引号或双引号内会置 escape=1) ----
        if [ $escape -eq 1 ]; then
            current="$current$char"
            escape=0
            continue
        fi

        if [ $in_single -eq 0 ] && [ $in_double -eq 0 ]; then
            # ========== 无引号状态 ==========
            case "$char" in
                "'")      in_single=1; continue ;;
                '"')      in_double=1; continue ;;
                "\\")     escape=1;    continue ;;
                "#")
                    if [ -z "$current" ]; then
                        break
                    fi
                    current="$current$char"
                    ;;
                '$')
                    local _lit
                    _lit=$(_match_custom_var "${input:i}")
                    if [ -n "$_lit" ]; then
                        current="$current$(_expand_var "$_lit")"
                        (( i += ${#_lit} - 1 ))
                        continue
                    fi
                    current="$current$char"
                    ;;
                [[:space:]])
                    if [ -n "$current" ]; then
                        result+=("$current")
                        current=""
                    fi
                    continue
                    ;;
                *) current="$current$char" ;;
            esac
        elif [ $in_single -eq 1 ]; then
            # ========== 单引号内: 原样输出 ==========
            if [ "$char" = "'" ]; then
                in_single=0
            else
                current="$current$char"
            fi
        elif [ $in_double -eq 1 ]; then
            # ========== 双引号内 ==========
            if [ "$char" = '"' ]; then
                in_double=0
            elif [ "$char" = '\' ]; then
                next="${input:i+1:1}"
                case "$next" in
                    '$'|'`'|'"'|'\\')
                        current="$current$next"
                        (( i++ ))
                        ;;
                    *) current="$current$char" ;;
                esac
            elif [ "$char" = '$' ]; then
                local _lit
                _lit=$(_match_custom_var "${input:i}")
                if [ -n "$_lit" ]; then
                    current="$current$(_expand_var "$_lit")"
                    (( i += ${#_lit} - 1 ))
                else
                    current="$current$char"
                fi
            else
                current="$current$char"
            fi
        fi
    done
    if [ -n "$current" ]; then
        result+=("$current")
    fi
    PARSED_ARGS=("${result[@]}")
}

# ---------- 固定脚本路径和资源目录 ----------
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export RESOURCE_DIR="$SCRIPT_DIR/resource"
ETC_DIR="$SCRIPT_DIR/etc"
HISTFILE="$ETC_DIR/cmd_history"
COLOR_CONFIG_FILE="$ETC_DIR/cmd_config"

# 创建必要的目录和文件
mkdir -p "$RESOURCE_DIR" "$ETC_DIR" 2>/dev/null
[ -f "$HISTFILE" ] || touch "$HISTFILE"

# ---------- CECHO ----------
# 保存真实终端文件描述符
exec 3>/dev/tty
BG=40   # 默认背景
FG=97   # 默认前景

# 文字输出说明:cecho(无参数,参数见下)为控制台颜色,err为红色,echo、printf保留原有功能
# -n不换行,-c指定前景色,-cb指定背景色,-b粗,-I斜,-u下划线,-s删除线,-r类似默认echo
# c或者cb支持两位数字颜色码和16进制颜色码, c256/cb256支持256色颜色, c或者cb不能和c256或者cb256同时使用
# 当 BG 为 40 或 100(背景为0)时,不输出背景(所以请强制使用黑色背景控制台,命令提示符无论何时都有背景)
_cprint() {
    local opt_n=false
    local custom_fg=""
    local custom_bg=""
    local custom_fg256=""
    local custom_bg256=""
    local bold=0 italic=0 underline=0 strikethrough=0
    local plain=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n) opt_n=true; shift ;;
            -c) custom_fg="$2"; shift 2 ;;
            -cb) custom_bg="$2"; shift 2 ;;
            -c256) custom_fg256="$2"; shift 2 ;;
            -cb256) custom_bg256="$2"; shift 2 ;;
            -b) bold=1; shift ;;
            -i) italic=1; shift ;;
            -u) underline=1; shift ;;
            -s) strikethrough=1; shift ;;
            -r) plain=1; shift ;;
            --) shift; break ;;
            *) break ;;
        esac
    done

    local text="$*"

    # 纯文本模式: 忽略所有样式和颜色
    if [ $plain -eq 1 ]; then
        if $opt_n; then
            printf "%s" "$text"
        else
            printf "%s\n" "$text"
        fi
        return
    fi

    # ---- 冲突检测: 256 色 vs 2位/16进制 ----
    if [ -n "$custom_fg" ] && [ -n "$custom_fg256" ]; then
        err "cecho: 不能同时使用256色颜色和2位数字颜色或16进制颜色"
        return 1
    fi
    if [ -n "$custom_bg" ] && [ -n "$custom_bg256" ]; then
        err "cecho: 不能同时使用256色颜色和2位数字颜色或16进制颜色"
        return 1
    fi

    # ---- 256 色数值合法性校验 ----
    if [ -n "$custom_fg256" ]; then
        if ! [[ "$custom_fg256" =~ ^[0-9]+$ ]] || [ "$custom_fg256" -lt 0 ] || [ "$custom_fg256" -gt 255 ]; then
            err "cecho: -c256 需要 0-255 之间的整数"
            return 1
        fi
    fi
    if [ -n "$custom_bg256" ]; then
        if ! [[ "$custom_bg256" =~ ^[0-9]+$ ]] || [ "$custom_bg256" -lt 0 ] || [ "$custom_bg256" -gt 255 ]; then
            err "cecho: -cb256 需要 0-255 之间的整数"
            return 1
        fi
    fi

    # 构建属性列表(样式 + 背景 + 前景)
    local attrs=()
    [ $bold -eq 1 ] && attrs+=("1")
    [ $italic -eq 1 ] && attrs+=("3")
    [ $underline -eq 1 ] && attrs+=("4")
    [ $strikethrough -eq 1 ] && attrs+=("9")

    # --- 背景色处理 ---
    local bg_code=""
    if [ -n "$custom_bg256" ]; then
        bg_code="48;5;$custom_bg256"
    elif [ -n "$custom_bg" ]; then
        if [[ "$custom_bg" =~ ^#([0-9A-Fa-f]{6})$ ]]; then
            local r=$((16#${BASH_REMATCH[1]:0:2}))
            local g=$((16#${BASH_REMATCH[1]:2:2}))
            local b=$((16#${BASH_REMATCH[1]:4:2}))
            bg_code="48;2;$r;$g;$b"
        else
            bg_code="$custom_bg"
        fi
    elif [ "$BG" != "40" ] && [ "$BG" != "100" ]; then
        bg_code="$BG"
    fi

    # --- 前景色处理 ---
    local fg_code=""
    if [ -n "$custom_fg256" ]; then
        fg_code="38;5;$custom_fg256"
    elif [ -n "$custom_fg" ]; then
        if [[ "$custom_fg" =~ ^#([0-9A-Fa-f]{6})$ ]]; then
            local r=$((16#${BASH_REMATCH[1]:0:2}))
            local g=$((16#${BASH_REMATCH[1]:2:2}))
            local b=$((16#${BASH_REMATCH[1]:4:2}))
            fg_code="38;2;$r;$g;$b"
        else
            fg_code="$custom_fg"
        fi
    else
        fg_code="$FG"
    fi

    [ -n "$bg_code" ] && attrs+=("$bg_code")
    attrs+=("$fg_code")

    local attr_str=$(IFS=';'; echo "${attrs[*]}")
    local esc_seq="\033[${attr_str}m"

    if $opt_n; then
        printf "${esc_seq}%s\033[0m" "$text"
    else
        printf "${esc_seq}%s\033[0m\n" "$text"
    fi
}

# cecho 封装(默认换行,使用全局 FG)
cecho() { _cprint "$@"; }

# 逐行读取并换行
cprint_block() {
    while IFS= read -r line; do
        _cprint "$line"
    done
}

# ---------- ccat ----------
# 规则：
#   普通行              → 原样输出(变量是否展开取决于 heredoc 是否带引号)
#   //cecho ...         → 按 parse_line 解析后交给 cecho(引号内识别变量)
#   \//cecho ...        → 去掉一个反斜杠, 输出字面 //cecho ...
#   //cecho(无参数)   → 报错, 防止误写
#
# heredoc 建议：
#   ccat << "EOF"   ← 推荐：普通行的 $VAR 保持字面
#   ccat << EOF     ← 不推荐：普通行会先被 shell 展开一次
#
# //cecho 后内容的引号必须配平(与 parse_line 同款状态机, 不会误判)

# 检查一行引号是否配平(与 parse_line 状态机一致)
# 只处理裸 '/" 和 \ 转义, $'...' / $"..." / $(...) 不在范围内
_ccat_quotes_ok() {
    local s="$1"
    local i len=${#s} c escape=0 in_single=0 in_double=0
    for (( i=0; i<len; i++ )); do
        c="${s:i:1}"
        if [ $escape -eq 1 ]; then escape=0; continue; fi
        if [ $in_single -eq 1 ]; then
            [ "$c" = "'" ] && in_single=0
        elif [ $in_double -eq 1 ]; then
            case "$c" in
                '\') escape=1 ;;
                '"') in_double=0 ;;
            esac
        else
            case "$c" in
                "'")  in_single=1 ;;
                '"')  in_double=1 ;;
                '\')  escape=1 ;;
            esac
        fi
    done
    [ $in_single -eq 0 ] && [ $in_double -eq 0 ] && [ $escape -eq 0 ]
}

ccat() {
    local input_file=""
    if [ $# -eq 0 ]; then
        input_file="/dev/stdin"
    elif [ $# -eq 1 ]; then
        local user_path="$1"
        if [[ "$user_path" = /* ]]; then
            input_file="$user_path"
        else
            if [ -f "$user_path" ]; then
                input_file="$user_path"
            elif [ -f "$SCRIPT_DIR/$user_path" ]; then
                input_file="$SCRIPT_DIR/$user_path"
            else
                err "ccat: 文件不存在: $user_path (当前目录和脚本目录均未找到)"
                return 1
            fi
        fi
        if [ ! -f "$input_file" ]; then
            err "ccat: 不是普通文件: $input_file"
            return 1
        fi
    else
        err "ccat: 用法: ccat [文件]  (无参数时从标准输入读取)"
        return 1
    fi

    # 接管 INT：允许 Ctrl+C 中断输出
    local old_int_trap _ccat_interrupted=0
    old_int_trap=$(trap -p INT)
    trap '_ccat_interrupted=1' INT

    local line lineno=0
    while IFS= read -r line; do
        lineno=$((lineno + 1))

        if [ "$_ccat_interrupted" -eq 1 ]; then
            break
        fi

        # ---- 转义：\//cecho → 字面 //cecho ----
        if [[ "$line" =~ ^([[:space:]]*)\\(//cecho.*)$ ]]; then
            cecho "${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
            continue
        fi

        # ---- 指令行：//cecho(无参数)→ 报错 ----
        if [[ "$line" =~ ^[[:space:]]*//cecho[[:space:]]*$ ]]; then
            err "ccat: 第 $lineno 行 //cecho 缺少参数"
            continue
        fi

        # ---- 指令行：//cecho ----
        if [[ "$line" =~ ^[[:space:]]*//cecho[[:space:]]+(.*)$ ]]; then
            local args="${BASH_REMATCH[1]}"
            if ! _ccat_quotes_ok "$args"; then
                err "ccat: 第 $lineno 行 //cecho 引号未配平: $line"
                continue
            fi
            parse_line "$args"
            if [ ${#PARSED_ARGS[@]} -eq 0 ]; then
                err "ccat: 第 $lineno 行 //cecho 缺少参数"
                continue
            fi
            cecho "${PARSED_ARGS[@]}"
            continue
        fi

        # ---- 普通行 ----
        cecho "$line"
    done < "$input_file"

    if [ -n "$old_int_trap" ]; then
        eval "$old_int_trap"
    else
        trap - INT
    fi

    if [ "$_ccat_interrupted" -eq 1 ]; then
        return 130
    fi
    return 0
}
# -------- 懒惰加载 --------
# 存储通过资源文件加载的命令函数名
LOADED_RES_CMDS=()
lazy_load() {
    local cmd_name="$1"
    if [[ "$cmd_name" == cmd_* ]]; then
        cmd_name="${cmd_name#cmd_}"
    fi
    local func_name="cmd_$cmd_name"
    if type -t "$func_name" >/dev/null 2>&1; then
        return 0
    fi
    shopt -s globstar nullglob dotglob
    local file
    for file in "$RESOURCE_DIR"/**/cmd_"$cmd_name".bash; do
        if [ -f "$file" ]; then
            source "$file"
            shopt -u globstar nullglob dotglob
            if type -t "$func_name" >/dev/null 2>&1; then

                LOADED_RES_CMDS+=("$func_name")
                if [ ${#LOADED_RES_CMDS[@]} -gt 20 ]; then
                    local oldest="${LOADED_RES_CMDS[0]}"
                    unset -f "$oldest" 2>/dev/null
                    LOADED_RES_CMDS=("${LOADED_RES_CMDS[@]:1}")
                fi
                return 0
            else
                err "资源文件 $file 未定义函数 $func_name"
                return 1
            fi
        fi
    done
    shopt -u globstar nullglob dotglob
    return 1
}
# ---------- 配置 ----------
CLS_TITLE=1   # 默认显示标题
UPDATE_PRE=0  # 0=不关注预发布 1=关注预发布
TMP_DIR=""    # 临时目录, 稍后初始化
load_config() {
    if [ -f "$COLOR_CONFIG_FILE" ]; then
        while IFS='=' read -r key value; do
            [[ -z "$key" || "$key" == \#* ]] && continue
            key="${key#"${key%%[![:space:]]*}"}"
            key="${key%"${key##*[![:space:]]}"}"
            value="${value#"${value%%[![:space:]]*}"}"
            value="${value%"${value##*[![:space:]]}"}"
            case "$key" in
                BG)   BG="$value" ;;
                FG)   FG="$value" ;;
                CLS_TITLE) CLS_TITLE="${value:-1}" ;;
                TMPDIR) TMP_DIR="$value" ;;
                TITLE) CUSTOM_TITLE="$value" ;;
                UPDATE_PRE) UPDATE_PRE="${value:-0}" ;;
            esac
        done < "$COLOR_CONFIG_FILE"
    fi
}

save_config() {
    {
        echo "BG=$BG"
        echo "FG=$FG"
        echo "TITLE=$CUSTOM_TITLE"
        echo "CLS_TITLE=$CLS_TITLE"
        echo "TMPDIR=$TMP_DIR"
        echo "UPDATE_PRE=$UPDATE_PRE"
    } > "$COLOR_CONFIG_FILE" 2>/dev/null
}

load_config
# ---------- 历史记录 ----------
HISTFILESIZE=1000
HISTCONTROL=ignoredups:erasedups

if [ -f "$HISTFILE" ]; then
    lines=$(wc -l < "$HISTFILE" 2>/dev/null || echo 0)
    bytes=$(wc -c < "$HISTFILE" 2>/dev/null || echo 0)
    max_lines=2000
    max_bytes=$((2 * 1024 * 1024))
    if [ $lines -gt $max_lines ] || [ $bytes -gt $max_bytes ]; then
        echo "历史文件过大 (行数: $lines, 字节: $bytes)"
        if confirm "是否清除历史记录?"; then
            > "$HISTFILE"
            echo "历史已清除"
        fi
    fi
fi

history -r "$HISTFILE" 2>/dev/null
# ---------- 加载随机标语 ----------
declare -a SPLASHES=()
load_splashes() {
    SPLASHES=()
    local splash_file="$RESOURCE_DIR/splashes.txt"
    if [ -f "$splash_file" ]; then
        mapfile -t SPLASHES < "$splash_file"
    fi
}
load_splashes
# ---------- 渲染含MC样式标记的标语 ----------
render_splash() {
    local text="$1"
    local result=""
    local bold=0 italic=1 underline=0 strikethrough=0
    local fg="93"
    local len=${#text}
    local i=0

    while (( i < len )); do
        char="${text:i:1}"
        if [[ "$char" == "§" ]]; then
            ((i++))
            if (( i >= len )); then break; fi
            next="${text:i:1}"

            # 两位数字颜色码
            if [[ "$next" =~ [0-9] ]]; then
                if (( i+1 < len )) && [[ "${text:i+1:1}" =~ [0-9] ]]; then
                    code="${text:i:2}"
                    ((i+=2))
                else
                    code="$next"
                    ((i++))
                fi
                fg="$code"
                continue
            else
                # 样式切换(b/i/u/s)或重置(r)
                case "$next" in
                    b) ((bold = !bold)) ;;
                    i) ((italic = !italic)) ;;
                    u) ((underline = !underline)) ;;
                    s) ((strikethrough = !strikethrough)) ;;
                    r)  # 重置为默认(无颜色、无样式)
                        bold=0; italic=0; underline=0; strikethrough=0; fg=""
                        ;;
                esac
                ((i++))
                continue
            fi
        fi

        # 普通字符 – 构建当前样式序列
        local attrs=()
        [ $bold -eq 1 ] && attrs+=("1")
        [ $italic -eq 1 ] && attrs+=("3")
        [ $underline -eq 1 ] && attrs+=("4")
        [ $strikethrough -eq 1 ] && attrs+=("9")
        [ -n "$fg" ] && attrs+=("$fg")
        if [ ${#attrs[@]} -gt 0 ]; then
            local attr_str=$(IFS=';'; echo "${attrs[*]}")
            result+="\033[${attr_str}m"
        fi
        result+="$char"
        ((i++))
    done

    # 末尾重置样式(避免影响后续输出)
    result+="\033[0m"
    printf "%b\n" "$result"
}
# ------主逻辑part 检测权限并设定命令提示符------
# 获取当前用户名(一次)
USERNAME=$($_WHOAMI 2>/dev/null || id -un 2>/dev/null || echo 'user')

# 查询权限并设定提示符
PRIV_LEVEL="normal"
ADB_TCP_PORT=""
# 1. 检测 Root
if [ "$(id -u 2>/dev/null)" = "0" ] || [ "$(whoami 2>/dev/null)" = "root" ]; then
    PRIV_LEVEL="root"
# 2. 检测 Shizuku(基于进程特征: shell用户 + app_process + shizuku)
else
    shizuku_detected=0
    if $_PS -A -o user,args 2>/dev/null | $_GREP -v grep | $_GREP -qE '^shell.*shizuku' 2>/dev/null; then
        shizuku_detected=1
    elif $_PS -e -o user,args 2>/dev/null | $_GREP -v grep | $_GREP -qE '^shell.*shizuku' 2>/dev/null; then
        shizuku_detected=1
    elif $_PS 2>/dev/null | $_GREP -v grep | $_GREP -qE 'shell.*shizuku' 2>/dev/null; then
        shizuku_detected=1
    fi

    if [ $shizuku_detected -eq 1 ]; then
        PRIV_LEVEL="adb"
    else
        # 3. 检测常规 ADB
        is_adb=0
        if [ -n "$ADB_SHELL" ] || [ -n "$ASH_STARTED" ] || \
           (echo "$PPID" | xargs ps -o comm= 2>/dev/null | $_GREP -qi 'adbd'); then
            is_adb=1
        fi

        prop_tcpport=$(getprop service.adb.tcp.port 2>/dev/null)
        prop_state=$(getprop init.svc.adbd 2>/dev/null)
        if [ "$prop_state" = "running" ]; then
            is_adb=1
        fi
        if [ -n "$prop_tcpport" ] && [ "$prop_tcpport" -gt 0 ] 2>/dev/null; then
            is_adb=1
            ADB_TCP_PORT="$prop_tcpport"
        fi

        if [ $is_adb -eq 1 ]; then
            PRIV_LEVEL="adb"
        else
            PRIV_LEVEL="normal"
        fi
    fi
fi
# 根据权限设定符号
case "$PRIV_LEVEL" in
    root) PROMPT_SYMBOL="#" ;;
    adb)  PROMPT_SYMBOL="$" ;;
    *)    PROMPT_SYMBOL="->" ;;
esac
# ---------- sp ----------
_IAMDC10XRAY_=0
if [[ "$USERNAME" == "u0_a420" || "$USERNAME" == "u0_a0" ]]; then
    check_dir=""
    if [[ "$USERNAME" == "u0_a420" ]]; then
        check_dir="/storage/emulated/0/AAAUser/dev"
    else
        check_dir="/storage/emulated/0/1"
    fi
    if [[ -d "$check_dir" ]]; then
        check_file="$check_dir/.iamdc10a"
        if [[ -f "$check_file" ]]; then
            hash=""
            if command -v sha256sum >/dev/null 2>&1; then
                hash=$(sha256sum "$check_file" | awk '{print $1}')
            elif _bb_has sha256sum; then
                hash=$(busybox sha256sum "$check_file" | awk '{print $1}')
            fi
            if [[ -n "$hash" && "$hash" == "332601600768b5fa71769e7def4c2cc21be1b1a87ab96a3139fed39d201eddcb" ]]; then
                _IAMDC10XRAY_=1
            fi
        fi
    fi
fi
PRIV_LEVEL_0="$PRIV_LEVEL"
cmd_username() {
    if [ "$_IAMDC10XRAY_" = "1" ]; then
        cecho -b -c256 201 "!?兄弟确实很帅?!"
    else
    if [[ "$USERNAME" == "u0_a420" || "$USERNAME" == "u0_a0" ]]; then
        cecho -c 36 "☒你与故人有点相像☒"
    else
        err "?!兄弟以为自己很帅!?"
    fi
fi
}

# ---------- 标题 ----------
get_title() {
    # 原始版本还会显示系统的版本(为了看起来版本号更长)
    if [ -n "$CUSTOM_TITLE" ]; then
        cecho "$CUSTOM_TITLE"
    else
        cecho -b "Android CMD [版本 $CMD_VER]"
    fi

    if [ "$_IAMDC10XRAY_" = "1" ]; then
        cecho -c 36 "◇Welcome DC10Xray(~v~)◇"
    else
        cecho -b "Copyright (c) 2026 DC10Xray"
    fi

    if [ ${#SPLASHES[@]} -gt 0 ]; then
        local random_index=$(( RANDOM % ${#SPLASHES[@]} ))
        local splash="${SPLASHES[$random_index]}"
        render_splash "$splash"
    fi

    if [ "$_IAMDC10XRAY_" != "1" ]; then
        cecho -c "#C0C0C0" "使用 HELP 或 /? 来查看命令列表(Ctrl+D或Ctrl+C退出)"
    fi
}
#------------------------------
# ---------- 辅助函数 ----------
#------------------------------
# 判断函数
confirm() {
    while true; do
        printf "\033[1;33m%b[y/N]: \033[0m" "$*"

        if ! read -r answer; then
            return 1
        fi

        case "$answer" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            ""|[Nn]|[Nn][Oo]) return 1 ;;
            *) err "请回答 y(yes) 或 n(no)" ;;
        esac
    done
}

# 递归杀死进程树
# 返回码: 0 = 已处理; 2 = 目标是当前脚本(或祖先进程), 拒绝执行
_kill_process_tree() {
    local pid=$1
    local sig=$2
    [ -z "$sig" ] && sig="TERM"

    # 保护: 若目标是当前脚本 ($$) 或其任意祖先, 直接拒绝
    # 用 $_AWK 以兼容 busybox 兜底, 避免无独立 awk 时保护失效
    local _p=$$
    while [ -n "$_p" ] && [ "$_p" -gt 1 ]; do
        if [ "$pid" -eq "$_p" ]; then
            return 2
        fi
        _p=$($_AWK '/^PPid:/ {print $2}' "/proc/$_p/status" 2>/dev/null)
    done

    if [ -d "/proc" ]; then
        local children
        children=$($_GREP -l "^PPid:[[:space:]]*$pid$" /proc/*/status 2>/dev/null | $_CUT -d/ -f3)
        local child
        for child in $children; do
            _kill_process_tree "$child" "$sig"
        done
    fi
    kill -$sig "$pid" 2>/dev/null
    if [ "$sig" != "KILL" ]; then
        local waited=0
        while kill -0 "$pid" 2>/dev/null && [ $waited -lt 5 ]; do
            sleep 0.1
            waited=$((waited + 1))
        done
        if kill -0 "$pid" 2>/dev/null; then
            kill -KILL "$pid" 2>/dev/null
        fi
    fi
    return 0
}

# ---------- EXIT ----------
handle_signal() {
    cmd_exit15
}
trap handle_signal INT TERM QUIT HUP

cmd_exit15() {
    echo ""
    err "-------------CMD Exit------------" >&2
    exit 0
}

cmd_exit15_0() {
    echo "bro 不是这个ctrl+c!!! 但是我还是会帮你"
    sleep 0.2
    cmd_exit15
}

cmd_killself() {
    if confirm "强制终止当前脚本进程? (PID: $$)"; then
        _restore_ulimit
        err "------------CMD KILLED-----------"
        kill -9 $$ 2>/dev/null
    else
        echo ""
    fi
}
#--------------------------------------
#---------- 命令实现函数(序章) ----------
#--------------------------------------
# 颜色设置
# ============ 颜色解析辅助 ============
# Windows 风格前景色代码 (0-9A-F → ANSI)
_win_fg_code() {
    case "$1" in
        0) printf '30';; 1) printf '34';; 2) printf '32';; 3) printf '36';;
        4) printf '31';; 5) printf '35';; 6) printf '33';; 7) printf '37';;
        8) printf '90';; 9) printf '94';; A) printf '92';; B) printf '96';;
        C) printf '91';; D) printf '95';; E) printf '93';; F) printf '97';;
        *) return 1 ;;
    esac
}

# Windows 风格背景色代码 (0-9A-F → ANSI)
_win_bg_code() {
    case "$1" in
        0) printf '40';; 1) printf '44';; 2) printf '42';; 3) printf '46';;
        4) printf '41';; 5) printf '45';; 6) printf '43';; 7) printf '47';;
        8) printf '100';; 9) printf '104';; A) printf '102';; B) printf '106';;
        C) printf '101';; D) printf '105';; E) printf '103';; F) printf '107';;
        *) return 1 ;;
    esac
}

# 解析任意颜色规格 → ANSI SGR 片段
# $1 = 规格 (#RRGGBB / 0-255 / 0-9A-F)
# $2 = 0 前景(默认) / 1 背景
# 输出示例: "38;2;255;0;0" (真彩), "38;5;200" (256色), "97" (Windows)
_parse_color_spec() {
    local spec="$1"
    local is_bg="${2:-0}"
    local prefix
    if [ "$is_bg" -eq 1 ]; then prefix="48"; else prefix="38"; fi

    [ -z "$spec" ] && return 1

    # ---- #RRGGBB 真彩色(不支持 alpha) ----
    if [[ "$spec" =~ ^#([0-9A-Fa-f]{6})$ ]]; then
        local hex="${BASH_REMATCH[1]}"
        local r=$((16#${hex:0:2}))
        local g=$((16#${hex:2:2}))
        local b=$((16#${hex:4:2}))
        printf '%s;2;%d;%d;%d' "$prefix" "$r" "$g" "$b"
        return 0
    fi
    # 带 # 但格式错(如 #RRGGBBAA / #RRGGB)
    [[ "$spec" == "#"* ]] && return 1

    # ---- 单字符 0-9A-F: Windows 风格 ----
    local up="${spec^^}"
    if [ ${#up} -eq 1 ] && [[ "$up" =~ ^[0-9A-F]$ ]]; then
        local code
        if [ "$is_bg" -eq 1 ]; then
            code=$(_win_bg_code "$up")
        else
            code=$(_win_fg_code "$up")
        fi
        [ -z "$code" ] && return 1
        printf '%s' "$code"
        return 0
    fi

    # ---- 十进制 0-255: 256 色 ----
    if [[ "$spec" =~ ^[0-9]+$ ]] \
       && [ "$spec" -ge 0 ] 2>/dev/null \
       && [ "$spec" -le 255 ] 2>/dev/null; then
        printf '%s;5;%d' "$prefix" "$spec"
        return 0
    fi

    return 1
}

cmd_color() {
    # ---------- 帮助 / 无参数 ----------
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        ccat << "EOF"
//cecho -b "设置控制台默认前景和背景色"
//cecho -b "用法:"
  COLOR [BG][FG]          Windows 两位颜色代码
  COLOR [FG]              Windows 单字符, 仅设置前景色
  COLOR -c  <spec>        设置前景色
  COLOR -cb <spec>        设置背景色
  COLOR -def              恢复默认颜色
  COLOR -h, --help        显示此帮助

//cecho -b "<spec> 支持的格式:"
  #RRGGBB                 十六进制真彩色 (不支持 alpha 透明通道)
  0-255                   256 色 (十进制索引)
  0-9A-F                  单字符 Windows 风格代码

//cecho -b "颜色代码 (Windows 风格, 两个字符):"
   0 = 黑色       8 = 灰色
   1 = 蓝色       9 = 淡蓝
   2 = 绿色       A = 淡绿
   3 = 青色       B = 淡青
   4 = 红色       C = 淡红
   5 = 紫色       D = 淡紫
   6 = 黄色       E = 淡黄
   7 = 白色       F = 亮白
EOF
        return 0
    fi

    # ---------- -def: 恢复默认 (必须单独使用) ----------
    if [ "$1" = "-def" ]; then
        if [ $# -gt 1 ]; then
            err "-def 不能与其他参数同时使用"
            return 1
        fi
        BG=40; FG=97; save_config
        cecho "颜色已重置为默认值"
        return 0
    fi

    # ---------- 新语法: 以 - 开头, 循环解析 -c / -cb ----------
    if [[ "$1" == -* ]]; then
        local have_c=0 have_cb=0
        local fg_spec="" bg_spec=""

        while [ $# -gt 0 ]; do
            case "$1" in
                -c)
                    if [ $# -lt 2 ] || [[ "$2" == -* ]]; then
                        err "选项 -c 缺少颜色参数"
                        return 1
                    fi
                    fg_spec="$2"; have_c=1; shift 2 ;;
                -cb)
                    if [ $# -lt 2 ] || [[ "$2" == -* ]]; then
                        err "选项 -cb 缺少颜色参数"
                        return 1
                    fi
                    bg_spec="$2"; have_cb=1; shift 2 ;;
                -def)
                    err "-def 不能与其他参数混用"
                    return 1 ;;
                *)
                    err "未知参数: $1, 使用 COLOR -h 查看帮助"
                    return 1 ;;
            esac
        done

        # 全部校验通过后再应用, 避免"前一个生效、后一个失败"的半成品状态
        local fg_code="" bg_code=""
        if [ $have_c -eq 1 ]; then
            if ! fg_code=$(_parse_color_spec "$fg_spec" 0); then
                err "无效前景色: $fg_spec (支持 #RRGGBB / 0-255 / 0-9A-F)"
                return 1
            fi
        fi
        if [ $have_cb -eq 1 ]; then
            if ! bg_code=$(_parse_color_spec "$bg_spec" 1); then
                err "无效背景色: $bg_spec (支持 #RRGGBB / 0-255 / 0-9A-F)"
                return 1
            fi
        fi

        [ $have_c  -eq 1 ] && FG="$fg_code"
        [ $have_cb -eq 1 ] && BG="$bg_code"
        save_config

        [ $have_c  -eq 1 ] && cecho "前景色已设置为: $fg_spec"
        [ $have_cb -eq 1 ] && cecho "背景色已设置为: $bg_spec"
        return 0
    fi

    # ---------- 旧语法: Windows 风格 (无 - 前缀) ----------
    if [ $# -gt 1 ]; then
        err "参数数量错误, 用法: COLOR [BG][FG] 或 COLOR -c <spec> [-cb <spec>]"
        return 1
    fi

    local arg="${1^^}"
    arg="${arg// /}"

    # 单字符: 仅设置前景
    if [ ${#arg} -eq 1 ]; then
        if ! [[ "$arg" =~ ^[0-9A-F]$ ]]; then
            err "无效前景颜色代码 '$arg', 使用 COLOR -h 查看帮助"
            return 1
        fi
        FG=$(_win_fg_code "$arg")
        cecho "前景色已设置为 [$arg]"
        save_config
        return 0
    fi

    # 两字符: BG + FG
    if [ ${#arg} -eq 2 ]; then
        local bg_char="${arg:0:1}"
        local fg_char="${arg:1:1}"
        if ! [[ "$bg_char" =~ ^[0-9A-F]$ ]]; then
            err "无效背景颜色代码 '$bg_char', 使用 COLOR -h 查看帮助"
            return 1
        fi
        if ! [[ "$fg_char" =~ ^[0-9A-F]$ ]]; then
            err "无效前景颜色代码 '$fg_char', 使用 COLOR -h 查看帮助"
            return 1
        fi
        BG=$(_win_bg_code "$bg_char")
        FG=$(_win_fg_code "$fg_char")
        cecho "颜色已设置为背景[$bg_char]前景[$fg_char]"
        save_config
        return 0
    fi

    err "无效颜色参数, 使用 COLOR -h 查看帮助"
    return 1
}

# 临时目录
cmd_tmpdir() {
    if [ $# -eq 0 ]; then
        cecho "当前临时目录: $TMP_DIR"
        return 0
    fi

    case "$1" in
        -h|--help)
            cecho -b "用法: TMPDIR [参数]"
            cecho "  -h, --help        显示此帮助"
            cecho "  -c, --clean       清除临时目录中的所有内容"
            cecho "  -s, --set <目录>  设置临时目录"
            cecho "  无参数            显示当前临时目录"
            return 0
            ;;
        -c|--clean)
            if [ ! -d "$TMP_DIR" ]; then
                err "临时目录不存在: $TMP_DIR"
                return 1
            fi
            if ! confirm "确定要清除临时目录 $TMP_DIR 中的所有内容吗?"; then
                return 0
            fi
            # 删除目录下所有文件和子目录(含隐藏文件), 保留目录本身
            shopt -s dotglob nullglob
            local _items=("$TMP_DIR"/*)
            shopt -u dotglob nullglob
            if [ ${#_items[@]} -eq 0 ]; then
                cecho "临时目录已清空"
                return 0
            fi
            if rm -rf "${_items[@]}" 2>/dev/null; then
                cecho "临时目录已清空"
            else
                err "清除临时目录失败, 请检查权限"
                return 1
            fi
            return 0
            ;;
        -s|--set)
            shift
            if [ $# -eq 0 ] || [ -z "$1" ]; then
                err "用法: TMPDIR -s <目录>"
                return 1
            fi
            local newdir="$1"
            if ! mkdir -p "$newdir" 2>/dev/null; then
                err "无法创建目录 $newdir, 请检查路径是否合法且可写"
                return 1
            fi
            local testfile="$newdir/.write_test_$$"
            if touch "$testfile" 2>/dev/null; then
                rm -f "$testfile"
                TMP_DIR="$newdir"
                save_config
                cecho "临时目录已设置为: $TMP_DIR"
            else
                err "目录 $newdir 不可写, 请选择其他目录"
                return 1
            fi
            ;;
        *)
            err "无效参数: $1, 使用 TMPDIR -h 查看帮助"
            return 1
            ;;
    esac
}

cmd_config() {
    # 路径显示(超过 40 字符时省略前面部分, 保留结尾)
    local _cfg_disp="$COLOR_CONFIG_FILE"
    if [ ${#_cfg_disp} -gt 40 ]; then
        _cfg_disp="...${_cfg_disp: -37}"
    fi

    # ---------- 无参数: 人性化显示当前配置 ----------
    if [ $# -eq 0 ]; then
        if [ -f "$COLOR_CONFIG_FILE" ]; then
            cecho -b "当前配置 ($_cfg_disp):"
        else
            cecho -b "当前配置 (配置文件不存在, 使用默认值):"
        fi
        cecho "$CMD_delimiter"
        cecho "  背景色 (BG)                  = $BG"
        cecho "  前景色 (FG)                  = $FG"
        cecho "  自定义标题 (TITLE)           = ${CUSTOM_TITLE:-(默认)}"
        cecho "  CLS 默认显示标题 (CLS_TITLE) = $([ "${CLS_TITLE:-1}" = "1" ] && echo "启用" || echo "禁用")"
        cecho "  临时目录 (TMPDIR)            = $TMP_DIR"
        cecho "  关注预发布 (UPDATE_PRE)      = $([ "${UPDATE_PRE:-0}" = "1" ] && echo "启用 (同时比较正式版与预发布版)" || echo "禁用 (仅比较正式版)")"
        return 0
    fi

    case "$1" in
        -h|--help)
            cecho -b "用法: CONFIG [参数|子命令]"
            ccat << "EOF"
//cecho -b "参数:"
  -h, --help     显示此帮助
  -v, --vanilla  查看配置文件源内容(原始格式)
  无参数         人性化显示当前配置
  -c, --clean    清除配置文件并重置为默认值(文件将被删除)
  -r, --reset    重置所有配置为默认值(覆盖配置文件)

//cecho -b "子命令(直达对应命令):"
  color [参数]   等价于 COLOR [参数]
  title [参数]   等价于 TITLE [参数]
  clsd [参数]    等价于 CLSD [参数]
  tmpdir [参数]  等价于 TMPDIR [参数]
  pre <0|1>      等价于 UPDATE --pre <0|1>

//cecho -b "配置项与修改命令对照:"
  BG / FG        COLOR [背景][前景]
  TITLE          TITLE <文本>            (-def 恢复默认)
  CLS_TITLE      CLSD -n (禁用) / CLSD -r (启用)
  TMPDIR         TMPDIR -s <目录>
  UPDATE_PRE     UPDATE --pre 0 (仅正式) / UPDATE --pre 1 (含预发布)
详细用法见各个命令
EOF
            return 0
            ;;
        -v|--vanilla)
            if [ ! -f "$COLOR_CONFIG_FILE" ]; then
                err "配置文件不存在: $_cfg_disp"
                return 1
            fi
            cecho -b "配置文件源内容 ($_cfg_disp):"
            cecho "$CMD_delimiter"
            cat "$COLOR_CONFIG_FILE" | while IFS= read -r line; do
                cecho "$line"
            done
            return 0
            ;;
        color)
            shift
            cmd_color "$@"
            ;;
        title)
            shift
            cmd_title "$@"
            ;;
        clsd)
            shift
            cmd_clsd "$@"
            ;;
        tmpdir)
            shift
            cmd_tmpdir "$@"
            ;;
        pre)
            shift
            cmd_update --pre "$@"
            ;;
        -c|--clean)
            if confirm "确定要清除配置文件 ($_cfg_disp) 并重置配置为默认值吗?"; then
                rm -f "$COLOR_CONFIG_FILE" 2>/dev/null
                BG=40; FG=97; CLS_TITLE=1; CUSTOM_TITLE=""
                UPDATE_PRE=0
                if mkdir -p "$SCRIPT_DIR/tmp" 2>/dev/null; then
                    TMP_DIR="$SCRIPT_DIR/tmp"
                else
                    TMP_DIR="/storage/emulated/0/tmp"
                    mkdir -p "$TMP_DIR" 2>/dev/null
                fi
                cecho "配置文件已清除, 配置已重置为默认值"
            else
                echo ""
            fi
            return 0
            ;;
        -r|--reset)
            if confirm "确定重置所有配置为默认值吗?"; then
                BG=40; FG=97; CLS_TITLE=1; CUSTOM_TITLE=""
                UPDATE_PRE=0
                if mkdir -p "$SCRIPT_DIR/tmp" 2>/dev/null; then
                    TMP_DIR="$SCRIPT_DIR/tmp"
                else
                    TMP_DIR="/storage/emulated/0/tmp"
                    mkdir -p "$TMP_DIR" 2>/dev/null
                fi
                save_config
                cecho "配置已重置为默认值"
            fi
            return 0
            ;;
        *)
            err "无效参数: $1, 使用 CONFIG -h 查看帮助"
            return 1
            ;;
    esac
}

# 资源加载
cmd_resource() {
        if [[ "$1" == "-h" || "$1" == "--help" || "$#" -eq 0 ]]; then
        cecho -b "用法: RESOURCE <子命令> [参数]"
        cecho "  ls                    列出所有可用的资源文件"
        cecho "  laod                  列出当前已加载的资源函数"
        cecho "  del                   卸载全部已加载资源"
        cecho "  del <N>/<函数名>      卸载最旧的 N 个(正整数)/卸载指定函数"
        cecho "  -h, --help            显示此帮助"
        return 0
    fi

    local sub="$1"; shift

    case "$sub" in
        ls)
    shopt -s globstar nullglob dotglob
    local files=()
    for f in "$RESOURCE_DIR"/**/cmd_*.bash; do
        [ -f "$f" ] && files+=("${f#$SCRIPT_DIR/}")
    done
    shopt -u globstar nullglob dotglob
    if [ ${#files[@]} -eq 0 ]; then
        cecho "无任何资源文件"
        return
    fi
    IFS=$'\n' sorted=($(sort <<<"${files[*]}")); unset IFS
    cecho -b "可用的资源文件:"
    local i=1
    for f in "${sorted[@]}"; do
        cecho "  $i. $f"
        ((i++))
    done
    ;;
        load)
            if [ ${#LOADED_RES_CMDS[@]} -eq 0 ]; then
                cecho "当前未加载任何资源"
                return
            fi
            cecho -b "已加载的资源函数:"
            local i=1
            for f in "${LOADED_RES_CMDS[@]}"; do
                cecho "  $i. ${f#cmd_}"
                ((i++))
            done
            ;;
        del)
            # 无参数：全部卸载
            if [ $# -eq 0 ]; then
                if [ ${#LOADED_RES_CMDS[@]} -eq 0 ]; then
                    cecho "无已加载资源"
                    return
                fi
                confirm "确定卸载全部已加载资源?" || return
                for f in "${LOADED_RES_CMDS[@]}"; do unset -f "$f"; done
                LOADED_RES_CMDS=()
                cecho "已全部卸载"
                return
            fi

            local arg="$1"
            # 数字：卸载最旧 N 个
            if [[ "$arg" =~ ^[0-9]+$ ]]; then
                local n=$arg
                local total=${#LOADED_RES_CMDS[@]}
                if [ $total -eq 0 ]; then
                    cecho "无已加载资源"
                    return
                fi
                [ $n -gt $total ] && n=$total
                [ $n -eq 0 ] && cecho "数量为0, 跳过" && return
                confirm "确定卸载最旧的 $n 个资源?" || return
                for ((i=0; i<n; i++)); do
                    unset -f "${LOADED_RES_CMDS[0]}"
                    LOADED_RES_CMDS=("${LOADED_RES_CMDS[@]:1}")
                done
                cecho "已卸载 $n 个资源"
                return
            fi

            # 函数名(可不带 cmd_ 前缀)
            local name="$arg"
            [[ "$name" != cmd_* ]] && name="cmd_$name"
            local found=0 new=()
            for f in "${LOADED_RES_CMDS[@]}"; do
                if [ "$f" = "$name" ]; then
                    found=1
                else
                    new+=("$f")
                fi
            done
            if [ $found -eq 0 ]; then
                err "未找到已加载的资源: $arg"
                return 1
            fi
            confirm "确定卸载 $name?" || return
            unset -f "$name"
            LOADED_RES_CMDS=("${new[@]}")
            cecho "已卸载 $name"
            ;;
        *)
            err "未知子命令: $sub, 使用 RESOURCE -h 查看帮助"
            return 1
            ;;
    esac
}

# 历史命令管理
cmd_history() {
    case "$1" in
        -c|--clear)
            if confirm "确定要清除所有历史记录吗?"; then
                > "$HISTFILE"
                history -c
                cecho "历史已清除"
            fi
            ;;
        -n|--num)
            local num="${2:-10}"
            if ! [[ "$num" =~ ^[0-9]+$ ]]; then
                err "参数必须是数字"
                return 1
            fi
            if [ -f "$HISTFILE" ]; then
                tail -n "$num" "$HISTFILE" | cat -n
            else
                err "历史文件不存在"
            fi
            ;;
        -p|--path)
            cecho "历史文件: $HISTFILE"
            ;;
        -s|--size)
            if [ -f "$HISTFILE" ]; then
                lines=$(wc -l < "$HISTFILE")
                bytes=$(wc -c < "$HISTFILE")
                cecho "历史记录行数: $lines, 字节数: $bytes"
            else
                err "历史文件不存在"
            fi
            ;;
        -h|--help)
            cecho -b "用法: HISTORY [参数]"
            cecho "  -c, --clear    清除所有历史记录"
            cecho "  -n, --num N    显示最近 N 条历史 (默认10)"
            cecho "  -p, --path     显示历史文件路径"
            cecho "  -s, --size     显示历史记录行数和字节数"
            cecho "  -h, --help     显示此帮助"
            ;;
        *)
            if [ -f "$HISTFILE" ]; then
                local total_lines=$(wc -l < "$HISTFILE" 2>/dev/null || echo 0)
                if [ $total_lines -gt 100 ] && command -v more >/dev/null 2>&1; then
                    cat -n "$HISTFILE" | more
                else
                    cat -n "$HISTFILE"
                fi
            else
                err "历史文件不存在"
            fi
            ;;
    esac
}

# 自定义标题
cmd_title() {
        if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  ccat << "EOF"
//cecho -b " TITLE [-def]/[字符串]"
  TITLE             显示本帮助
  TITLE -def        恢复控制台标题为默认值
  TITLE <字符串>    设置自定义标题
  示例: TITLE cmd.exe [版本 16.0]
EOF
        return 0
    fi
    if [ "$1" = "-def" ]; then
        CUSTOM_TITLE=""
        save_config
        cecho "标题已恢复为默认值"
        return 0
    fi
    CUSTOM_TITLE="$*"
    save_config
    cecho "标题已设置为: $CUSTOM_TITLE"
}

# CLS
cmd_cls() {
    local show_title=""
    local title_config=$CLS_TITLE

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n) show_title=0 ;;
            -r|-y) show_title=1 ;;
            *) break ;;
        esac
        shift
    done
    [ -z "$show_title" ] && show_title=$title_config

    clear
    printf '\033[3J'
    for i in {1..200}; do echo; done
    printf '\033[H'
    if [ "$show_title" -eq 1 ]; then
        cecho "$CMD_delimiter"
        get_title
        echo ""
        echo ""
    fi
}

# CLS 默认行为
cmd_clsd() {
    if [ $# -eq 0 ]; then
        cecho "当前 CLS 默认标题显示: $([ $CLS_TITLE -eq 1 ] && echo "启用" || echo "禁用")"
        cecho "用法: CLSD -n     设置默认不显示标题"
        cecho "      CLSD -r/-y  设置默认显示标题"
        return 0
    fi
    case "$1" in
        -n) CLS_TITLE=0 ;;
        -r|-y) CLS_TITLE=1 ;;
        *) err "无效参数: $1"; return 1 ;;
    esac
    save_config
    cecho "CLS 默认标题显示已设置为: $([ $CLS_TITLE -eq 1 ] && echo "启用" || echo "禁用")"
}
# ---------- 命令实现函数 ----------
QAQ_cmd_help() {
ccat << EOF
$CMD_delimiter
//cecho -b "文件和目录操作"
//cecho -c 93 "若参数包含空格, 用双引号或者单引号包裹即可"
  COPY/CP [源...] [目标]        复制文件/目录 ⤸
  --支持多个源;目标为目录时复制到目录下
  CD [目录]                     修改工作目录
  CHMOD [参数] <模式> <文件...>      修改文件权限
  CHOWN [参数] <所有者> <文件...>    修改文件所有者
  DD [参数]                     复制并转换文件(系统)
  RM/DEL [文件]                 删除文件或目录
  RD/RMDIR [目录]               删除空目录
  FIND [路径...] [表达式...]    查找文件和目录
  HEAD [-n N] [参数] <文件>     显示文件开头N行(系统)
  TAIL [-n N] [参数] <文件>     显示文件结尾N行(系统)
  CUT [参数] [文件...]          按列/字段截取文本(系统)
  MD/MKDIR [目录]               创建目录
  NEW/TOUCH <文件>              创建新文件或者更新文件时间
  MOVE [源...] [目标]           移动文件/目录,或重命名(同目录下)
  REN [旧名] [新名]             重命名文件(=MOVE)
  DIR/LS [路径]                 列出目录内容
  DU [目录]                     列出目录大小
  SIZE [文件]                   列出文件大小
  STAT <文件>                   显示文件的详细信息
  WC [参数] [文件...]           统计行数、单词数、字符数
  CODEWC [参数] [文件...]       统计代码的行数、单词数、字符数(BETA)
  AWK [参数] '程序' [文件...]   执行 awk 程序(系统)
  GREP [参数] 模式 [文件...]    在文件中搜索(系统)
  CGREP <关键词|正则表达式> <文件1> [文件2...]
  --在文件中搜索字符串/正则表达式
  SED [参数] '脚本' [文件...]   流编辑器(系统)
  LN [-s] <源> <目标>           创建(软)链接
  TREE [参数] [路径]            显示目录树
  TYPE [文件]                   查看文本文件
  CAT [参数] <1> [2...]         更高级的查看文本文件(系统)
  MORE < 文件                   分页查看文本文件
  ZIP <输出文件> <源文件|目录> [-f] [-l]
  --创建 ZIP 压缩包(支持目录递归)
  UNZIP <压缩包> [-d 目标]      解压 ZIP 压缩包
//cecho -c 31 -b "需要root权限:"
  FORMAT <设备路径> [文件系统类型]
  --格式化存储设备
  MOUNT <设备> <挂载点> [参数] 挂载文件系统
  UMOUNT <设备或挂载点>        卸载文件系统

//cecho -b "系统"
  DATE [参数]         显示/设置时钟
  CAL [模式|年] [月]  显示日历
  CLOCK               显示实时时间(每0.1s刷新)
  FREE                显示当前内存使用
  DF [参数]           显示磁盘使用情况
  GETPROP [KEY]       系统属性(空KEY分页显示全部)
  ENV [参数]          显示/设置环境变量
  EXTS/EXES [参数]    显示当前终端可执行文件
  LOGCAT [参数]       系统日志相关功能
  UPTIME [参数]       系统运行时间
  RES/WM              显示屏幕相关信息(WM详细,RES兼容)
  BATT                显示电池信息
  SYSTEMINFO          系统信息
  TL/TASKLIST         进程列表
  TOP/TASKMGR         任务管理器
  TEMP                显示温度传感器、温度墙和温控状态
  MONITOR             实时显示时间、内存和温度(约每2s刷新)
  CPUMONITOR          实时显示每个CPU核心的当前频率
  WHOAMI              显示当前用户UID和权限
  ID [参数]           查看当前用户UID/GID/组
  WHICH               查找命令路径
  DISKC [参数]        检测各可读(写)挂载点的读写速度
  DISKT [参数]        检测当前存储设备的顺序和随机读写速度
  PATH [set (值)]     PATH段管理
  HOME [set (值)]     显示(set以外的任何情况)或者设置HOME目录
  PWD [-L|-P]         显示当前工作目录
  SDIR                显示脚本所在目录
  SELF                显示当前脚本路径

//cecho -b "网络"
  NETSTAT [参数]             网络连接统计
  HOSTNAME [参数]            显示主机名
  NETINFO                    显示当前设备的一些有用网络信息
  DNS [参数] [IPV4|域名]     相互转换IPV4或域名
  NETNEIG                    扫描局域网下的主机
  FTP [参数]                 FTP功能
  GIT [--sys|--sim] [参数]   GITHUB功能
  PING [参数]                测试网络连接
  PING6 [参数]               (=PING -6)
  SCAN [参数]                扫描网络中的存活主机
  PORTSCAN [参数]            扫描指定地址的存活端口
  DOWNLOAD <URL> <本地路径>  下载网络文件到本地
  SPEEDTEST [-u|-t]          网络测速(默认 Cloudflare 10MB)
  WGET <参数...>             网络下载工具(直接透传)
  CURL <参数...>             网络传输工具(直接透传)

//cecho -b "编解码与校验"
  B64 [参数]                            Base64编码/解码
  B32 [参数]                            Base32编码/解码
  SHA1 [参数]                           计算/校验SHA1
  SHA224 [参数]                         计算/校验SHA224
  SHA256 [参数]                         计算/校验SHA256
  SHA384 [参数]                         计算/校验SHA384
  SHA512 [参数]                         计算/校验SHA512
  MD5 [参数]                            计算/校验MD5
  B2SUM [参数]                          计算/校验BLAKE2b-512
  CRC32 [参数]                          计算/校验CRC32(cksum)
  DIFF [参数] <1> <2>                   比较两个文件/目录的差异
  ZIPDUFF [参数] <源> <新>              比较两个ZIP文件的差异
  JSON -w|[参数] <目标>                 检验JSON有效性
  PSD [-n 长度] [-C 数量] [参数...]     生成符合要求的随机密码
  RAND [长度]                           生成随机数(默认四位数)

//cecho -b "杂项"
  ECHO/PRINT [消息]          显示消息
  PRINTF/ECHO -e             解析代码的显示消息
  CECHO [参数] [消息]        CMD自定义的显示消息
  ERR [消息]                 显示错误样式消息(红色)
  YES [内容]                 刷屏某一内容直至按下Ctrl+C
  DUMP <目标> [输出]         扁平化文件夹结构(所有内容导出到TXT)
  HACK/HACK2 [参数] <目标>   穷举可打印字符直到找到目标(线性/二分搜索)
  AWKC <表达式>|<无参数进入交互>           AWK计算器
  BC [-s 精度] <表达式>|<无参数进入交互>   任意精度计算器
  TIMER [秒数]|[时间戳]                 倒计时/闹钟
  SLEEP <秒数>                          睡眠指定时间
  WATCH <秒数> <命令> [参数]            每隔指定时间清除屏幕并运行命令
  REPEAT <次数> <命令> [参数]           重复执行指定次数命令
  TIME <命令> [参数]                    测量命令执行耗时
  TIMEOUT [参数] <秒数> <命令> [参数]   在指定时间后终止命令
//cecho -b "ACMD"
  CLS/CLEAR [-n|-r|-y]          清除屏幕
  CLSD [-n|-r|-y]               设置清除屏幕默认行为
  COLOR [-def]|[BF]             设置控制台颜色
  TITLE [-def]|[文本]           设置控制台标题
  TMPDIR [参数]                 临时目录
  RESOURCE [参数]               资源目录
  HISTORY [参数]                历史命令
  ETC/CONFIG [参数|子命令]      配置
  UPDATE [--pre <0|1>]          检查更新
  INFO                          显示脚本自身信息
  HELP <OR> /?                  此命令列表
  EXIT/EXIT15                   正常退出
  EXITK/KILLSELF                杀掉自己以退出
//cecho -c "#C0C0C0" "  #按下Ctrl+C退出命令, 未说明时退出脚本"
  ULIMIT [参数] [限制值]        限制SHELL
  SH/RUN [-M|-S] <路径> [参数]  执行外部脚本
  C [-M] <系统命令> [参数]      执行任意系统命令(无参数系统交互)
  CC                            执行多条内置命令
  FUN [参数] [函数体]           临时定义函数(重启后失效,同名覆盖)
  ADB <参数>                    执行 ADB 命令
  RUNNING <包名>                启动应用程序
  KILL [-9|-15|-2|-t] <PID>     终止指定进程
$CMD_delimiter
EOF
}

cmd_pwd() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        cecho -b "用法: PWD [-L|-P]"
        cecho "显示当前工作目录"
        cecho "  -L          逻辑路径(跟随符号链接, 默认)"
        cecho "  -P          物理路径(解析符号链接)"
        cecho "  -h, --help  显示此帮助"
        return 0
    fi

    if [ $# -eq 0 ]; then
        cecho "$(pwd)"
        return 0
    fi

    case "$1" in
        -L|-P)
            builtin pwd "$1"
            ;;
        *)
            err "未知参数: $1, 使用 PWD -h 查看帮助"
            return 1
            ;;
    esac
}

cmd_whoami() {
    # ---------- 获取当前用户名 ----------
    # 优先使用 $_WHOAMI, 失败则回退到 id -un, 最后显示 unknown
    local user="$($_WHOAMI 2>/dev/null || id -un 2>/dev/null || echo 'unknown')"
    local user_level=""

    # ---------- 权限状态检测 ------------
    # 1. ROOT 权限 
    if [ "$(id -u 2>/dev/null)" = "0" ] || [ "$(whoami 2>/dev/null)" = "root" ]; then
        user_level="ROOT用户"
    else
        # 2. Shizuku 环境(shell 用户 + app_process + shizuku)
        # 适配不同 Android 版本的 ps, 使用 $_PS 和 $_GREP
        local shizuku_detected=0
        if $_PS -A -o user,args 2>/dev/null | $_GREP -v grep | $_GREP -qE '^shell.*shizuku' 2>/dev/null; then
            shizuku_detected=1
        elif $_PS -e -o user,args 2>/dev/null | $_GREP -v grep | $_GREP -qE '^shell.*shizuku' 2>/dev/null; then
            shizuku_detected=1
        elif $_PS 2>/dev/null | $_GREP -v grep | $_GREP -qE 'shell.*shizuku' 2>/dev/null; then
            shizuku_detected=1
        fi

        if [ $shizuku_detected -eq 1 ]; then
            user_level="ADB调试 (Shizuku激活)"
        else
            # 3. 常规 ADB 调试环境
            local is_adb=0
            local tcp_port=""

            # 3.1 环境变量或父进程(最直接)
            if [ -n "$ADB_SHELL" ] || [ -n "$ASH_STARTED" ] || \
               (echo "$PPID" | xargs ps -o comm= 2>/dev/null | $_GREP -qi 'adbd'); then
                is_adb=1
            fi

            # 3.2 补充: 系统属性(用于显示端口信息, 但不作为唯一判断依据)
            local prop_tcpport=$(getprop service.adb.tcp.port 2>/dev/null)
            local prop_state=$(getprop init.svc.adbd 2>/dev/null)
            if [ "$prop_state" = "running" ]; then
                is_adb=1
            fi
            if [ -n "$prop_tcpport" ] && [ "$prop_tcpport" -gt 0 ] 2>/dev/null; then
                is_adb=1
                tcp_port="$prop_tcpport"
            fi

            # 4. 综合判断
            if [ $is_adb -eq 1 ]; then
                user_level="ADB调试"
                if [ -n "$tcp_port" ]; then
                    user_level="ADB调试 (网络调试已开启, 端口:$tcp_port)"
                fi
            else
                user_level="普通用户"
            fi
        fi
    fi

    # ---------- 统一输出 ----------
    cecho "当前用户: $user"
    cecho "当前权限状态: $user_level"
    if [ "$_IAMDC10XRAY_" = "1" ]; then
        cecho -b -c256 201 "SP: ACMD 特殊用户(开发者)"
    fi
}

cmd_id() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    ccat << "EOF"
//cecho -b "用法: ID [参数]"
显示当前用户的 UID、GID 和所属组
//cecho -b "参数:"
-u          只显示 UID
-g          只显示主 GID
-G          显示所有 GID
-n          显示名称而不是数字(与 -u/-g/-G 搭配)
-r          显示真实 ID 而非有效 ID
-h, --help  显示此帮助
EOF
        return 0
    fi

    if command -v id >/dev/null 2>&1; then
        id "$@" 2>&1 | while IFS= read -r line; do cecho "$line"; done
        return ${PIPESTATUS[0]}
    elif _bb_has id; then
        busybox id "$@" 2>&1 | while IFS= read -r line; do cecho "$line"; done
        return ${PIPESTATUS[0]}
    else
        err "未找到 id 命令"
        return 127
    fi
}

# ---------- 人性化时间公共函数 ----------
# 占位符:
#   YYYY YY MM DD HH hh mm ss AA aa
#   mmm       毫秒(3位总值)       = 小数秒前3位
#   uuuuuu    微秒(6位总值)       = 小数秒前6位
#   uuu       微秒分量(3位)       = 小数秒第4-6位
#   NNNNNNNNN 纳秒(9位总值)       = 全部小数秒
#   NN        纳秒分量(3位)       = 小数秒第7-9位
#   TZ        时区偏移            = 形如 +08:00
# 替换顺序说明:
#   1) TZ 最先替换为 @@TZ@@%z@@TZ_END@@, 后续只清理标记
#   2) 小数秒"长占位符"先于"短占位符"
#   3) mm(分) 必须在 mmm(毫秒) 之后替换
_human_date_fmt() {
    local fmt="$1"

    # ---- 1) 时区: TZ -> @@TZ@@%z@@TZ_END@@ (冒号由后处理补) ----
    fmt="${fmt//TZ/@@TZ@@%z@@TZ_END@@}"

    # ---- 2) 日期 ----
    fmt="${fmt//YYYY/%Y}"
    fmt="${fmt//YY/%y}"
    fmt="${fmt//MM/%m}"
    fmt="${fmt//DD/%d}"
    fmt="${fmt//HH/%H}"
    fmt="${fmt//hh/%I}"

    # ---- 3) 小数秒(长占位符优先) ----
    fmt="${fmt//NNNNNNNNN/@NS9@}"   # 纳秒总值
    fmt="${fmt//uuuuuu/@US6@}"      # 微秒总值
    fmt="${fmt//mmm/@MS3@}"         # 毫秒
    fmt="${fmt//uuu/@US3@}"         # 微秒分量
    fmt="${fmt//NN/@NS3@}"          # 纳秒分量

    # ---- 4) 分/秒/星期 ----
    fmt="${fmt//mm/%M}"
    fmt="${fmt//ss/%S}"
    fmt="${fmt//AA/%A}"
    fmt="${fmt//aa/%a}"

    printf '%s' "$fmt"
}

# 把 @MS3@/@US6@/@US3@/@NS9@/@NS3@ 替换成小数秒对应位
# 参数: $1=字符串, $2=9位纳秒(空/非法则视为 000000000)
_human_date_fix_subsec() {
    local out="$1" ns="${2:-}"
    if [[ "$out" != *"@MS3@"* && "$out" != *"@US6@"* && "$out" != *"@US3@"* \
          && "$out" != *"@NS9@"* && "$out" != *"@NS3@"* ]]; then
        printf '%s' "$out"
        return
    fi
    if ! [[ "$ns" =~ ^[0-9]+$ ]]; then
        ns="000000000"
    fi
    while [ ${#ns} -lt 9 ]; do ns="0$ns"; done
    ns="${ns:0:9}"

    out="${out//@MS3@/${ns:0:3}}"   # 毫秒(3)
    out="${out//@US6@/${ns:0:6}}"   # 微秒(6)
    out="${out//@US3@/${ns:3:3}}"   # 微秒分量(3)
    out="${out//@NS9@/${ns:0:9}}"   # 纳秒(9)
    out="${out//@NS3@/${ns:6:9}}"   # 纳秒分量(3)
    printf '%s' "$out"
}

# 把 @@TZ@@+0800@@TZ_END@@ 收尾为 +08:00
_human_date_fix_tz() {
    local out="$1"

    # 正常形式: @@TZ@@+0800@@TZ_END@@ -> +08:00
    while [[ "$out" =~ @@TZ@@([+-])([0-9]{2})([0-9]{2})@@TZ_END@@ ]]; do
        out="${out//${BASH_REMATCH[0]}/${BASH_REMATCH[1]}${BASH_REMATCH[2]}:${BASH_REMATCH[3]}}"
    done

    # 极端情况: date 不支持 %z, 降级为 +00:00
    out="${out//@@TZ@@%z@@TZ_END@@/+00:00}"
    out="${out//@@TZ@@@@TZ_END@@/+00:00}"

    # 清理残留标记
    out="${out//@@TZ@@/}"
    out="${out//@@TZ_END@@/}"
    printf '%s' "$out"
}

# 按人性化格式输出时间
# 参数: $1=人性化格式串, $2=utc(0/1), $3=参考文件(可选, 显示其修改时间)
_human_date_output() {
    local human_fmt="$1" utc="$2" ref_file="$3"
    local fmt
    fmt=$(_human_date_fmt "$human_fmt")

    local out
    if [ -n "$ref_file" ]; then
        if [ "$utc" -eq 1 ]; then
            out=$($_DATE -u -r "$ref_file" "+$fmt" 2>/dev/null)
        else
            out=$($_DATE -r "$ref_file" "+$fmt" 2>/dev/null)
        fi
    else
        if [ "$utc" -eq 1 ]; then
            out=$($_DATE -u "+$fmt" 2>/dev/null)
        else
            out=$($_DATE "+$fmt" 2>/dev/null)
        fi
    fi

    # 需要拆分小数秒时, 单独取 9 位纳秒
    if [[ "$fmt" == *"@MS3@"* || "$fmt" == *"@US6@"* || "$fmt" == *"@US3@"* \
          || "$fmt" == *"@NS9@"* || "$fmt" == *"@NS3@"* ]]; then
        local ns=""
        if [ -n "$ref_file" ]; then
            if [ "$utc" -eq 1 ]; then
                ns=$($_DATE -u -r "$ref_file" +%N 2>/dev/null)
            else
                ns=$($_DATE -r "$ref_file" +%N 2>/dev/null)
            fi
        else
            if [ "$utc" -eq 1 ]; then
                ns=$($_DATE -u +%N 2>/dev/null)
            else
                ns=$($_DATE +%N 2>/dev/null)
            fi
        fi
        out=$(_human_date_fix_subsec "$out" "$ns")
    fi

    # 时区收尾
    if [[ "$out" == *"@@TZ"* ]]; then
        out=$(_human_date_fix_tz "$out")
    fi

    printf '%s' "$out"
}

# 兼容旧名
_human_date_now() {
    _human_date_output "$1" 0 ""
}

cmd_date() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        ccat << "EOF"
//cecho -b "用法: DATE [参数]"
  (无参数)             默认格式: YYYY-MM-DD HH:MM:SS (AA)
  -f <格式>            按 date 格式串输出(如 %Y-%m-%d)
  -fp <人性化格式>     按指定格式输出, 人性化格式
  -u                   使用 UTC 时间
  -v                   输出系统 date 默认格式(原始)
                       可与 -n 同时使用, 此时输出原始格式的网络时间
  -r <文件>            显示文件的修改时间
  -s <时间字符串>      设置系统时间
  -n [URL...]          从互联网获取时间(默认: www.ntsc.ac.cn)
                       可跟多个 URL, 按顺序依次尝试并显示
  -sn [URL]            从互联网获取时间并立即设置其为系统时间
                       默认: www.ntsc.ac.cn, 只允许一个 URL
  -h, --help           显示此帮助
//cecho -b "人性化格式(-fp)占位符:"
  YYYY=年  YY=两位年  MM=月  DD=日
  HH=24时  hh=12时  mm=分  ss=秒
  mmm=毫秒(3位总值)        如 802
  uuuuuu=微秒(6位总值)     如 802598
  uuu=微秒分量(3位)        如 598
  NNNNNNNNN=纳秒(9位总值)  如 802598399
  NN=纳秒分量(3位)         如 399
  AA=星期全称  aa=星期缩写
  TZ=时区偏移              如 +08:00
EOF
        return 0
    fi

    local fmt="%Y-%m-%d %H:%M:%S (%A)"
    local human_fmt=""          # -fp 时的原始人性化格式串(非空表示使用 -fp)
    local fmt_set=0
    local utc=0
    local raw=0
    local set_time=""
    local ref_file=""
    local use_net=0
    local set_net=0
    local set_net_url=""
    local -a net_urls=()

    while [ $# -gt 0 ]; do
        case "$1" in
            -f)
                if [ $# -lt 2 ]; then
                    err "参数 -f 需要格式串"
                    return 1
                fi
                fmt="$2"; fmt_set=1; human_fmt=""; shift 2 ;;
            -fp)
                if [ $# -lt 2 ]; then
                    err "参数 -fp 需要人性化格式串"
                    return 1
                fi
                human_fmt="$2"
                fmt=$(_human_date_fmt "$2")
                fmt_set=1; shift 2 ;;
            -u) utc=1; shift ;;
            -v) raw=1; shift ;;
            -r)
                if [ $# -lt 2 ]; then
                    err "参数 -r 需要文件路径"
                    return 1
                fi
                ref_file="$2"; shift 2 ;;
            -s)
                if [ $# -lt 2 ]; then
                    err "参数 -s 需要时间字符串"
                    return 1
                fi
                set_time="$2"; shift 2 ;;
            -sn)
                set_net=1; shift
                if [ $# -gt 0 ]; then
                    case "$1" in
                        -*) ;;
                        *) set_net_url="$1"; shift ;;
                    esac
                fi
                if [ $# -gt 0 ]; then
                    case "$1" in
                        -*) ;;
                        *) err "-sn 只允许指定一个 URL"; return 1 ;;
                    esac
                fi
                ;;
            -n)
                use_net=1; shift
                while [ $# -gt 0 ]; do
                    case "$1" in
                        -*) break ;;
                    esac
                    net_urls+=("$1"); shift
                done
                ;;
            *)
                err "未知参数: $1, 使用 DATE -h 查看帮助"
                return 1 ;;
        esac
    done

    # ---------- 互斥校验 ----------
    if [ -n "$set_time" ] && { [ $utc -eq 1 ] || [ $fmt_set -eq 1 ] || [ $raw -eq 1 ] || [ -n "$ref_file" ] || [ $use_net -eq 1 ] || [ $set_net -eq 1 ]; }; then
        err "-s 不能与 -f/-fp/-u/-v/-r/-n/-sn 同时使用"
        return 1
    fi
    if [ -n "$ref_file" ] && { [ $raw -eq 1 ] || [ $use_net -eq 1 ] || [ $set_net -eq 1 ]; }; then
        err "-r 不能与 -v/-n/-sn 同时使用"
        return 1
    fi
    if [ $raw -eq 1 ] && { [ $utc -eq 1 ] || [ $fmt_set -eq 1 ] || [ $set_net -eq 1 ]; }; then
        err "-v 不能与 -f/-fp/-u/-sn 同时使用"
        return 1
    fi
    if [ $set_net -eq 1 ] && { [ $use_net -eq 1 ] || [ $utc -eq 1 ] || [ $fmt_set -eq 1 ]; }; then
        err "-sn 不能与 -n/-f/-fp/-u 同时使用"
        return 1
    fi

    # ---------- 互联网时间设置系统时间 ----------
    if [ $set_net -eq 1 ]; then
        [ -z "$set_net_url" ] && set_net_url="www.ntsc.ac.cn"

        local ts
        if ! ts=$(_nettime_epoch "$set_net_url"); then
            err "$set_net_url: 获取互联网时间失败"
            return 1
        fi

        if $_DATE -s "@$ts" 2>/dev/null; then
            cecho "已根据 $set_net_url 设置系统时间为: $($_DATE "+%Y-%m-%d %H:%M:%S")"
            return 0
        else
            err "设置系统时间失败"
            return 1
        fi
    fi

    # ---------- 互联网时间显示 ----------
    if [ $use_net -eq 1 ]; then
        if [ $raw -eq 1 ]; then
            fmt=""
        else
            # HTTP Date 响应头仅到秒, 亚秒占位符会得到误导性的 0
            if [ -n "$human_fmt" ]; then
                if [[ "$fmt" == *"@MS3@"* || "$fmt" == *"@US6@"* || "$fmt" == *"@US3@"* \
                      || "$fmt" == *"@NS9@"* || "$fmt" == *"@NS3@"* ]]; then
                    err "HTTP Date 响应头最多精确到秒"
                    return 1
                fi
            else
                if [[ "$fmt" =~ %[0-9]*N ]]; then
                    err "HTTP Date 响应头最多精确到秒"
                    return 1
                fi
            fi
        fi

        if [ ${#net_urls[@]} -eq 0 ]; then
            net_urls=("www.ntsc.ac.cn")
        fi

        local _ok=1
        local _u _t
        for _u in "${net_urls[@]}"; do
            if _t=$(_nettime_fetch "$_u" "$fmt" "$utc"); then
                cecho "$_u: $_t"
                _ok=0
            else
                err "$_u: 获取失败"
            fi
        done
        return $_ok
    fi

    # ---------- 设置系统时间 ----------
    if [ -n "$set_time" ]; then
        $_DATE -s "$set_time"
        local ret=$?
        if [ $ret -eq 0 ]; then
            cecho "系统时间已设置为: $($_DATE "+%Y-%m-%d %H:%M:%S")"
            return 0
        else
            err "设置系统时间失败 (退出码: $ret)"
            return 1
        fi
    fi

    # ---------- 文件修改时间 ----------
    if [ -n "$ref_file" ]; then
        if [ ! -e "$ref_file" ]; then
            err "文件不存在: $ref_file"
            return 1
        fi

        local file_time
        if [ -n "$human_fmt" ]; then
            file_time=$(_human_date_output "$human_fmt" "$utc" "$ref_file")
        else
            if [ $utc -eq 1 ]; then
                file_time=$($_DATE -u -r "$ref_file" "+$fmt" 2>/dev/null)
            else
                file_time=$($_DATE -r "$ref_file" "+$fmt" 2>/dev/null)
            fi
        fi

        if [ -z "$file_time" ]; then
            file_time=$($_STAT -c '%y' "$ref_file" 2>/dev/null)
        fi

        if [ -z "$file_time" ]; then
            err "无法读取文件时间: $ref_file"
            return 1
        fi
        cecho "$file_time"
        return 0
    fi

    # ---------- 原始输出 ----------
    if [ $raw -eq 1 ]; then
        $_DATE
        return $?
    fi

    # ---------- 正常显示 ----------
    if [ -n "$human_fmt" ]; then
        cecho "$(_human_date_output "$human_fmt" "$utc" "")"
    else
        if [ $utc -eq 1 ]; then
            cecho "$($_DATE -u "+$fmt" 2>/dev/null)"
        else
            cecho "$($_DATE "+$fmt" 2>/dev/null)"
        fi
    fi
}

# 从 URL 的 HTTP 响应头 Date 字段提取 epoch 时间戳
# 用法: _nettime_epoch <url>
# 成功时 echo 秒级时间戳并返回 0, 失败返回 1
_nettime_epoch() {
    local url="$1"

    case "$url" in
        http://*|https://*) ;;
        *) url="https://$url" ;;
    esac

    local hdr=""
    local awk_date='/^[Dd][Aa][Tt][Ee]:/{sub(/^[Dd][Aa][Tt][Ee]:[ \t]*/,""); sub(/\r$/,""); print; exit}'

    hdr=$(curl -sI --max-time 8 -L "$url" 2>/dev/null | awk "$awk_date")

    if [ -z "$hdr" ]; then
        hdr=$(curl -s --max-time 8 -L -o /dev/null -D - "$url" 2>/dev/null | awk "$awk_date")
    fi

    if [ -z "$hdr" ]; then
        case "$url" in
            https://*)
                local u2="http://${url#https://}"
                hdr=$(curl -sI --max-time 8 -L "$u2" 2>/dev/null | awk "$awk_date")
                if [ -z "$hdr" ]; then
                    hdr=$(curl -s --max-time 8 -L -o /dev/null -D - "$u2" 2>/dev/null | awk "$awk_date")
                fi
                ;;
        esac
    fi

    [ -z "$hdr" ] && return 1

    local ts
    ts=$($_DATE -u -d "$hdr" "+%s" 2>/dev/null)
    [ -z "$ts" ] && return 1
    echo "$ts"
}

# 从 URL 获取时间并按格式输出
# 用法: _nettime_fetch <url> <fmt> <utc(0/1)>
#   fmt 为空时使用系统 date 默认格式(不带 +格式串)
_nettime_fetch() {
    local url="$1" fmt="$2" utc="$3"
    local ts
    ts=$(_nettime_epoch "$url") || return 1

    if [ -z "$fmt" ]; then
        if [ "$utc" -eq 1 ]; then
            $_DATE -u -d "@$ts"
        else
            $_DATE -d "@$ts"
        fi
    elif [ "$utc" -eq 1 ]; then
        $_DATE -u -d "@$ts" "+$fmt"
    else
        $_DATE -d "@$ts" "+$fmt"
    fi
}

cmd_sleep() {
        if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -eq 0 ]; then
        cecho -b "用法: sleep <时间>"
        cecho "示例: sleep 5"
        return 0
    fi
    local time_arg="$1"
    if ! echo "$time_arg" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
        err "无效的时间值"
        return 1
    fi
    if [ $# -gt 1 ]; then
        err "多余参数"
        return 1
    fi
    local old_trap=$(trap -p INT)
    local interrupted=0
    trap 'interrupted=1' INT
    cecho "将会睡眠 $time_arg 秒(按Ctrl+C中断)"
    sleep "$time_arg"
    eval "$old_trap" 2>/dev/null
    if [ $interrupted -eq 1 ]; then
        cecho "睡眠被中断"
        return 130
    fi
    cecho "睡眠完成"
}

cmd_yes() {
    local string="$*"
    local prompt
    if [ -z "$string" ]; then
        prompt="您确定要刷屏空内容吗?(Ctrl+C终止)"
    else
        prompt="您确定要刷屏\"$string\"吗?(Ctrl+C终止)"
    fi

    if ! confirm "$prompt"; then
        return 0
    fi
    # 保存旧的 INT 陷阱
    local old_trap=$(trap -p INT)
    local interrupted=0
    local yes_pid=""

    # 设置新的 INT 陷阱: 设置中断标志并杀死后台进程
    trap 'interrupted=1; [ -n "$yes_pid" ] && kill $yes_pid 2>/dev/null' INT

    # 检测 yes 命令是否存在, 若存在则使用, 否则用循环模拟
    if command -v yes >/dev/null 2>&1; then
        yes "$string" &
        yes_pid=$!
    else
        # 使用子 shell 循环, printf 确保空字符串输出空行且不解释转义
        ( while true; do printf '%s\n' "$string"; done ) &
        yes_pid=$!
    fi

    # 等待后台进程结束(可能被信号中断)
    wait $yes_pid 2>/dev/null

    # 恢复旧的 INT 陷阱
    if [ -n "$old_trap" ]; then
        eval "$old_trap"
    else
        trap - INT
    fi

    # 如果被中断, 返回 130
    if [ $interrupted -eq 1 ]; then
        echo "" >&2
        return 130
    fi
}

cmd_echo() {
    # 显示帮助
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cecho -b "用法: ECHO [-e] [-n] [消息]"
        cecho -b "支持参数:"
        cecho "  -e       启用转义字符解析(如 \\n, \\t)"
        cecho "  -n       不换行输出"
        cecho "  -en/-ne  同时启用 -e 和 -n"
        return 0
    fi

    local opts=()
    # 解析参数(仅支持 -e、-n、-en、-ne)
    while [ $# -gt 0 ]; do
        case "$1" in
            -e) opts+=("-e"); shift ;;
            -n) opts+=("-n"); shift ;;
            -en|-ne) opts+=("-e" "-n"); shift ;;
            *) break ;;
        esac
    done
    local text="$*"   # 剩余所有参数合并为一个字符串(保留空格)

    # 判断是否启用转义解析
    local has_e=0
    local has_n=0
    for opt in "${opts[@]}"; do
        [ "$opt" = "-e" ] && has_e=1
        [ "$opt" = "-n" ] && has_n=1
    done

    if [ $has_e -eq 1 ]; then
        # 使用 printf 的 %b 来解析转义序列
        if [ $has_n -eq 1 ]; then
            printf "%b" "$text"
        else
            printf "%b\n" "$text"
        fi
    else
        # 不解析转义, 直接原样输出
        if [ $has_n -eq 1 ]; then
            printf "%s" "$text"
        else
            printf "%s\n" "$text"
        fi
    fi
}

cmd_cecho() {
    # 显示帮助
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        cecho -b "用法: CECHO [参数] [消息]"
        cecho -b "参数:"
        ccat << "EOF"
-n               不换行
-c <颜色>        设置前景色 (两位数字颜色码或 #RRGGBB 十六进制)
-cb <颜色>       设置背景色 (两位数字颜色码或 #RRGGBB 十六进制)
-c256 <0-255>    设置256色前景色
-cb256 <0-255>   设置256色背景色
-b               粗体
-i               斜体
-u               下划线
-s               删除线
-r               纯文本模式 (忽略所有样式和颜色)
-h, --help       显示本帮助

//cecho -c 90 "注意: -c/-cb 与 -c256/-cb256 不能同时使用"
EOF
        return 0
    fi

    # 初始化变量
    local opt_n=false
    local custom_fg=""
    local custom_bg=""
    local custom_fg256=""
    local custom_bg256=""
    local bold=0
    local italic=0
    local underline=0
    local strikethrough=0
    local plain=0
    local text_args=()

    # 解析参数
    while [ $# -gt 0 ]; do
        case "$1" in
            -n) opt_n=true; shift ;;
            -c)
                if [ $# -lt 2 ]; then
                    err "参数 -c 需要指定颜色值"
                    return 1
                fi
                custom_fg="$2"; shift 2 ;;
            -cb)
                if [ $# -lt 2 ]; then
                    err "参数 -cb 需要指定颜色值"
                    return 1
                fi
                custom_bg="$2"; shift 2 ;;
            -c256)
                if [ $# -lt 2 ]; then
                    err "参数 -c256 需要指定颜色值"
                    return 1
                fi
                custom_fg256="$2"; shift 2 ;;
            -cb256)
                if [ $# -lt 2 ]; then
                    err "参数 -cb256 需要指定颜色值"
                    return 1
                fi
                custom_bg256="$2"; shift 2 ;;
            -b) bold=1; shift ;;
            -i) italic=1; shift ;;
            -u) underline=1; shift ;;
            -s) strikethrough=1; shift ;;
            -r) plain=1; shift ;;
            --) shift; break ;;
            -*)
                err "未知参数: $1"
                return 1
                ;;
            *) break ;;
        esac
    done

    # 剩余所有参数视为文本
    text_args=("$@")

    # 构建调用 _cprint 的参数列表
    local call_args=()
    [ "$opt_n" = true ] && call_args+=("-n")
    [ -n "$custom_fg" ]    && call_args+=("-c" "$custom_fg")
    [ -n "$custom_bg" ]    && call_args+=("-cb" "$custom_bg")
    [ -n "$custom_fg256" ] && call_args+=("-c256" "$custom_fg256")
    [ -n "$custom_bg256" ] && call_args+=("-cb256" "$custom_bg256")
    [ "$bold" -eq 1 ] && call_args+=("-b")
    [ "$italic" -eq 1 ] && call_args+=("-i")
    [ "$underline" -eq 1 ] && call_args+=("-u")
    [ "$strikethrough" -eq 1 ] && call_args+=("-s")
    [ "$plain" -eq 1 ] && call_args+=("-r")

    # 如果存在文本, 将其合并为一个字符串并添加到参数列表
    if [ ${#text_args[@]} -gt 0 ]; then
        local text="${text_args[*]}"
        call_args+=("$text")
    fi

    # 调用底层函数执行输出
    _cprint "${call_args[@]}"
}

# ---------- CURL 包装 ----------
cmd_curl() {
    if [ "$HAS_CURL" -eq 0 ]; then
        err "当前系统未安装 curl"
        return 127
    fi
    $_CURL "$@"
}

# ---------- WGET 包装 ----------
cmd_wget() {
    if [ "$HAS_WGET" -eq 0 ]; then
        err "当前系统未安装 wget"
        return 127
    fi
    $_WGET "$@"
}


# ------------- 文件操作函数 -------------
# 负责 copy / move / del / mkdir / rmdir / touch / link
#  用法: file_op <操作> [系统参数] <参数...>
# 规则:
# -系统参数原样透传给底层命令
# -未给关键参数时, 自动补人性化参数(见各分支)
file_op() {
    [ $# -eq 0 ] && { err "file_op: 缺少操作类型"; return 1; }

    local op="${1,,}"; shift
    case "$op" in
        copy|cp)             op="copy"  ;;
        move|mv|ren|rename)  op="move"  ;;
        del|rm|erase)        op="del"   ;;
        md|mkdir)            op="mkdir" ;;
        rd|rmdir)            op="rmdir" ;;
        new|touch)           op="touch" ;;
        ln|link)             op="link"  ;;
        *) err "file_op: 未知操作: $op"; return 1 ;;
    esac

    # ---------- 解析参数 / 位置参数 ----------
    local end_opts=0
    local -a opts=() pos=()
    while [ $# -gt 0 ]; do
        if [ $end_opts -eq 1 ]; then pos+=("$1"); shift; continue; fi
        case "$1" in
            --)  end_opts=1; shift ;;
            -*)  opts+=("$1"); shift ;;
            *)   pos+=("$1"); shift ;;
        esac
    done

    # ---------- 工具: 检测参数串里是否含某字符 ----------
    _file_op_has_char() {
        local needle="$1"; shift
        local o
        for o in "$@"; do
            case "$o" in
                --*) continue ;;                # 长参数不当作短参数字符匹配
                -*)  [[ "${o#-}" == *"$needle"* || "${o#-}" == *"${needle^^}"* ]] && return 0 ;;
            esac
        done
        return 1
    }

    case "$op" in

    # ================= COPY =================
    copy)
        [ ${#pos[@]} -lt 2 ] && { err "用法: COPY [系统参数] <源...> <目标>"; return 1; }
        local dest="${pos[${#pos[@]}-1]}"
        local sources=("${pos[@]:0:${#pos[@]}-1}")

        # 脚本行为: 目标父目录不存在则自动创建
        local ddir; ddir=$(dirname "$dest")
        [ -n "$ddir" ] && [ "$ddir" != "." ] && [ ! -d "$ddir" ] && mkdir -p "$ddir" 2>/dev/null

        local dest_is_dir=0; [ -d "$dest" ] && dest_is_dir=1
        if [ ${#sources[@]} -gt 1 ] && [ $dest_is_dir -eq 0 ] && [ -e "$dest" ]; then
            err "多个源时目标必须为目录"; return 1
        fi

        # 脚本行为: 用户没给 r/R 时, 源是目录就补 -r
        local has_r=0
        _file_op_has_char r "${opts[@]}" && has_r=1

        local src
        for src in "${sources[@]}"; do
            [ -e "$src" ] || { err "源不存在: $src"; return 1; }

            local target
            if [ $dest_is_dir -eq 1 ]; then
                target="$dest/$(basename "$src")"
            else
                target="$dest"
            fi

            local -a cur=("${opts[@]}")
            if [ $has_r -eq 0 ] && [ -d "$src" ]; then
                cur+=("-r")
            fi

            $_CP "${cur[@]}" "$src" "$target" 2>/dev/null \
                || { err "复制失败: $src"; return 1; }
        done
        ;;

    # ================= MOVE =================
    move)
        [ ${#pos[@]} -lt 2 ] && { err "用法: MOVE [系统参数] <源...> <目标>"; return 1; }
        local dest="${pos[${#pos[@]}-1]}"
        local sources=("${pos[@]:0:${#pos[@]}-1}")

        # 脚本行为: 目标父目录不存在则自动创建
        local ddir; ddir=$(dirname "$dest")
        [ -n "$ddir" ] && [ "$ddir" != "." ] && [ ! -d "$ddir" ] && mkdir -p "$ddir" 2>/dev/null

        local dest_is_dir=0; [ -d "$dest" ] && dest_is_dir=1
        if [ ${#sources[@]} -gt 1 ] && [ $dest_is_dir -eq 0 ] && [ -e "$dest" ]; then
            err "多个源时目标必须为目录"; return 1
        fi

        local src
        for src in "${sources[@]}"; do
            [ -e "$src" ] || { err "源不存在: $src"; return 1; }

            local target
            if [ $dest_is_dir -eq 1 ]; then
                target="$dest/$(basename "$src")"
            else
                target="$dest"
            fi

            $_MV "${opts[@]}" "$src" "$target" 2>/dev/null \
                || { err "移动失败: $src"; return 1; }
        done
        ;;

    # ================= DEL =================
    del)
        [ ${#pos[@]} -eq 0 ] && { err "用法: DEL [系统参数] <目标...>"; return 1; }

        # 脚本行为: 用户没给 r/R 时, 目标里含目录就补 -r
        local has_r=0
        _file_op_has_char r "${opts[@]}" && has_r=1

        local -a cur=("${opts[@]}")
        if [ $has_r -eq 0 ]; then
            local f
            for f in "${pos[@]}"; do
                [ -d "$f" ] && { cur+=("-r"); break; }
            done
        fi

        local f
        for f in "${pos[@]}"; do
            [ -e "$f" ] || { err "系统找不到指定的路径: $f"; continue; }
            $_RM "${cur[@]}" "$f" 2>/dev/null \
                || err "删除失败: $f"
        done
        ;;

    # ================= MKDIR =================
    mkdir)
        [ ${#pos[@]} -eq 0 ] && { err "用法: MD [系统参数] <目录...>"; return 1; }

        # 脚本行为: 用户没给 p 时补 -p (递归建父目录)
        local has_p=0
        _file_op_has_char p "${opts[@]}" && has_p=1

        local -a cur=("${opts[@]}")
        [ $has_p -eq 0 ] && cur+=("-p")

        local f
        for f in "${pos[@]}"; do
            $_MKDIR "${cur[@]}" "$f" 2>/dev/null \
                || err "目录创建失败: $f"
        done
        ;;

    # ================= RMDIR =================
    rmdir)
        [ ${#pos[@]} -eq 0 ] && { err "用法: RD [系统参数] <目录...>"; return 1; }
        local f
        for f in "${pos[@]}"; do
            [ -d "$f" ] || { err "系统找不到指定的路径: $f"; continue; }
            $_RMDIR "${opts[@]}" "$f" 2>/dev/null \
                || err "目录删除失败(可能非空): $f"
        done
        ;;

    # ================= TOUCH =================
    touch)
        [ ${#pos[@]} -eq 0 ] && { err "用法: NEW [系统参数] <文件...>"; return 1; }
        local f
        for f in "${pos[@]}"; do
            # 脚本行为: 目标父目录不存在则自动创建
            local d; d=$(dirname "$f")
            [ -n "$d" ] && [ "$d" != "." ] && [ ! -d "$d" ] && mkdir -p "$d" 2>/dev/null
            touch "${opts[@]}" "$f" 2>/dev/null \
                || err "无法处理: $f"
        done
        ;;

    # ================= LINK =================
    link)
        [ ${#pos[@]} -lt 2 ] && { err "用法: LN [系统参数] <源> <目标>"; return 1; }
        local src="${pos[0]}" target="${pos[1]}"
        [ -e "$src" ] || { err "源不存在: $src"; return 1; }
        ln "${opts[@]}" "$src" "$target" 2>/dev/null \
            || { err "创建链接失败"; return 1; }
        ;;
    esac
}

# 七个命令薄壳 (仅帮助 + 参数校验)
cmd_copy() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        ccat << "EOF"
//cecho -b "用法: COPY [系统参数] <源...> <目标>"
//cecho -b "脚本行为:"
  - 目标父目录不存在时自动创建
  - 源是目录且未给 -r/-R 时自动补 -r
EOF
        return 0
    fi
    [ $# -lt 2 ] && { err "用法: COPY [系统参数] <源...> <目标>"; return 1; }
    file_op copy "$@"
}

cmd_move() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
cecho "用法: MOVE [系统参数] <源...> <目标>"
cecho "脚本行为:"
cecho "  - 目标父目录不存在时自动创建"
        return 0
    fi
    [ $# -lt 2 ] && { err "用法: MOVE [系统参数] <源...> <目标>"; return 1; }
    file_op move "$@"
}

cmd_del() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
cecho -b "用法: DEL [系统参数] <目标...>"
cecho -b "脚本行为:"
cecho "  - 目标含目录且未给 -r/-R 时自动补 -r"
        return 0
    fi
    [ $# -eq 0 ] && { err "用法: DEL [系统参数] <目标...>"; return 1; }
    file_op del "$@"
}

cmd_md() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
cecho -b "用法: MD [系统参数] <目录...>"
cecho -b "脚本行为:"
cecho "  - 未给 -p 时自动补 -p (递归创建父目录)"
        return 0
    fi
    [ $# -eq 0 ] && { err "用法: MD [系统参数] <目录...>"; return 1; }
    file_op mkdir "$@"
}

cmd_rd() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
cecho -b "用法: RD [系统参数] <目录...>"
        return 0
    fi
    [ $# -eq 0 ] && { err "用法: RD [系统参数] <目录...>"; return 1; }
    file_op rmdir "$@"
}

cmd_touch() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
cecho -b "用法: NEW [系统参数] <文件...>"
cecho -b "脚本行为:"
cecho "  - 目标父目录不存在时自动创建"
        return 0
    fi
    [ $# -eq 0 ] && { err "用法: NEW [系统参数] <文件...>"; return 1; }
    file_op touch "$@"
}

cmd_ln() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
cecho -b "用法: LN [系统参数] <源> <目标>"
cecho -c 90 "创建软链接请用 LN -s <源> <目标>"
        return 0
    fi
    [ $# -lt 2 ] && { err "用法: LN [系统参数] <源> <目标>"; return 1; }
    file_op link "$@"
}

# ------- 文件操作其他分支 -------
cmd_chmod() {
    if [ $# -eq 0 ]; then
        err "缺少参数, 使用 CHMOD --help 查看系统帮助"
        return 1
    fi

    if command -v chmod >/dev/null 2>&1; then
        chmod "$@" 2>&1 | while IFS= read -r line; do cecho "$line"; done
        return ${PIPESTATUS[0]}
    elif _bb_has chmod; then
        busybox chmod "$@" 2>&1 | while IFS= read -r line; do cecho "$line"; done
        return ${PIPESTATUS[0]}
    else
        err "未找到 chmod 命令"
        return 127
    fi
}

cmd_chown() {
    if [ $# -eq 0 ]; then
        err "缺少参数, 使用 CHOWN --help 查看系统帮助"
        return 1
    fi

    if command -v chown >/dev/null 2>&1; then
        chown "$@" 2>&1 | while IFS= read -r line; do cecho "$line"; done
        return ${PIPESTATUS[0]}
    elif _bb_has chown; then
        busybox chown "$@" 2>&1 | while IFS= read -r line; do cecho "$line"; done
        return ${PIPESTATUS[0]}
    else
        err "未找到 chown 命令"
        return 127
    fi
}

cmd_du() {
        if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -eq 0 ]; then
        cecho -b "用法: DU [目录]"
        cecho "示例: DU /storage/emulated/0"
        cecho "      DU .          # 当前目录"
        return 0
    fi
    if [ $# -gt 1 ]; then
        err "只能指定一个目录"
        return 1
    fi
    local target="$1"
    if [ -d "$target" ]; then
        local size_output
        size_output=$(du -sh "$target" 2>/dev/null)
        cecho "$size_output"
    else
        err "'$target' 不是目录"
        return 1
    fi
}

cmd_size() {
        if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -eq 0 ]; then
        cecho -b "用法: SIZE <文件>"
        return 0
    fi
    if [ $# -ne 1 ]; then
        err "参数错误, 使用 SIZE -h 查看帮助"
        return 1
    fi
    local target="$1"
    if [ -f "$target" ]; then
        local sz
        sz=$(du -sh "$target" 2>/dev/null)
        cecho "$sz"
    else
        err "'$target' 不是普通文件"
        return 1
    fi
}

cmd_dir() {
    if [ $# -eq 0 ]; then
        $_LS -l --color=auto 2>&1 | while IFS= read -r line; do cecho "$line"; done
    else
        for path in "$@"; do
            cecho "$path:"
            # 同样处理带参数的ls命令
            $_LS -l --color=auto "$path" 2>&1 | while IFS= read -r line; do cecho "$line"; done
            echo ""
        done
    fi
}

cmd_type() {
    [ $# -eq 0 ] && { err "命令语法不正确"; return; }
    for file in "$@"; do
        if [ -f "$file" ]; then
            $_CAT "$file" 2>&1 | while IFS= read -r line; do cecho "$line"; done
        else
            err "系统找不到指定的文件: $file"
        fi
    done
}

cmd_free() {
    $_FREE -h 2>&1 | while IFS= read -r line; do cecho "$line"; done
}

# 0.15NEW
# ---------- cat ----------
cmd_cat() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cecho -b "用法: CAT [参数] <文件1> [文件2...]"
        cecho "查看文件内容, 支持标准 cat 参数"
        return 0
    fi
    local has_file=0
    for arg in "$@"; do
        if [[ "$arg" != -* ]]; then
            has_file=1
            break
        fi
    done
    if [ $has_file -eq 0 ]; then
        err "缺少文件参数, 使用 CAT -h 查看帮助"
        return 1
    fi
    for arg in "$@"; do
        if [[ "$arg" != -* ]]; then
            if [ ! -f "$arg" ] && [ ! -c "$arg" ] && [ ! -b "$arg" ]; then
                err "文件不存在或不是普通文件: $arg"
                return 1
            fi
            if [ ! -r "$arg" ]; then
                err "文件不可读: $arg"
                return 1
            fi
        fi
    done
    if command -v cat >/dev/null 2>&1; then
        command cat "$@" 2>/dev/null | while IFS= read -r line; do
            cecho "$line"
        done
        local ret=${PIPESTATUS[0]}
        if [ $ret -ne 0 ]; then
            err "cat 执行失败(错误码 $ret)"
            return $ret
        fi
    else
        err "系统 cat 命令未找到"
        return 127
    fi
}

# ---------- head ----------
cmd_head() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cecho -b "用法: HEAD [-n N] [参数] <文件>"
        cecho "显示文件开头 N 行(默认10行)"
        return 0
    fi
    local has_file=0
    for arg in "$@"; do
        if [[ "$arg" != -* ]]; then
            has_file=1
            break
        fi
    done
    if [ $has_file -eq 0 ]; then
        err "缺少文件参数, 使用 HEAD -h 查看帮助"
        return 1
    fi
    for arg in "$@"; do
        if [[ "$arg" != -* ]]; then
            if [ ! -f "$arg" ]; then
                err "文件不存在: $arg"
                return 1
            fi
            if [ ! -r "$arg" ]; then
                err "文件不可读: $arg"
                return 1
            fi
        fi
    done
    if command -v head >/dev/null 2>&1; then
        command head "$@" 2>/dev/null | while IFS= read -r line; do
            cecho "$line"
        done
        local ret=${PIPESTATUS[0]}
        if [ $ret -ne 0 ]; then
            err "head 执行失败(错误码 $ret)"
            return $ret
        fi
    else
        err "系统 head 命令未找到"
        return 127
    fi
}

# ---------- tail ----------
cmd_tail() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cecho -b "用法: TAIL [-n N] [参数] <文件>"
        cecho "显示文件末尾 N 行(默认10行)"
        return 0
    fi
    local has_file=0
    for arg in "$@"; do
        if [[ "$arg" != -* ]]; then
            has_file=1
            break
        fi
    done
    if [ $has_file -eq 0 ]; then
        err "缺少文件参数, 使用 TAIL -h 查看帮助"
        return 1
    fi
    for arg in "$@"; do
        if [[ "$arg" != -* ]]; then
            if [ ! -f "$arg" ]; then
                err "文件不存在: $arg"
                return 1
            fi
            if [ ! -r "$arg" ]; then
                err "文件不可读: $arg"
                return 1
            fi
        fi
    done
    if command -v tail >/dev/null 2>&1; then
        command tail "$@" 2>/dev/null | while IFS= read -r line; do
            cecho "$line"
        done
        local ret=${PIPESTATUS[0]}
        if [ $ret -ne 0 ]; then
            err "tail 执行失败(错误码 $ret)"
            return $ret
        fi
    else
        err "系统 tail 命令未找到"
        return 127
    fi
}

# ---------- dd ----------
cmd_dd() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cecho -b "用法: DD [参数]"
        cecho "复制并转换文件(危险)"
        return 0
    fi
    if [ $# -eq 0 ]; then
        err "缺少参数, 使用 DD -h 查看帮助"
        return 1
    fi
    local has_if=0 has_of=0
    for arg in "$@"; do
        [[ "$arg" == if=* ]] && has_if=1
        [[ "$arg" == of=* ]] && has_of=1
    done
    if [ $has_if -eq 0 ] || [ $has_of -eq 0 ]; then
        err "至少需要指定 if= 和 of= 参数"
        return 1
    fi
    if ! confirm "执行 dd 命令可能损坏数据, 确认继续吗"; then
        return 0
    fi
    if command -v dd >/dev/null 2>&1; then
        dd "$@"
        local ret=$?
        if [ $ret -ne 0 ]; then
            err "dd 执行失败(错误码 $ret)"
        else
            cecho "dd 执行完成"
        fi
        return $ret
    else
        err "dd 命令未找到"
        return 127
    fi
}

# ---------- MOUNT：挂载文件系统 ----------
cmd_mount() {
    if [[ "$1" == "-h" || "$1" == "--help" ]] || [ $# -lt 2 ]; then
        cecho -b "用法: MOUNT <设备> <挂载点> [参数]"
        cecho "挂载文件系统(通常需要 root 权限)"
        cecho "示例: MOUNT /dev/block/sda1 /mnt/usb"
        return 0
    fi

    if [ "$(id -u)" -ne 0 ]; then
        err "挂载操作需要 root 权限"
        return 1
    fi

    local device="$1"
    local mountpoint="$2"
    shift 2
    local opts="$*"

    if [ ! -b "$device" ] && [ ! -c "$device" ]; then
        err "设备不存在或不是块/字符设备: $device"
        return 1
    fi

    # 检查挂载点是否存在
    if [ ! -d "$mountpoint" ]; then
        if ! confirm "挂载点 $mountpoint 不存在, 是否创建"; then
            return 0
        fi
        mkdir -p "$mountpoint" || { err "无法创建挂载点"; return 1; }
    fi

    # 检查设备是否已经挂载
    if mount | grep -q "^$device "; then
        err "设备 $device 已经挂载"
        return 1
    fi

    if ! confirm "确定要挂载 $device 到 $mountpoint 吗"; then
        return 0
    fi

    mount "$device" "$mountpoint" $opts
    local ret=$?
    if [ $ret -eq 0 ]; then
        cecho "挂载成功"
    else
        err "挂载失败(错误码 $ret)"
    fi
    return $ret
}

# ---------- UMOUNT：卸载文件系统 ----------
cmd_umount() {
    if [[ "$1" == "-h" || "$1" == "--help" ]] || [ $# -eq 0 ]; then
        cecho -b "用法: UMOUNT <设备或挂载点>"
        cecho "卸载文件系统(通常需要 root 权限)"
        cecho "示例: UMOUNT /mnt/usb  或  UMOUNT /dev/block/sda1"
        return 0
    fi

    if [ "$(id -u)" -ne 0 ]; then
        err "卸载操作需要 root 权限"
        return 1
    fi

    local target="$1"

    # 检查目标是否已挂载
    if ! mount | grep -q " $target " && ! mount | grep -q "^$target "; then
        err "未找到挂载点或设备: $target"
        return 1
    fi

    if ! confirm "确定要卸载 $target 吗?"; then
        return 0
    fi

    umount "$target"
    local ret=$?
    if [ $ret -eq 0 ]; then
        cecho "卸载成功"
    else
        err "卸载失败(错误码 $ret)"
    fi
    return $ret
}

# ---------- FORMAT：格式化存储设备 ----------
cmd_format() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cecho -b "用法: FORMAT <设备路径> [文件系统类型]"
        cecho "格式化存储设备(危险操作, 所有数据将被清除)"
        cecho "支持的文件系统类型(根据系统工具自动检测)："
        cecho "  vfat, ext4, f2fs, ntfs, exfat 等"
        cecho "示例: FORMAT /dev/block/mmcblk1p1 ext4"
        cecho "      FORMAT /dev/block/sda1         # 将交互选择类型"
        return 0
    fi

    if [ "$(id -u)" -ne 0 ]; then
        err "格式化操作需要 root 权限"
        return 1
    fi

    if [ $# -lt 1 ]; then
        err "缺少设备路径参数, 使用 FORMAT -h 查看帮助"
        return 1
    fi

    local device="$1"
    local fstype="$2"

    if [ ! -b "$device" ] && [ ! -c "$device" ]; then
        err "设备不存在或不是块/字符设备: $device"
        return 1
    fi

    # 检查设备是否已挂载
    local mount_point=$(mount | grep -E "^$device " | awk '{print $3}' | head -1)
    if [ -n "$mount_point" ]; then
        err "设备 $device 已挂载到 $mount_point, 请先卸载"
        err "使用: UMOUNT $device"
        return 1
    fi

    # 检测可用的格式化工具
    local tools=()
    local tool_map=()
    local candidates=(
        "mkfs.vfat:vfat"
        "mkfs.ext4:ext4"
        "mkfs.f2fs:f2fs"
        "mkfs.ntfs:ntfs"
        "mkfs.exfat:exfat"
        "make_ext4fs:ext4"
        "mke2fs:ext4"
    )
    for entry in "${candidates[@]}"; do
        local tool="${entry%:*}"
        local type="${entry#*:}"
        if command -v "$tool" >/dev/null 2>&1; then
            tools+=("$tool")
            tool_map["$tool"]="$type"
        fi
    done

    if [ ${#tools[@]} -eq 0 ]; then
        err "未找到任何可用的格式化工具(mkfs.* 或 make_ext4fs)"
        return 127
    fi

    # 确定文件系统类型
    local selected_tool=""
    if [ -z "$fstype" ]; then
        cecho "可用的文件系统类型："
        local idx=1
        local type_list=()
        for t in "${tools[@]}"; do
            local label="${tool_map[$t]}"
            cecho "  $idx) $label (工具: $t)"
            type_list+=("$t")
            ((idx++))
        done
        echo ""
        read -p "请选择编号 (1-${#type_list[@]}): " choice
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#type_list[@]}" ]; then
            err "无效选择"
            return 1
        fi
        selected_tool="${type_list[$((choice-1))]}"
        fstype="${tool_map[$selected_tool]}"
    else
        local found=0
        for entry in "${candidates[@]}"; do
            local tool="${entry%:*}"
            local type="${entry#*:}"
            if [ "$type" == "$fstype" ] && command -v "$tool" >/dev/null 2>&1; then
                found=1
                selected_tool="$tool"
                break
            fi
        done
        if [ $found -eq 0 ]; then
            err "不支持的文件系统类型 '$fstype' 或未找到对应工具"
            return 1
        fi
    fi

    # 最终确认
    cecho -c 31 -b "警告：将格式化设备 $device, 所有数据将永久丢失!"
    echo ""
    if ! confirm "确认格式化操作?一旦开始则不可终止"; then
        return 0
    fi

    # 执行格式化(数组传参, 无 eval, 避免命令注入)
    cecho "正在格式化 $device 为 $fstype ..."
    local -a fmt_cmd
    case "$selected_tool" in
        mkfs.vfat)        fmt_cmd=("$selected_tool" -F 32 "$device") ;;
        mkfs.ext4|mke2fs) fmt_cmd=("$selected_tool" -F "$device") ;;
        mkfs.f2fs)        fmt_cmd=("$selected_tool" -f "$device") ;;
        mkfs.ntfs)        fmt_cmd=("$selected_tool" -f -Q "$device") ;;
        mkfs.exfat)       fmt_cmd=("$selected_tool" -f "$device") ;;
        make_ext4fs)      fmt_cmd=("$selected_tool" "$device") ;;
        *) err "未知工具 $selected_tool"; return 1 ;;
    esac

    if "${fmt_cmd[@]}"; then
        cecho -c 92 "格式化成功完成"
        return 0
    else
        local ret=$?
        err "格式化失败(错误码 $ret)"
        return $ret
    fi
}
# 0.15NEW Finish
# 0.20NEW start
# ---------- awk包装 ----------
cmd_awk() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cecho -b "用法: AWK [参数] '程序' [文件...]"
        cecho "执行 awk 程序, 输出结果逐行着色"
        return 0
    fi
    local output
    output=$($_AWK "$@" 2>&1)
    local ret=$?
    if [ $ret -ne 0 ]; then
        err "awk 执行失败 (错误码 $ret):"
        err "$output"
        return $ret
    else
        echo "$output" | while IFS= read -r line; do
            cecho "$line"
        done
        return 0
    fi
}

# ---------- grep包装 ----------
cmd_grep() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cecho -b "用法: GREP [参数] 模式 [文件...]"
        cecho "在文件或标准输入中搜索模式(保留颜色输出)"
        return 0
    fi
    local output
    output=$($_GREP "$@" 2>&1)
    local ret=$?
    if [ $ret -ne 0 ]; then
        # grep 返回 1 表示未找到, 不算错误
        if [ $ret -eq 1 ]; then
            echo "$output" | while IFS= read -r line; do
                cecho "$line"
            done
            return 1
        else
            err "grep 执行失败 (错误码 $ret):"
            err "$output"
            return $ret
        fi
    else
        echo "$output" | while IFS= read -r line; do
            cecho "$line"
        done
        return 0
    fi
}

# ---------- sed包装 ----------
cmd_sed() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cecho -b "用法: SED [参数] '脚本' [文件...]"
        cecho "执行 sed 流编辑器, 输出逐行着色"
        return 0
    fi
    local output
    output=$($_SED "$@" 2>&1)
    local ret=$?
    if [ $ret -ne 0 ]; then
        err "sed 执行失败 (错误码 $ret):"
        err "$output"
        return $ret
    else
        echo "$output" | while IFS= read -r line; do
            cecho "$line"
        done
        return 0
    fi
}

# ---------- cut包装 ----------
cmd_cut() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cecho -b "用法: CUT [参数] [文件...]"
        cecho "按列或字段截取文本, 输出逐行着色"
        return 0
    fi
    local output
    output=$($_CUT "$@" 2>&1)
    local ret=$?
    if [ $ret -ne 0 ]; then
        err "cut 执行失败 (错误码 $ret):"
        err "$output"
        return $ret
    else
        echo "$output" | while IFS= read -r line; do
            cecho "$line"
        done
        return 0
    fi
}
# 0.20NEW Finish

cmd_cpumonitor() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cecho -b "用法: CPUMONITOR"
        cecho "实时显示每个CPU核心的当前频率(按Ctrl+C退出)"
        return 0
    fi

    # 获取核心数量
    local cores=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo)
    if [ -z "$cores" ] || [ "$cores" -eq 0 ]; then
        err "无法获取 CPU 核心数量"
        return 1
    fi

    # 先建立核心与频率文件路径的映射(与 systeminfo 一致)
    local core_paths=()
    local core_indices=()
    for cpu_dir in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
        if [ -d "$cpu_dir" ] && [ -r "$cpu_dir/scaling_cur_freq" ]; then
            core=$(basename $(dirname "$cpu_dir"))  # 得到 cpu0, cpu1, ...
            core_num=${core#cpu}                    # 提取数字
            core_paths[$core_num]="$cpu_dir/scaling_cur_freq"
            core_indices+=($core_num)
        fi
    done

    # 如果没有任何核心可读, 报错退出
    if [ ${#core_indices[@]} -eq 0 ]; then
        err "未找到可读取频率的 CPU 核心"
        return 1
    fi

    # 按数字排序核心索引(保证输出顺序)
    local sorted_indices=($(printf '%s\n' "${core_indices[@]}" | sort -n))

    # 保存旧的 INT trap, 设置自己的
    local old_trap=$(trap -p INT)
    local stop=0
    trap 'stop=1' INT

    cecho "按Ctrl+C退出CPU监控"
    cecho "$CMD_delimiter"

    # 预输出占位行(每个核心一行)
    for idx in "${sorted_indices[@]}"; do
        echo
    done

    while [ $stop -eq 0 ]; do
        # 回退到起始位置
        printf "\033[${#sorted_indices[@]}A"

        for idx in "${sorted_indices[@]}"; do
            local freq_path="${core_paths[$idx]}"
            local freq_display="N/A"
            if [ -n "$freq_path" ] && [ -r "$freq_path" ]; then
                local raw=$($_CAT "$freq_path" 2>/dev/null | tr -d '\n\r')
                if [ -n "$raw" ] && [ "$raw" -gt 0 ] 2>/dev/null; then
                    # 转换为 MHz, 保留一位小数(与 systeminfo 一致)
                    freq_display=$(awk "BEGIN {printf \"%.1f MHz\", $raw/1000}" 2>/dev/null)
                    [ -z "$freq_display" ] && freq_display="$((raw/1000)) MHz"
                else
                    freq_display="offline"
                fi
            else
                freq_display="offline"
            fi
            printf "\r\033[KCPU$idx: %s\n" "$freq_display"
        done

        # 等待 0.5 秒, 可被中断
        sleep 0.5
    done

    # 退出时清空所有行并恢复光标
    printf "\033[${#sorted_indices[@]}A"
    for idx in "${sorted_indices[@]}"; do
        printf "\033[K\n"
    done
    printf "\033[${#sorted_indices[@]}A"

    # 恢复原来的 trap
    eval "$old_trap" 2>/dev/null || trap - INT
    cecho "已退出 CPU 监控"
    return 0
}

# 温度读取辅助: 参数 传感器路径, 默认显示值
_read_temp() {
    local sensor_path="$1"
    local default_display="$2"
    if [ -n "$sensor_path" ] && [ -r "$sensor_path" ]; then
        local temp_raw=$($_CAT "$sensor_path" 2>/dev/null | tr -d '\n\r')
        if [ -n "$temp_raw" ]; then
            local temp_c
            if [ "$temp_raw" -gt 1000 ] 2>/dev/null; then
                temp_c=$(echo "scale=1; $temp_raw / 1000" | bc 2>/dev/null 2>/dev/null || echo "$((temp_raw / 1000))")
            else
                temp_c="$temp_raw"
            fi
            if echo "$temp_c" | awk -v t="$temp_c" 'BEGIN {if (t > 5 && t < 120) exit 0; else exit 1}' 2>/dev/null; then
                echo "${temp_c}°C"
                return
            fi
        fi
    fi
    echo "$default_display"
}

cmd_monitor() {
    cecho "正在监控时间、内存和温度(按Ctrl+C终止)"
    cecho "$CMD_delimiter"
    
    local saved_bg=$BG
    local saved_fg=$FG
    local stop_monitor=0
    
    # 保存旧的 INT trap, 设置自己的
    local old_trap=$(trap -p INT)
    trap 'stop_monitor=1' INT
    
    # ---------- 1. 定义关键温度传感器路径 ----------
    local thermal_base="/sys/class/thermal"
    local cpu_sensor_path=""
    local gpu_sensor_path=""
    local battery_sensor_path=""
    
    if [ -d "$thermal_base" ]; then
        for zone in "$thermal_base"/thermal_zone*; do
            if [ -d "$zone" ]; then
                local type_file="$zone/type"
                local temp_file="$zone/temp"
                if [ -r "$type_file" ] && [ -r "$temp_file" ]; then
                    local sensor_type=$($_CAT "$type_file" 2>/dev/null | tr -d '\n\r')
                    case "$sensor_type" in
                        cpu-0-0|cpuss-0|cpu-0-1|cpuss-1|cpu-1-0)
                            if [ -z "$cpu_sensor_path" ]; then
                                cpu_sensor_path="$temp_file"
                            fi
                            ;;
                        gpuss-0|gpuss-1|gpu)
                            if [ -z "$gpu_sensor_path" ]; then
                                gpu_sensor_path="$temp_file"
                            fi
                            ;;
                        battery)
                            battery_sensor_path="$temp_file"
                            ;;
                    esac
                fi
            fi
        done
    fi
    
    if [ -z "$battery_sensor_path" ] && [ -r "/sys/class/power_supply/battery/temp" ]; then
        battery_sensor_path="/sys/class/power_supply/battery/temp"
    fi

    # ---------- 2. 先输出三行占位 ----------
    printf "\n\n\n"
    
    # ---------- 3. 主显示循环 ----------
    while [ $stop_monitor -eq 0 ]; do
        # 3.1 获取当前时间
        local current_time=$($_DATE "+%Y-%m-%d %a %H:%M:%S")
        
        # 3.2 获取内存信息
        local mem_total_kb mem_free_kb buffers_kb cached_kb
        mem_total_kb=$($_GREP -E '^MemTotal:' /proc/meminfo 2>/dev/null | $_AWK '{print $2}')
        mem_free_kb=$($_GREP -E '^MemFree:' /proc/meminfo 2>/dev/null | $_AWK '{print $2}')
        buffers_kb=$($_GREP -E '^Buffers:' /proc/meminfo 2>/dev/null | $_AWK '{print $2}')
        cached_kb=$($_GREP -E '^Cached:' /proc/meminfo 2>/dev/null | $_AWK '{print $2}')
        
        [ -z "$mem_total_kb" ] && mem_total_kb=0
        [ -z "$mem_free_kb" ] && mem_free_kb=0
        [ -z "$buffers_kb" ] && buffers_kb=0
        [ -z "$cached_kb" ] && cached_kb=0
        
        local mem_used_kb=$((mem_total_kb - mem_free_kb - buffers_kb - cached_kb))
        [ $mem_used_kb -lt 0 ] && mem_used_kb=0
        
        local mem_total_mb=$((mem_total_kb / 1024))
        local mem_used_mb=$((mem_used_kb / 1024))
        
        local percent=0
        if [ $mem_total_mb -gt 0 ]; then
            percent=$(( (mem_used_mb * 100) / mem_total_mb ))
        fi
        
        # 3.3 读取温度
        local cpu_temp=$(_read_temp "$cpu_sensor_path" "N/A")
        local gpu_temp=$(_read_temp "$gpu_sensor_path" "N/A")
        local bat_temp=$(_read_temp "$battery_sensor_path" "N/A")
        
        # ---------- 4. 原地刷新三行 ----------
        printf "\033[3A"
        
        printf "\r\033[K"
        _cprint -c 92 "实时时钟: $current_time"
        
        printf "\r\033[K"
        _cprint -c 93 "内存使用率: $percent%   已用: ${mem_used_mb}M / 总共: ${mem_total_mb}M"
        
        printf "\r\033[K"
        _cprint -c 96 -n "CPU: ${cpu_temp:-N/A}  "
        _cprint -c 95 -n "GPU: ${gpu_temp:-N/A}  "
        _cprint -c 92 "Battery: ${bat_temp:-N/A}"
        
        # 5. 精确等待到下一秒
        if [ $stop_monitor -eq 0 ]; then
            local now_ms
            if date +%s%N >/dev/null 2>&1; then
                now_ms=$(date +%s%N | $_CUT -b1-13 2>/dev/null)
            else
                now_ms=$(date +%s)000
            fi
            
            if [ -n "$now_ms" ]; then
                local current_second=$((now_ms % 1000))
                local sleep_ms=$((1000 - current_second))
                if [ $sleep_ms -gt 0 ]; then
                    local sleep_sec=$(echo "scale=3; $sleep_ms / 1000" | bc 2>/dev/null)
                    if [ -n "$sleep_sec" ]; then
                        sleep $sleep_sec 2>/dev/null || true
                    else
                        sleep 1
                    fi
                fi
            else
                sleep 1
            fi
        fi
    done
    
    # 退出时,清空最后三行并换行
    printf "\033[3A\033[K\n\033[K\n\033[K\n"
    BG=$saved_bg
    FG=$saved_fg
    echo ""
    cecho "已退出监控"
    
    # 恢复旧的 trap
    eval "$old_trap" 2>/dev/null
    return 0
}

cmd_clock() {
    local colors=(31 32 33 34 35 36 37)
    local color_index=0
    local stop=0
    local last_color_time=$(date +%s)

    # 保存旧的 trap, 设置自己的 INT 处理
    local old_trap=$(trap -p INT)
    trap 'stop=1' INT

    cecho "(按Ctrl+C退出时钟显示)"
    cecho "$CMD_delimiter"
    while [ $stop -eq 0 ]; do
        local time_str=$(date "+%Y-%m-%d %a %H:%M:%S")
        local color=${colors[$color_index]}
        printf "\r\033[K\033[1;%sm实时时钟: [%s]\033[0m" "$color" "$time_str"

        local now=$(date +%s)
        if [ $((now - last_color_time)) -ge 1 ]; then
            color_index=$(( (color_index + 1) % ${#colors[@]} ))
            last_color_time=$now
        fi

        sleep 0.1
    done

    printf "\r\033[K\n"
    cecho "时钟已退出"

    # 恢复旧的 trap
    eval "$old_trap" 2>/dev/null
}

cmd_ulimit() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    err "此汉化帮助可能和您的系统参数不同, 仅供参考, 更多信息请使用ULIMIT -a"
        ccat << "EOF"
//cecho -b "用法: ULIMIT [参数] [限制值]"
显示或设置当前 Shell 进程的资源限制

//cecho -b "参数:"
  -a              显示所有当前限制
  -S              软限制 (默认)
  -H              硬限制
  -c <KB>         核心文件大小
  -d <KB>         数据段大小
  -f <KB>         文件大小
  -l <KB>         锁定内存大小
  -n <数量>       文件描述符数量
  -s <KB>         栈大小
  -t <秒>         CPU 时间
  -u <数量>       最大用户进程数
  -v <KB>         虚拟内存大小

//cecho -b "示例:"
  ULIMIT              # 显示所有软限制 (同 -S -a)
  ULIMIT -a           # 显示所有限制
  ULIMIT -u 1024      # 将最大用户进程数设为 1024
  ULIMIT -n 4096      # 将最大文件描述符设为 4096
  ULIMIT -H -u        # 显示硬限制的最大用户进程数
EOF
        return 0
    fi

    if [[ $# -eq 0 ]]; then
        ulimit -S -a
        return $?
    fi

    ulimit "$@"
    local ret=$?
    if [[ $ret -ne 0 ]]; then
        err "无效参数或参数"
    fi
    return $ret
}

cmd_getprop() {
    if ! command -v getprop >/dev/null 2>&1; then
        err "getprop 命令未找到(可能非 Android 环境)"
        return 1
    fi
    if [ $# -eq 0 ]; then
        # 无参数: 分页显示所有属性
        if command -v more >/dev/null 2>&1; then
            getprop | more
        else
            getprop | while IFS= read -r line; do cecho "$line"; done
        fi
    else
        # 有参数: 显示指定属性值
        local key="$1"
        local value
        value=$(getprop "$key" 2>/dev/null)
        if [ -n "$value" ]; then
            cecho "$value"
        else
            cecho "[空]"
        fi
    fi
}

# ---------- PATH 段管理 ----------
cmd_path() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        cecho -b "用法: PATH [子命令]"
        ccat << "EOF"
  (无参数)/ls                列出 PATH 各段(带编号)
  -r, --raw                  原样输出 PATH 字符串(不编号)
  add <目录...>              追加到末尾
  add <序号> <目录...>       插到正序第 <序号> 位 (1=最前)
  add -f <目录...>           插入到最前面
  add -f <序号> <目录...>    从末尾倒数第 <序号> 位 (1=最末尾)
  del <编号|目录...>         删除指定段(可混用)
  clean                      去重+删除不存在的目录
  set <值>                   整体替换(危险)
  -h, --help                 显示本帮助
EOF
        return 0
    fi

    # 顶层 -r: 原样输出
    if [ "$1" = "-r" ] || [ "$1" = "--raw" ]; then
        cecho "$PATH"
        return 0
    fi

    case "$1" in
        ""|ls|list|show)
            local i=1 p
            local IFS=':'
            for p in $PATH; do
                if [ -z "$p" ]; then
                    cecho "  $i. <空(表示当前目录)>"
                else
                    cecho "  $i. $p"
                fi
                ((i++))
            done
            ;;

        add)
            shift
            local reverse=0
            if [ "$1" = "-f" ] || [ "$1" = "--reverse" ]; then
                reverse=1; shift
            fi

            local pos=""
            if [[ "${1:-}" =~ ^[0-9]+$ ]]; then
                pos="$1"; shift
            fi

            [ $# -eq 0 ] && { err "用法: PATH add [-f] [序号] <目录...>"; return 1; }

            local -a _arr=()
            local IFS=':'
            read -ra _arr <<< "$PATH"
            unset IFS
            local L=${#_arr[@]}

            local dir
            for dir in "$@"; do
                # 去重
                local exists=0 j
                for j in "${_arr[@]}"; do
                    [ "$j" = "$dir" ] && { exists=1; break; }
                done
                if [ $exists -eq 1 ]; then
                    cecho "已存在, 跳过: $dir"
                    continue
                fi

                # 计算插入索引(0 起算)
                local idx
                if [ -z "$pos" ]; then
                    if [ "$reverse" -eq 1 ]; then
                        idx=0     # -f 无序号 = 最前
                    else
                        idx=$L   # 无 -f 无序号 = 末尾
                    fi
                elif [ "$reverse" -eq 1 ]; then
                    idx=$((L - pos + 1))    # -f N: 从末尾倒数第 N 位
                    [ $idx -lt 0 ] && idx=0
                    [ $idx -gt $L ] && idx=$L
                else
                    idx=$((pos - 1))      # N: 正序第 N 位
                    [ $idx -lt 0 ] && idx=0
                    [ $idx -gt $L ] && idx=$L
                fi

                if [ $idx -eq 0 ]; then
                    _arr=("$dir" "${_arr[@]}")
                elif [ $idx -ge $L ]; then
                    _arr+=("$dir")
                    idx=$L
                else
                    _arr=("${_arr[@]:0:$idx}" "$dir" "${_arr[@]:$idx}")
                fi
                L=$((L + 1))
                cecho "已添加: $dir (位置 $((idx + 1)))"
            done

            local joined="" s
            for s in "${_arr[@]}"; do
                joined="${joined:+$joined:}$s"
            done
            export PATH="$joined"
            ;;

        del|rm|remove)
            shift
            [ $# -eq 0 ] && { err "用法: PATH del <编号|目录...>"; return 1; }

            local -a _arr=()
            local IFS=':'
            read -ra _arr <<< "$PATH"
            unset IFS

            # 收集要删除的索引(从 0 起算)
            local -A _todel=()
            local arg
            for arg in "$@"; do
                if [[ "$arg" =~ ^[0-9]+$ ]]; then
                    local idx=$((arg - 1))
                    if [ $idx -lt 0 ] || [ $idx -ge ${#_arr[@]} ]; then
                        err "编号越界: $arg"; continue
                    fi
                    _todel[$idx]=1
                else
                    local found=0 j
                    for j in "${!_arr[@]}"; do
                        if [ "${_arr[$j]}" = "$arg" ]; then
                            _todel[$j]=1; found=1
                        fi
                    done
                    [ $found -eq 0 ] && err "未找到: $arg"
                fi
            done

            # 重建
            local -a _new=()
            local i
            for i in "${!_arr[@]}"; do
                if [ -z "${_todel[$i]:-}" ]; then
                    _new+=("${_arr[$i]}")
                else
                    cecho "已删除: ${_arr[$i]}"
                fi
            done

            local joined="" s
            for s in "${_new[@]}"; do
                joined="${joined:+$joined:}$s"
            done
            export PATH="$joined"
            ;;

        clean)
            local -a _arr=() _new=()
            local IFS=':'
            read -ra _arr <<< "$PATH"
            unset IFS

            local -A _seen=()
            local seg removed=0
            for seg in "${_arr[@]}"; do
                if [ -z "$seg" ] || [ ! -d "$seg" ] || [ -n "${_seen[$seg]:-}" ]; then
                    ((removed++))
                    continue
                fi
                _seen[$seg]=1
                _new+=("$seg")
            done

            local joined="" s
            for s in "${_new[@]}"; do
                joined="${joined:+$joined:}$s"
            done
            export PATH="$joined"
            cecho "已清理, 移除 $removed 段 (剩 ${#_new[@]} 段)"
            ;;

        set)
            shift
            [ -z "${1:-}" ] && { err "用法: PATH set <值>"; return 1; }
            if confirm "确定替换 PATH? (可能导致莫名其妙的问题)"; then
                export PATH="$1"
                cecho "PATH 已更新"
            fi
            ;;

        *)
            err "未知子命令: $1, 使用 PATH -h 查看帮助"
            return 1
            ;;
    esac
}

# ---------- ENV search ----------
# 用法: ENV search [-n|-v] [-C] [-f] <字符串>
#   -n  只匹配变量名
#   -v  只匹配变量值
#   无  两者都匹配
#   -C  区分大小写(默认不区分), 与 -f 互斥
#   -f  正则表达式模式(默认固定子串)
_env_search() {
    local mode="all"
    local case_sensitive=0
    local use_regex=0

    while [ $# -gt 0 ]; do
        case "$1" in
            -n|--name)  mode="name";  shift ;;
            -v|--value) mode="value"; shift ;;
            -C)         case_sensitive=1; shift ;;
            -f)         use_regex=1; shift ;;
            --) shift; break ;;
            -*) err "未知参数: $1, 使用 ENV -h 查看帮助"; return 1 ;;
            *) break ;;
        esac
    done

    if [ $# -eq 0 ] || [ -z "$1" ]; then
        err "用法: ENV search [-n|-v] [-C] [-f] <字符串>"
        return 1
    fi

    # -C 与 -f 互斥
    if [ $use_regex -eq 1 ] && [ $case_sensitive -eq 1 ]; then
        err "-C 与 -f 冲突: 正则模式下大小写由正则本身控制"
        return 1
    fi

    local pat="$1" idx=0

    # 仅固定子串模式使用 nocasematch
    local _old_nocasematch=""
    if [ $use_regex -eq 0 ]; then
        _old_nocasematch=$(shopt -p nocasematch 2>/dev/null)
        if [ $case_sensitive -eq 0 ]; then
            shopt -s nocasematch
        else
            shopt -u nocasematch
        fi
    fi

    while IFS= read -r name; do
        [ -z "$name" ] && continue
        local val="${!name}"
        local match=0

        if [ $use_regex -eq 1 ]; then
            case "$mode" in
                name)  [[ "$name" =~ $pat ]] && match=1 ;;
                value) [[ "$val"  =~ $pat ]] && match=1 ;;
                all)
                    [[ "$name" =~ $pat ]] && match=1
                    [[ "$val"  =~ $pat ]] && match=1
                    ;;
            esac
        else
            case "$mode" in
                name)  [[ "$name" == *"$pat"* ]] && match=1 ;;
                value) [[ "$val"  == *"$pat"* ]] && match=1 ;;
                all)
                    [[ "$name" == *"$pat"* ]] && match=1
                    [[ "$val"  == *"$pat"* ]] && match=1
                    ;;
            esac
        fi
        [ $match -eq 0 ] && continue

        ((idx++))
        printf '  %3d. %s=%s\n' "$idx" "$name" "$val"
    done < <(export -p 2>/dev/null \
             | $_SED -n 's/^declare -x \([A-Za-z_][A-Za-z0-9_]*\).*/\1/p')

    # 恢复原状态
    if [ -n "$_old_nocasematch" ]; then
        eval "$_old_nocasematch" 2>/dev/null
    fi

    if [ $idx -eq 0 ]; then
        cecho "无匹配: $pat"
        return 1
    fi
    cecho -c 90 "共匹配 $idx 个变量"
}

# ---------- ENV ----------
cmd_env() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        ccat << "EOF"
//cecho -b "用法:"
    ENV [ls] [KEY]           显示所有环境变量(或指定变量)"
    ENV set KEY=VALUE        设置环境变量(也支持 KEY VALUE 空格格式)
    ENV unset KEY            删除环境变量
    ENV search [-n|-v] [-C] [-f] <字符串>   搜索变量
    -n 搜KEY, -v 搜VALUE, 默认两者
    -C 区分大小写(默认不区分)
    -f 正则表达式模式(与-C互斥)(默认固定子串)
EOF
        return 0
    fi

    if [ $# -eq 0 ]; then
        set -- ls
    fi

    local subcmd="$1"
    shift

    case "$subcmd" in
        ls|"")
            if [ $# -gt 0 ]; then
                if [ -z "$1" ]; then
                    err "变量名不能为空"
                    return 1
                fi
                if [ -z "${!1+x}" ]; then
                    err "未找到环境变量: $1"
                    return 1
                fi
                _cprint -c 36 -n "$1"
                _cprint -c 90 -n "="
                printf '%s\n' "${!1}"
            else
                if command -v env >/dev/null 2>&1; then
                    env | $_SORT | while IFS='=' read -r k v; do
                        _cprint -c 36 -n "$k"
                        _cprint -c 90 -n "="
                        printf '%s\n' "$v"
                    done
                else
                    err "无法显示环境变量"
                    return 1
                fi
            fi
            ;;

        set)
            if [ $# -eq 0 ]; then
                err "用法: ENV set KEY=VALUE 或 ENV set KEY VALUE"
                return 1
            fi
            local key value
            if [[ "$1" == *=* ]]; then
                key="${1%%=*}"; value="${1#*=}"
            else
                if [ $# -lt 2 ]; then
                    err "用法: ENV set KEY VALUE"
                    return 1
                fi
                key="$1"; value="$2"
            fi
            if ! [[ "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                err "无效的环境变量名: $key"
                return 1
            fi
            export "$key=$value"
            cecho "已设置环境变量: $key=$value"
            ;;

        unset)
            if [ $# -eq 0 ]; then
                err "用法: ENV unset KEY"
                return 1
            fi
            local key="$1"
            if ! [[ "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                err "无效的环境变量名: $key"
                return 1
            fi
            if unset "$key" 2>/dev/null; then
                cecho "已删除环境变量: $key"
            else
                err "无法删除环境变量: $key"
                return 1
            fi
            ;;

        search)
            _env_search "$@"
            ;;

        *)
            err "未知子命令: $subcmd"
            cecho "使用 ENV -h 查看帮助"
            return 1
            ;;
    esac
}

# ---------- 列出 PATH 中的可执行文件 ----------
cmd_exts() {
    local only_ext=0
    local dirs_only=0
    local show_path=0
    local count_only=0
    local search=""
    local scan_dir=""

    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                cecho -b "用法: EXTS [参数] [目录]"
                cecho "列出可执行文件, 无目录时扫描 \$PATH"
                cecho -b "参数"
                cecho "  -e, --ext             只显示扩展目录(排除 /system 等系统目录)"
                cecho "  -d, --dirs            只显示目录路径, 不列出文件"
                cecho "  -p, --path            显示完整路径"
                cecho "  -c, --count           只显示数量统计"
                cecho "  -s, --search <关键词>  过滤包含关键词的命令"
                cecho "  -h, --help            显示帮助"
                return 0 ;;
            -e|--ext)    only_ext=1; shift ;;
            -d|--dirs)   dirs_only=1; shift ;;
            -p|--path)   show_path=1; shift ;;
            -c|--count)  count_only=1; shift ;;
            -s|--search)
                if [ $# -lt 2 ]; then err "参数 -s 需要关键词"; return 1; fi
                search="$2"; shift 2 ;;
            --) shift; break ;;
            -*)
                err "未知参数: $1, 使用 EXTS -h 查看帮助"
                return 1 ;;
            *)
                if [ -n "$scan_dir" ]; then
                    err "只能指定一个目录"
                    return 1
                fi
                scan_dir="$1"; shift ;;
        esac
    done

    # 确定要扫描的目录列表
    local -a dirs=()
    if [ -n "$scan_dir" ]; then
        if [ ! -d "$scan_dir" ]; then
            err "目录不存在: $scan_dir"
            return 1
        fi
        dirs=("$scan_dir")
    else
        local IFS=':'
        dirs=($PATH)
        unset IFS
    fi

    # 系统目录前缀(视为系统命令)
    _exts_is_sys() {
        local d="$1"
        case "$d" in
            /system|/system/*|/vendor|/vendor/*|/apex|/apex/*|\
            /product|/product/*|/odm|/odm/*|/sbin|/sbin/*|\
            /data/adb/magisk|/data/adb/magisk/*|/data/adb/ksu|/data/adb/ksu/*)
                return 0 ;;
        esac
        return 1
    }

    local total=0
    local dir
    for dir in "${dirs[@]}"; do
        [ -z "$dir" ] && continue
        [ -d "$dir" ] || continue
        if [ $only_ext -eq 1 ] && _exts_is_sys "$dir"; then
            continue
        fi

        # 收集该目录下的可执行文件(含隐藏文件, 与 command -v 行为一致)
        local -a names=()
        local f bn
        shopt -s dotglob nullglob
        for f in "$dir"/*; do
            [ -e "$f" ] || continue
            [ -x "$f" ] || continue
            [ -f "$f" ] || continue
            bn="${f##*/}"
            if [ -n "$search" ]; then
                [[ "$bn" == *"$search"* ]] || continue
            fi
            names+=("$bn")
        done
        shopt -u dotglob nullglob

        [ ${#names[@]} -eq 0 ] && continue

        # 排序去重
        local sorted
        if command -v sort >/dev/null 2>&1; then
            sorted=$(printf '%s\n' "${names[@]}" | sort -u)
        else
            sorted=$(printf '%s\n' "${names[@]}")
        fi

        local n
        n=$(printf '%s\n' "$sorted" | awk 'END{print NR+0}')
        total=$((total + n))

        if [ $count_only -eq 1 ]; then
            continue
        fi

        if [ $dirs_only -eq 1 ]; then
            _cprint -c 96 "$dir/  ($n)"
            continue
        fi

        # 标题: 系统目录 / 扩展目录
        if _exts_is_sys "$dir"; then
            _cprint -c 33 "[系统] $dir/  ($n)"
        else
            _cprint -c 92 "[扩展] $dir/  ($n)"
        fi

        # 每行 3 个
        local col=0
        local entry
        while IFS= read -r bn; do
            [ -z "$bn" ] && continue
            if [ $show_path -eq 1 ]; then
                entry="$dir/$bn"
            else
                entry="$bn"
            fi
            printf "  %-24s" "$entry"
            col=$((col + 1))
            if [ $col -ge 3 ]; then
                echo ""
                col=0
            fi
        done <<< "$sorted"
        [ $col -gt 0 ] && echo ""
        echo ""
    done

    if [ $count_only -eq 1 ]; then
        cecho "可执行文件总数: $total"
    elif [ $total -eq 0 ]; then
        err "未找到任何可执行文件"
        return 1
    fi
}

cmd_watch() {
    local use_builtin=0
    if [ "$1" = "-d" ] || [ "$1" = "--builtin" ]; then
        use_builtin=1
        shift
    fi
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -lt 2 ]; then
        cecho -b "用法: WATCH [-d] <秒数> <命令> [参数]"
        cecho "  -d, --builtin   使用内置命令(自动匹配 CMD 别名/资源/内置函数)"
        cecho "示例: WATCH 2 date"
        cecho "      WATCH -d 2 systeminfo"
        cecho "按Ctrl+C中断"
        return 0
    fi

    local interval="$1"
    shift
    local cmd_name="$1"
    shift
    local cmd_args=("$@")

    if ! [[ "$interval" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        err "错误:秒数必须是正数"
        return 1
    fi
    if [ "$(echo "$interval <= 0" | bc)" -eq 1 ]; then
        err "错误:秒数必须大于0"
        return 1
    fi

    if ! confirm "每 ${interval} 秒清屏并执行: \"$cmd_name ${cmd_args[*]}\"?(按Ctrl+C随时退出)"; then
        return 0
    fi

    local old_trap=$(trap -p INT)
    local stop_watch=0
    trap 'stop_watch=1' INT

    while [ $stop_watch -eq 0 ]; do
        cmd_cls -n
        if [ $use_builtin -eq 1 ]; then
            _dispatch_cmd "$cmd_name" "${cmd_args[@]}"
        else
            if [ ${#cmd_args[@]} -eq 0 ]; then
                "$cmd_name"
            else
                "$cmd_name" "${cmd_args[@]}"
            fi
        fi
        if [ $stop_watch -eq 0 ]; then
            sleep "$interval"
        fi
    done

    if [ -n "$old_trap" ]; then
        eval "$old_trap"
    else
        trap - INT
    fi

    echo ""
    sleep 0.1

    if ! confirm "是否保留输出?"; then
        cmd_cls
    fi

    return 0
}

cmd_repeat() {
    local use_builtin=0
    if [ "$1" = "-d" ] || [ "$1" = "--builtin" ]; then
        use_builtin=1
        shift
    fi
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -lt 2 ]; then
        cecho -b "用法: REPEAT [-d] <次数> <命令> [参数]"
        cecho "  -d, --builtin   使用内置命令(自动匹配 CMD 别名/资源/内置函数)"
        cecho "示例: REPEAT 100 echo Hello World"
        cecho "      REPEAT -d 3 systeminfo"
        cecho "按Ctrl+C中断"
        return 0
    fi

    local count="$1"
    shift
    local cmd_name="$1"
    shift
    local cmd_args=("$@")

    if ! [[ "$count" =~ ^[0-9]+$ ]] || [ "$count" -eq 0 ]; then
        err "次数必须是正整数"
        return 1
    fi

    if ! confirm "执行 \"$cmd_name ${cmd_args[*]}\" *$count?(按Ctrl+C随时退出)"; then
        return 0
    fi

    local old_trap=$(trap -p INT)
    local stop_repeat=0
    trap 'stop_repeat=1' INT

    local i
    for ((i=1; i<=count; i++)); do
        if [ $stop_repeat -eq 1 ]; then
            break
        fi
        if [ $use_builtin -eq 1 ]; then
            _dispatch_cmd "$cmd_name" "${cmd_args[@]}"
        else
            if [ ${#cmd_args[@]} -eq 0 ]; then
                "$cmd_name"
            else
                "$cmd_name" "${cmd_args[@]}"
            fi
        fi
    done

    if [ -n "$old_trap" ]; then
        eval "$old_trap"
    else
        trap - INT
    fi

    if [ $stop_repeat -eq 1 ]; then
        echo ""
        cecho "REPEAT 已被用户中断 (执行了 $((i-1)) 次)"
        return 130
    else
        cecho "REPEAT 完成 (共执行 $count 次)"
        return 0
    fi
}

cmd_time() {
    local use_builtin=0
    if [ "$1" = "-d" ] || [ "$1" = "--builtin" ]; then
        use_builtin=1
        shift
    fi
    if [[ "$1" == "-h" || "$1" == "--help" ]] || [ $# -eq 0 ]; then
        cecho -b "用法: TIME [-d] <命令> [参数]"
        cecho "  -d, --builtin   使用内置命令(自动匹配 CMD 别名/资源/内置函数)"
        cecho "示例: TIME ls -l"
        cecho "      TIME -d systeminfo"
        cecho "按Ctrl+C中断正在执行的命令"
        return 0
    fi

    local cmd_name="$1"
    shift
    local cmd_args=("$@")

    local old_trap=$(trap -p INT)
    trap '' INT

    (
        trap - INT
        TIMEFORMAT=$'实际时间\t%E\n用户时间\t%U秒\n系统时间\t%S秒'
        if [ $use_builtin -eq 1 ]; then
            time _dispatch_cmd "$cmd_name" "${cmd_args[@]}"
        else
            if [ ${#cmd_args[@]} -eq 0 ]; then
                time "$cmd_name"
            else
                time "$cmd_name" "${cmd_args[@]}"
            fi
        fi
    )
    local exit_code=$?

    if [ -n "$old_trap" ]; then
        eval "$old_trap"
    else
        trap - INT
    fi

    if [ $exit_code -eq 130 ]; then
        echo ""
        return 130
    else
        return $exit_code
    fi
}

cmd_timeout() {
    local signal="TERM"
    local kill_after=""
    local preserve_status=0
    local verbose=0
    local use_builtin=0

    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                cecho -b "用法: TIMEOUT [-d] [参数] <秒数> <命令> [参数]"
                cecho -b "参数:"
                cecho "  -d, --builtin             使用内置命令(自动匹配 CMD 别名/资源/内置函数)"
                cecho "  -s, --signal <信号>       超时发送的信号(默认 TERM)"
                cecho "  -k, --kill-after <时长>   超时后再等指定时长, 仍存活则发 KILL"
                cecho "      --preserve-status     超时时保留命令自身退出状态"
                cecho "  -v, --verbose             超时时输出提示信息"
                cecho "  -h, --help                显示此帮助"
                cecho -b "时长格式:"
                cecho "  数字[后缀], 后缀 s(秒,默认)/m(分)/h(时)/d(天), 支持小数"
                return 0
                ;;
            -d|--builtin)
                use_builtin=1; shift ;;
            -s|--signal)
                if [ $# -lt 2 ]; then err "参数 -s 需要信号名"; return 1; fi
                signal="$2"; shift 2 ;;
            --signal=*)
                signal="${1#--signal=}"; shift ;;
            -k|--kill-after)
                if [ $# -lt 2 ]; then err "参数 -k 需要时长"; return 1; fi
                kill_after="$2"; shift 2 ;;
            --kill-after=*)
                kill_after="${1#--kill-after=}"; shift ;;
            --preserve-status)
                preserve_status=1; shift ;;
            -v|--verbose)
                verbose=1; shift ;;
            --)
                shift; break ;;
            -*)
                err "未知参数: $1, 使用 TIMEOUT -h 查看帮助"
                return 1 ;;
            *)
                break ;;
        esac
    done

    if [ $# -lt 2 ]; then
        err "用法: TIMEOUT [-d] [参数] <秒数> <命令> [参数], 使用 TIMEOUT -h 查看帮助"
        return 1
    fi

    local duration="$1"
    shift

    if [ "$1" = "--" ]; then
        shift
    fi

    _timeout_parse_ticks() {
        local d="$1"
        local unit="s"
        local num="$d"
        case "${d: -1}" in
            s|S) unit="s"; num="${d%?}" ;;
            m|M) unit="m"; num="${d%?}" ;;
            h|H) unit="h"; num="${d%?}" ;;
            d|D) unit="d"; num="${d%?}" ;;
        esac
        if ! [[ "$num" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            return 1
        fi
        local mult=10
        case "$unit" in
            m) mult=600 ;;
            h) mult=36000 ;;
            d) mult=864000 ;;
        esac
        awk -v n="$num" -v m="$mult" 'BEGIN{printf "%d", n*m}'
    }

    local max_ticks
    max_ticks=$(_timeout_parse_ticks "$duration") || {
        err "无效的时长: $duration"
        return 1
    }
    [ -z "$max_ticks" ] && max_ticks=0

    local kill_after_ticks=0
    if [ -n "$kill_after" ]; then
        kill_after_ticks=$(_timeout_parse_ticks "$kill_after") || {
            err "无效的 -k 时长: $kill_after"
            return 1
        }
        [ -z "$kill_after_ticks" ] && kill_after_ticks=0
    fi

    _timeout_send_signal() {
        local pid="$1"
        local sig="$2"
        [ "$pid" -eq $$ ] && return
        if [ -d "/proc" ]; then
            local children
            children=$($_GREP -l "^PPid:[[:space:]]*$pid$" /proc/*/status 2>/dev/null | $_CUT -d/ -f3)
            local child
            for child in $children; do
                _timeout_send_signal "$child" "$sig"
            done
        fi
        kill -"$sig" "$pid" 2>/dev/null
}

    local old_trap
    old_trap=$(trap -p INT)

    # 启动目标命令
    if [ $use_builtin -eq 1 ]; then
        local cmd_name="$1"
        shift
        local cmd_args=("$@")
        _dispatch_cmd "$cmd_name" "${cmd_args[@]}" &
        local cmd_pid=$!
    else
        "$@" &
        local cmd_pid=$!
    fi

    trap 'kill -INT "$cmd_pid" 2>/dev/null' INT

    local ticks=0
    while kill -0 "$cmd_pid" 2>/dev/null; do
        if [ "$ticks" -ge "$max_ticks" ]; then
            if [ "$verbose" -eq 1 ]; then
                _cprint -c 93 "timeout: 超时, 发送 SIG$signal 给进程 $cmd_pid"
            fi
            _timeout_send_signal "$cmd_pid" "$signal"

            if [ "$kill_after_ticks" -gt 0 ]; then
                local kticks=0
                while kill -0 "$cmd_pid" 2>/dev/null && [ "$kticks" -lt "$kill_after_ticks" ]; do
                    sleep 0.1
                    kticks=$((kticks + 1))
                done
                if kill -0 "$cmd_pid" 2>/dev/null; then
                    if [ "$verbose" -eq 1 ]; then
                        _cprint -c 93 "timeout: 仍存活, 发送 SIGKILL 给进程 $cmd_pid"
                    fi
                    _timeout_send_signal "$cmd_pid" KILL
                fi
            fi

            wait "$cmd_pid" 2>/dev/null
            local cmd_status=$?

            if [ -n "$old_trap" ]; then
                eval "$old_trap"
            else
                trap - INT
            fi

            if [ "$preserve_status" -eq 1 ]; then
                return $cmd_status
            fi
            if [ "$verbose" -eq 1 ]; then
                err "命令执行超时, 已被终止"
            fi
            return 124
        fi
        sleep 0.1
        ticks=$((ticks + 1))
    done

    wait "$cmd_pid" 2>/dev/null
    local exit_code=$?

    if [ -n "$old_trap" ]; then
        eval "$old_trap"
    else
        trap - INT
    fi

    return $exit_code
}

cmd_which() {
        if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -eq 0 ]; then
        cecho -b "用法: WHICH <命令>"
        return 0
    fi
    local path=$(command -v "$1" 2>/dev/null)
    [ -n "$path" ] && cecho "$path" || err "未找到命令: $1"
}

cmd_tasklist() {
    cecho "进程列表"
    cecho "$CMD_delimiter"
    # 标题, 宽度与数据一致(任务管理器风格)
    printf "  %-6s %-9s %-14s %5s\n" "PID" "USER" "TASK" "RSS"

    # 先试 GNU top 语法, 不支持就跳过走 ps 回退
    local top_output=""
    local pid_line=""
    if top -n 1 -b >/dev/null 2>&1; then
      top_output=$(top -n 1 -b 2>/dev/null)
      pid_line=$(echo "$top_output" | grep -n '^[ ]*PID' | head -1 | cut -d: -f1)
    fi
    if [ -n "$pid_line" ]; then
        # 取前 20 个进程
        echo "$top_output" | tail -n +$((pid_line+1)) | head -n 20 | awk '{
            if (NF < 8) next;
            pid=$1; user=$2; res=$6; cmd=$NF;
            if (length(cmd)>12) cmd=substr(cmd,1,12)"..";
            printf "  %-6s %-9s %-14s %5s\n", pid, user, cmd, res
        }'
    else
        # 回退到 ps
        err "无法从 top 获取进程列表, 使用 ps 回退"
        if ps -A -o pid,user,comm,rss 2>/dev/null | head -n1 | grep -q "PID"; then
            ps -A -o pid,user,comm,rss 2>/dev/null | tail -n +2 | head -n 20 | awk '{
                pid=$1; user=$2; cmd=$3; rss=$4;
                if (rss ~ /^[0-9]+$/ && rss > 0) {
                    rss_mb = rss/1024;
                    if (rss_mb >= 1000) val = sprintf("%.0fM", rss_mb);
                    else val = sprintf("%.1fM", rss_mb);
                    # 固定宽度 5 右对齐
                    rss_str = sprintf("%5s", val);
                } else {
                    rss_str = "  N/A";
                }
                if (length(cmd)>12) cmd=substr(cmd,1,12)"..";
                printf "  %-6s %-9s %-14s %5s\n", pid, user, cmd, rss_str;
            }'
        else
            cecho "无可用进程数据"
        fi
    fi
}

# RUNNING
cmd_running() {
        if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -eq 0 ]; then
        cecho -b "用法: RUNNING <包名>"
        cecho "示例: RUNNING com.android.settings"
        return 0
    fi
    local pkg="$1"
    local user_id
    user_id=$(am get-current-user 2>/dev/null)
    [ -z "$user_id" ] && user_id=0
    if am start -a android.intent.action.MAIN -c android.intent.category.LAUNCHER --user "$user_id" "$pkg" >/dev/null 2>&1; then
        cecho "已启动 $pkg"; return
    fi
    local act
    act=$(pm resolve-activity --brief "$pkg" 2>/dev/null | grep '/' | head -1)
    if [ -n "$act" ]; then
        if am start -n "$act" --user "$user_id" >/dev/null 2>&1; then
            cecho "已启动 $pkg"; return
        fi
    fi
    if monkey -p "$pkg" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; then
        cecho "已启动 $pkg"; return
    fi
    err "无法启动 $pkg"
}

# ---------- UPTIME 汉化 + 负载高亮 ----------
# 中文运行时长转换(默认格式): "13 days, 22:09" → "13天, 22时09分"
_translate_uptime() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"

    if [[ "$s" =~ ^([0-9]+)[[:space:]]+days?,[[:space:]]+(.+)$ ]]; then
        local days="${BASH_REMATCH[1]}"
        local rest="${BASH_REMATCH[2]}"
        rest="${rest#"${rest%%[![:space:]]*}"}"
        rest="${rest%"${rest##*[![:space:]]}"}"
        local rest_trans
        if [[ "$rest" =~ ^([0-9]+):([0-9]+)$ ]]; then
            rest_trans="${BASH_REMATCH[1]}时${BASH_REMATCH[2]}分"
        elif [[ "$rest" =~ ^([0-9]+)[[:space:]]+min ]]; then
            rest_trans="${BASH_REMATCH[1]}分钟"
        else
            rest_trans="$rest"
        fi
        printf '%s' "${days}天, ${rest_trans}"
        return
    fi
    if [[ "$s" =~ ^([0-9]+)[[:space:]]+days?$ ]]; then
        printf '%s' "${BASH_REMATCH[1]}天"; return
    fi
    if [[ "$s" =~ ^([0-9]+):([0-9]+)$ ]]; then
        printf '%s' "${BASH_REMATCH[1]}时${BASH_REMATCH[2]}分"; return
    fi
    if [[ "$s" =~ ^([0-9]+)[[:space:]]+min ]]; then
        printf '%s' "${BASH_REMATCH[1]}分钟"; return
    fi
    printf '%s' "$s"
}

# 中文运行时长转换(-p 美化格式): "1 week, 6 days, 22 hours, 19 minutes" → "1周, 6天, 22小时, 19分钟"
_translate_pretty_uptime() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"

    local out=""
    local first=1
    local IFS=','
    local part
    for part in $s; do
        part="${part#"${part%%[![:space:]]*}"}"
        part="${part%"${part##*[![:space:]]}"}"
        [ -z "$part" ] && continue
        if [[ "$part" =~ ^([0-9]+)[[:space:]]+(.+)$ ]]; then
            local num="${BASH_REMATCH[1]}"
            local unit="${BASH_REMATCH[2]}"
            local unit_cn="$unit"
            case "$unit" in
                week|weeks)               unit_cn="周" ;;
                day|days)                 unit_cn="天" ;;
                hour|hours)               unit_cn="小时" ;;
                minute|minutes|min|mins)  unit_cn="分钟" ;;
                second|seconds|sec|secs)  unit_cn="秒" ;;
            esac
            [ $first -eq 0 ] && out+=", "
            out+="${num}${unit_cn}"
            first=0
        else
            [ $first -eq 0 ] && out+=", "
            out+="$part"
            first=0
        fi
    done
    printf '%s' "$out"
}

# 根据负载与 CPU 核心数比值返回颜色码(空表示不高亮)
# <0.7 绿(92), <1.0 黄(93), >=1.0 红(91)
_load_color() {
    local load="$1" cores="$2"
    awk -v l="$load" -v c="$cores" 'BEGIN {
        if (c <= 0) { exit }
        r = l / c;
        if (r < 0.7) print "92";
        else if (r < 1.0) print "93";
        else print "91";
    }' 2>/dev/null
}

# 获取 CPU 核心数, 失败时输出空
_get_cores() {
    local cores=""
    if command -v nproc >/dev/null 2>&1; then
        cores=$(nproc 2>/dev/null)
    fi
    if [ -z "$cores" ] || ! [[ "$cores" =~ ^[0-9]+$ ]] || [ "$cores" -le 0 ]; then
        cores=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null)
    fi
    if [ -z "$cores" ] || ! [[ "$cores" =~ ^[0-9]+$ ]] || [ "$cores" -le 0 ]; then
        cores=""
    fi
    printf '%s' "$cores"
}

# 输出负载行(带颜色), 参数: load1 load5 load15
_uptime_print_load() {
    local load1="$1" load5="$2" load15="$3"
    local cores
    cores=$(_get_cores)

    if [ -z "$cores" ]; then
        cecho "  最近1分钟, 5分钟, 10分钟的过载: ${load1}, ${load5}, ${load15}"
        return
    fi

    local c1 c5 c15
    c1=$(_load_color "$load1"  "$cores")
    c5=$(_load_color "$load5"  "$cores")
    c15=$(_load_color "$load15" "$cores")

    printf "  最近1分钟, 5分钟, 10分钟的过载: "
    if [ -n "$c1" ]; then _cprint -n -c "$c1" "$load1"; else printf "%s" "$load1"; fi
    printf ", "
    if [ -n "$c5" ]; then _cprint -n -c "$c5" "$load5"; else printf "%s" "$load5"; fi
    printf ", "
    if [ -n "$c15" ]; then _cprint -n -c "$c15" "$load15"; else printf "%s" "$load15"; fi
    printf "\n"
}

# 原始输出(逐行着色)
_uptime_raw_output() {
    local raw="$1"
    echo "$raw" | while IFS= read -r line; do cecho "$line"; done
}

cmd_uptime() {
    local opt_p=0 opt_s=0 opt_v=0
    local raw_args=()
    local arg

    for arg in "$@"; do
        case "$arg" in
            -p) opt_p=1; raw_args+=("-p") ;;
            -s) opt_s=1; raw_args+=("-s") ;;
            -v) opt_v=1 ;;
            -h|--help)
                cecho -b "用法: UPTIME [-p|-s] [-v]"
                cecho "  (无参数)   默认格式, 已汉化"
                cecho "  -p         美化输出(human readable), 已汉化"
                cecho "  -s         显示系统启动时间, 已汉化"
                cecho "  -v         输出原始输出(不汉化)"
                return 0
                ;;
            *)
                err "未知参数: $arg, 使用 UPTIME -h 查看帮助"
                return 1
                ;;
        esac
    done

    if [ $opt_p -eq 1 ] && [ $opt_s -eq 1 ]; then
        err "-p 和 -s 不能同时使用"
        return 1
    fi

    local raw
    raw=$($_UPTIME "${raw_args[@]}" 2>&1)
    local ret=$?
    if [ $ret -ne 0 ] || [ -z "$raw" ]; then
        err "无法获取运行时间"
        return 1
    fi

    # -v: 原始输出优先(搭配时不汉化)
    if [ $opt_v -eq 1 ]; then
        _uptime_raw_output "$raw"
        return 0
    fi

    # -s: 启动时间
    if [ $opt_s -eq 1 ]; then
        local boot
        boot=$(echo "$raw" | head -1 | tr -d '\n\r')
        boot="${boot#"${boot%%[![:space:]]*}"}"
        boot="${boot%"${boot##*[![:space:]]}"}"
        cecho "  系统启动时间: ${boot}"
        return 0
    fi

    # -p: 美化格式
    if [ $opt_p -eq 1 ]; then
        if [[ "$raw" =~ ^[[:space:]]*up[[:space:]]+(.+),[[:space:]]+load[[:space:]]+averages?:[[:space:]]+([0-9.]+),[[:space:]]+([0-9.]+),[[:space:]]+([0-9.]+) ]]; then
            local up_str="${BASH_REMATCH[1]}"
            local l1="${BASH_REMATCH[2]}"
            local l5="${BASH_REMATCH[3]}"
            local l15="${BASH_REMATCH[4]}"
            local up_cn
            up_cn=$(_translate_pretty_uptime "$up_str")
            cecho "  已经运行${up_cn}"
            _uptime_print_load "$l1" "$l5" "$l15"
        else
            _uptime_raw_output "$raw"
        fi
        return 0
    fi

    # 默认格式
    if [[ "$raw" =~ ^[[:space:]]*([0-9:]+)[[:space:]]+up[[:space:]]+(.+),[[:space:]]+([0-9]+)[[:space:]]+users?,[[:space:]]+load[[:space:]]+averages?:[[:space:]]+([0-9.]+),[[:space:]]+([0-9.]+),[[:space:]]+([0-9.]+) ]]; then
        local t="${BASH_REMATCH[1]}"
        local up_str="${BASH_REMATCH[2]}"
        local users="${BASH_REMATCH[3]}"
        local l1="${BASH_REMATCH[4]}"
        local l5="${BASH_REMATCH[5]}"
        local l15="${BASH_REMATCH[6]}"
        local up_cn
        up_cn=$(_translate_uptime "$up_str")
        cecho "  自${t} 已经运行${up_cn}, ${users}个用户"
        _uptime_print_load "$l1" "$l5" "$l15"
    else
        _uptime_raw_output "$raw"
    fi
}

cmd_find() {
    if [ $# -eq 0 ]; then
        err "缺少参数, 使用 FIND -h 查看帮助"
        return 1
    fi

    local output
    output=$($_FIND "$@" 2>&1)
    local ret=$?
    if [ -n "$output" ]; then
        printf "%s\n" "$output" | while IFS= read -r line; do
            cecho "$line"
        done
    fi
    return $ret
}

cmd_cgrep() {
        if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -eq 0 ]; then
        cecho -b "用法: CGREP <关键词/正则表达式> <文件1> [文件2...]"
        return 0
    fi
    if [ $# -lt 2 ]; then
        err "参数不足, 使用 CGREP -h 查看帮助"
        return 1
    fi
    local pattern="$1"; shift
    $_GREP "$pattern" "$@" 2>&1 | while IFS= read -r line; do cecho "$line"; done
}

cmd_wc() {
    if [[ "$1" == "-h" || "$1" == "--help" ]] || [ $# -lt 1 ]; then
        cecho -b "用法: WC [参数] [文件...]"
        cecho "统计行数、单词数、字符数"
        cecho "参数: 与系统WC相同, 输出美化"
        return 0
    fi

    # 如果参数中含有标准 wc 的短参数, 直接原样执行并输出
    local has_short_opts=0
    for arg in "$@"; do
        if [[ "$arg" =~ ^-[lwcmL] ]]; then
            has_short_opts=1
            break
        fi
    done

    if [ $has_short_opts -eq 1 ]; then
        # 直接调用系统 wc, 保留原始输出
        wc "$@"
        return $?
    fi

    # 无参数或仅有文件:美化输出
    if [ $# -eq 0 ]; then
        # 无文件, 从标准输入读取
        local data=$(cat)
        local lines=$(echo "$data" | wc -l)
        local words=$(echo "$data" | wc -w)
        local chars=$(echo "$data" | wc -c)
        cecho "行数: $lines   单词数: $words   字符数: $chars"
    else
        # 有文件, 逐个显示
        for file in "$@"; do
            if [ ! -f "$file" ]; then
                err "文件不存在: $file"
                continue
            fi
            local lines=$(wc -l < "$file" 2>/dev/null)
            local words=$(wc -w < "$file" 2>/dev/null)
            local chars=$(wc -c < "$file" 2>/dev/null)
            cecho "文件: $file"
            cecho "  行数: $lines   单词数: $words   字符数: $chars"
        done
    fi
}

cmd_diff() {
    if [[ "$1" == "-h" || "$1" == "--help" ]] || [ $# -lt 2 ]; then
        cecho -b "用法: DIFF [参数] <1> <2>"
        cecho "比较两个文件/目录的差异"
        cecho "参数: 与系统diff相同, 输出美化"
        return 0
    fi

    local output
    output=$(diff "$@" 2>&1)
    local ret=$?

    if [ $ret -eq 0 ]; then
        # 无差异
        cecho -b "无差异"
        return 0
    elif [ $ret -eq 1 ]; then
        # 有差异, 直接输出 diff 原始内容
        cecho -b -c 33 "有差异:"
        printf "%s\n" "$output"
        return 1
    else
        # 错误处理:转换常见错误信息为中文
        local errmsg="$output"
        if [[ "$errmsg" =~ "No such file or directory" ]]; then
            err "文件或目录不存在"
        elif [[ "$errmsg" =~ "cannot stat" ]]; then
            err "无法获取文件状态"
        elif [[ "$errmsg" =~ "Permission denied" ]]; then
            err "权限不足"
        elif [[ "$errmsg" =~ "Is a directory" ]]; then
            err "期望文件, 但为目录"
        elif [[ "$errmsg" =~ "Not a directory" ]]; then
            err "期望目录, 但为文件"
        else
            err "diff 错误: $errmsg"
        fi
        return $ret
    fi
}

cmd_more() {
    if [ -z "$1" ]; then
        err "命令语法不正确"
        return 1
    fi
    if command -v more >/dev/null 2>&1; then
        more "$1"
    else
        err "系统未找到 more 命令"
        return 1
    fi
}

cmd_tree() {
    local show_dirs_only=0
    local max_depth=-1
    local show_size=0
    local show_dir_size=0
    local path="."

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d) show_dirs_only=1; shift ;;
            -a) show_dir_size=1; shift ;;
            -L)
                if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                    max_depth="$2"; shift 2
                else
                    shift
                fi
                ;;
            -s) show_size=1; shift ;;
            -h|--help)
                cecho -b "用法: TREE [参数] [路径]"
                cecho "参数:"
                cecho "  -d          只显示目录"
                cecho "  -L <深度>   限制递归深度"
                cecho "  -a          显示目录的总大小"
                cecho "  -s          显示文件的大小"
                cecho "  -h, --help  显示此帮助"
                return 0
                ;;
            *)
                path="$1"; shift
                ;;
        esac
    done

    if [ ! -d "$path" ]; then
        err "系统找不到指定的路径"
        return 1
    fi

    path=$(cd "$path" 2>/dev/null && pwd) || path="$(realpath "$path" 2>/dev/null || echo "$path")"

    local tmp_base="$TMP_DIR"
    if [ ! -d "$tmp_base" ]; then
        mkdir -p "$tmp_base" 2>/dev/null || { err "无法创建临时目录"; return 1; }
    fi
    if [ ! -w "$tmp_base" ]; then
        err "临时目录不可写"; return 1;
    fi

    local tmp_prefix="tree_$$_$(date +%s%N)_${RANDOM:-$$}_"
    local temp_files=()

    # 保存旧的 EXIT trap, 设置自己的清理
    local old_exit_trap=$(trap -p EXIT)
    trap 'rm -f "${temp_files[@]}"' EXIT

    # 中断处理
    local interrupted=0
    local old_int_trap=$(trap -p INT)
    trap 'interrupted=1' INT

    _tree_recursive() {
        local dir="$1"
        local prefix="$2"
        local depth="$3"
        if [ $max_depth -ge 0 ] && [ $depth -gt $max_depth ]; then
            return
        fi

        local tmpfile
        tmpfile=$(mktemp -p "$tmp_base" "${tmp_prefix}XXXXXX" 2>/dev/null) || {
            tmpfile="$tmp_base/${tmp_prefix}$(od -An -N4 -tu4 /dev/urandom 2>/dev/null | tr -d ' ')"
            touch "$tmpfile" 2>/dev/null || return
        }
        temp_files+=("$tmpfile")

        if ls -A "$dir" >/dev/null 2>&1; then
            ls -A "$dir" | $_SORT 2>/dev/null > "$tmpfile"
        else
            ls -a "$dir" 2>/dev/null | $_GREP -v '^\.$' | $_GREP -v '^\.\.$' | $_SORT 2>/dev/null > "$tmpfile"
        fi

        local count=0
        if [ -s "$tmpfile" ]; then
            count=$($_AWK 'END {print NR}' "$tmpfile" 2>/dev/null)
        fi
        if [ -z "$count" ] || [ "$count" -eq 0 ]; then
            return
        fi

        local i=0
        while IFS= read -r entry; do
            # 检查中断标志
            if [ $interrupted -eq 1 ]; then
                return
            fi
            i=$((i+1))
            local full="$dir/$entry"
            local is_last=0
            [ $i -eq $count ] && is_last=1

            local connector="├── "
            local child_prefix="${prefix}│   "
            if [ $is_last -eq 1 ]; then
                connector="└── "
                child_prefix="${prefix}    "
            fi

            # ========== 防循环:处理符号链接 ==========
            if [ -L "$full" ]; then
                # 仅当非 -d 模式时显示, 用青色并加 @ 标记
                if [ $show_dirs_only -eq 0 ]; then
                    _cprint -c 36 "${prefix}${connector}${entry}@"
                fi
                continue   # 不递归
            fi

            if [ -d "$full" ]; then
                if [ $show_dirs_only -eq 0 ] || [ $show_dirs_only -eq 1 ]; then
                    if [ $show_dir_size -eq 1 ]; then
                        local dir_size=$(du -sh "$full" 2>/dev/null | awk '{print $1}')
                        [ -z "$dir_size" ] && dir_size="?"
                        _cprint -c 33 "${prefix}${connector}${entry} ($dir_size)"
                    else
                        _cprint -c 33 "${prefix}${connector}${entry}"
                    fi
                fi
                # 递归前再次检查中断
                if [ $interrupted -eq 0 ]; then
                    _tree_recursive "$full" "$child_prefix" $((depth+1))
                fi
            else
                if [ $show_dirs_only -eq 0 ]; then
                    if [ $show_size -eq 1 ]; then
                        local size=$(du -sh "$full" 2>/dev/null | awk '{print $1}')
                        [ -z "$size" ] && size="?"
                        _cprint "${prefix}${connector}${entry} ($size)"
                    else
                        _cprint "${prefix}${connector}${entry}"
                    fi
                fi
            fi
        done < "$tmpfile"
    }

    local rootname=$(basename "$path")
    [ -z "$rootname" ] && rootname="/"
    _cprint -c 32 "$rootname"
    _tree_recursive "$path" "" 0

    # 恢复 trap
    eval "$old_exit_trap" 2>/dev/null || trap - EXIT
    eval "$old_int_trap" 2>/dev/null || trap - INT
    # 清理可能残留的临时文件(以防万一
    rm -f "${temp_files[@]}" 2>/dev/null
}

cmd_adb() {
        if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -eq 0 ]; then
        cecho -b "用法: ADB <参数>"
        cecho "示例: ADB devices"
        return 0
    fi
    if ! confirm "确认要执行此ADB命令吗?(请确认命令是否安全!)"; then
        return 0
    fi
    if command -v adb >/dev/null 2>&1; then
        adb "$@" 2>&1 | while IFS= read -r line; do cecho "$line"; done
    else
        err "未找到 adb 命令"
        return 1
    fi
}

# ---------- 多行内置命令批量执行 ----------
# CC 执行上下文标志(防嵌套套娃)
_CC_RUNNING=0

# 帮助文本(单独抽出来, 嵌套时也可查看)
# 实际实现
_cmd_cc_impl() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        _cmd_cc_help
        return 0
    fi

    cecho -b "进入多行输入模式 (每行作为独立内置命令按顺序执行, 按 Ctrl+D 开始, Ctrl+C 中断)"
    cecho "$CMD_delimiter"

    local old_trap interrupted=0
    old_trap=$(trap -p INT)
    trap 'interrupted=1' INT

    local input_data
    input_data=$(cat)
    local cat_ret=$?

    if [ $interrupted -eq 1 ] || [ $cat_ret -ne 0 ]; then
        eval "$old_trap" 2>/dev/null || trap - INT
        echo ""
        return 130
    fi
    if [ -z "$input_data" ]; then
        eval "$old_trap" 2>/dev/null || trap - INT
        err "未输入任何内容"
        return 1
    fi

    cecho "$CMD_delimiter"
    cecho "开始按顺序执行:"

    local line_num=0 exec_count=0 fail_count=0
    while IFS= read -r line; do
        line_num=$((line_num + 1))
        local trimmed="${line#"${line%%[![:space:]]*}"}"
        trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
        [ -z "$trimmed" ] && continue
        [[ "$trimmed" == \#* ]] && continue
        if [ $interrupted -eq 1 ]; then break; fi

        _cprint -c 90 "[$line_num] $line"

        # 复用 CMD 解析器(支持变量/引号), 再交给内置命令分发器
        parse_line "$line"
        if [ ${#PARSED_ARGS[@]} -eq 0 ]; then
            continue
        fi

        local _cc_cmd="${PARSED_ARGS[0],,}"
        local _cc_args=("${PARSED_ARGS[@]:1}")

        _dispatch_cmd "$_cc_cmd" "${_cc_args[@]}"
        local ret=$?
        if [ $ret -ne 0 ]; then
            fail_count=$((fail_count + 1))
            err "第 $line_num 行执行失败 (退出码: $ret)"
        fi
        exec_count=$((exec_count + 1))
    done <<< "$input_data"

    eval "$old_trap" 2>/dev/null || trap - INT

    cecho "$CMD_delimiter"
    if [ $interrupted -eq 1 ]; then
        err "执行被中断 (已执行 $exec_count 行, 失败 $fail_count 行)"
        return 130
    fi
    cecho "执行完毕: 共 $exec_count 行, 失败 $fail_count 行"
    return 0
}

# 对外入口(wrapper): 帮助不受套娃限制, 其余路径自动复位标志
cmd_cc() {
    if [ "$_CC_RUNNING" -eq 1 ]; then
        err "CC: 不支持嵌套调用(已在 CC 执行上下文中)"
        return 1
    fi

    _CC_RUNNING=1
    _cmd_cc_impl "$@"
    local _cc_ret=$?
    _CC_RUNNING=0
    return $_cc_ret
}

# ---------- CMD/C ----------
# ---------- CMD/C ----------
cmd_cmd() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    ccat << "EOF"
  C/CMD                         进入系统交互
  C/CMD -M                      多行输入模式(每行独立执行, Ctrl+D开始)
  C/CMD -L <命令> [参数]        前台运行(支持 top 等持续刷新命令)
  C/CMD -h/--help               显示此帮助
EOF
        return 0
    fi

    if [ "$1" = "-L" ] || [ "$1" = "--long" ]; then
        shift
        if [ $# -eq 0 ]; then
            err "用法: C -L <命令> [参数]"
            err "  -L, --long   长时间执行模式(前台运行, 支持 top 等持续刷新命令)"
            return 1
        fi

        local cmd_disp="$*"
        [ ${#cmd_disp} -gt 40 ] && cmd_disp="${cmd_disp:0:37}..."
        cecho -c 90 "长时间执行模式(前台运行, Ctrl+C 直接中断命令): $cmd_disp"
        cecho "$CMD_delimiter"

        # 保存旧的 INT trap
        local old_int_trap
        old_int_trap=$(trap -p INT)

        # 父 shell 忽略 INT, 避免 Ctrl+C 时把父 shell 也带走
        # 子 shell 内 trap - INT 恢复默认, 让命令能正常响应 Ctrl+C
        trap '' INT

        (
            trap - INT
            eval "$@"
        )
        local exit_code=$?

        # 恢复旧 trap
        if [ -n "$old_int_trap" ]; then
            eval "$old_int_trap"
        else
            trap - INT
        fi

        if [ $exit_code -ne 0 ]; then
            echo ""
            err "命令以退出码 $exit_code 退出"
            return $exit_code
        else
            echo ""
            cecho "命令执行完毕"
            return 0
        fi
    fi

    if [ "$1" = "-M" ]; then
        cecho -b "进入多行输入模式 (每行作为独立命令, 按顺序执行, 按 Ctrl+D 开始, Ctrl+C退出)"
        cecho "$CMD_delimiter"

        local old_trap interrupted=0
        old_trap=$(trap -p INT)
        trap 'interrupted=1' INT

        local input_data
        input_data=$(cat)
        local cat_ret=$?

        if [ $interrupted -eq 1 ] || [ $cat_ret -ne 0 ]; then
            eval "$old_trap" 2>/dev/null || trap - INT
            echo ""
            return 130
        fi
        if [ -z "$input_data" ]; then
            eval "$old_trap" 2>/dev/null || trap - INT
            err "未输入任何内容"
            return 1
        fi

        cecho "$CMD_delimiter"
        cecho "开始按顺序执行:"

        local line_num=0 exec_count=0 fail_count=0
        while IFS= read -r line; do
            line_num=$((line_num+1))
            local trimmed="${line#"${line%%[![:space:]]*}"}"
            [ -z "$trimmed" ] && continue
            [[ "$trimmed" == \#* ]] && continue
            if [ $interrupted -eq 1 ]; then break; fi
            _cprint -c 90 "[$line_num] $line"
            eval "$line"
            local ret=$?
            if [ $ret -ne 0 ]; then
                fail_count=$((fail_count+1))
                err "第 $line_num 行执行失败 (退出码: $ret)"
            fi
            exec_count=$((exec_count+1))
        done <<< "$input_data"

        eval "$old_trap" 2>/dev/null || trap - INT
        cecho "$CMD_delimiter"
        if [ $interrupted -eq 1 ]; then
            err "执行被中断 (已执行 $exec_count 行, 失败 $fail_count 行)"
            return 130
        fi
        cecho "执行完毕: 共 $exec_count 行, 失败 $fail_count 行"
        return 0
    fi

    if [ $# -eq 0 ]; then
        local shell_bin=""
        if [ -L "/proc/$$/exe" ]; then
            shell_bin=$(readlink -f "/proc/$$/exe" 2>/dev/null)
        fi
        if [ -z "$shell_bin" ] || [ ! -x "$shell_bin" ]; then shell_bin="$BASH"; fi
        if [ -z "$shell_bin" ] || [ ! -x "$shell_bin" ]; then
            if [ -x "$0" ]; then shell_bin="$0"; else shell_bin=$(command -v "$0" 2>/dev/null); fi
        fi
        if [ -z "$shell_bin" ] || [ ! -x "$shell_bin" ]; then shell_bin="sh"; fi

        local shell_disp="$shell_bin"
        [ ${#shell_disp} -gt 30 ] && shell_disp="...${shell_disp: -27}"

        local shell_base use_hist=0 sub_hist=""
        shell_base=$(basename "$shell_bin" 2>/dev/null)
        shell_base="${shell_base#-}"
        if [[ "$shell_base" == bash* ]]; then
            sub_hist="$TMP_DIR/subhist_$$_$(date +%s%N).hist"
            if : > "$sub_hist" 2>/dev/null; then use_hist=1; else sub_hist=""; fi
        fi

        cecho -b "进入交互模式 [$shell_disp] (exit 或 Ctrl+D 退出)"
        cecho "$CMD_delimiter"

        if [ $use_hist -eq 1 ]; then
            HISTFILE="$sub_hist" HISTSIZE=1000 HISTFILESIZE=1000 "$shell_bin" -i
        else
            "$shell_bin" -i
        fi
        local exit_code=$?

        if [ $use_hist -eq 1 ] && [ -s "$sub_hist" ]; then
            local added=0 line
            while IFS= read -r line; do
                [ -z "$line" ] && continue
                [[ "$line" =~ ^[[:space:]]*$ ]] && continue
                [[ "$line" =~ ^#[0-9]+$ ]] && continue
                history -s "c $line"
                added=$((added + 1))
            done < "$sub_hist"
            if [ $added -gt 0 ]; then
                history -w "$HISTFILE"
                cecho -c 90 "已记录 $added 调命令在历史中(格式:c \$实际系统命令)"
            fi
        fi
        [ -n "$sub_hist" ] && rm -f "$sub_hist" 2>/dev/null

        cecho "已退出系统交互(退出码: $exit_code)"
        return $exit_code
    fi

    local old_trap=$(trap -p INT)
    local child_pid="" interrupted=0
    trap 'interrupted=1; [ -n "$child_pid" ] && kill -INT "$child_pid" 2>/dev/null' INT
    eval "$@" &
    child_pid=$!
    wait "$child_pid"
    local exit_code=$?
    eval "$old_trap" 2>/dev/null || trap - INT

    if [ $interrupted -eq 1 ]; then
        echo ""
        cecho "命令被中断"
        return 130
    elif [ $exit_code -ne 0 ]; then
        echo ""
        err "命令以退出码 $exit_code 退出"
        return $exit_code
    else
        echo ""
        cecho "命令执行完毕"
        return 0
    fi
}

cmd_sh_usage() {
    ccat << "EOF"
//cecho -b "用法: SH/RUN [-s <shell>] <脚本路径> [参数]"
      SH/RUN [-s <shell>] -M   多行脚本编辑模式(Ctrl+D开始)
//cecho -b "选项:"
  -s, --shell <shell>  指定解释器 (默认: bash)
  -M                   多行脚本编辑模式
  -h, --help           显示此帮助
EOF
}

cmd_sh() {
    local shell_bin="bash"
    local mode_m=0

    if [ $# -eq 0 ]; then
        cmd_sh_usage
        return 0
    fi

    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help) cmd_sh_usage; return 0 ;;
            -M) mode_m=1; shift ;;
            -s|--shell)
                if [ $# -lt 2 ]; then err "选项 $1 缺少 shell 参数"; return 1; fi
                shell_bin="$2"; shift 2 ;;
            --shell=*) shell_bin="${1#--shell=}"; shift ;;
            -s?*) shell_bin="${1#-s}"; shift ;;
            --) shift; break ;;
            -*) err "未知选项: $1"; return 1 ;;
            *) break ;;
        esac
    done

    if [ -z "$shell_bin" ]; then err "shell 不能为空"; return 1; fi
    if ! command -v "$shell_bin" >/dev/null 2>&1; then
        err "指定的解释器不存在或不可执行: $shell_bin"
        return 1
    fi

    # -------- -M 多行脚本编辑模式 --------
    if [ "$mode_m" -eq 1 ]; then
        cecho -b "进入脚本编辑模式 (解释器: $shell_bin, 按 Ctrl+D 开始, Ctrl+C 取消)"
        cecho "$CMD_delimiter"

        local old_trap interrupted=0
        old_trap=$(trap -p INT)
        trap 'interrupted=1' INT

        local input_data
        input_data=$(cat)
        local cat_ret=$?

        if [ $interrupted -eq 1 ] || [ $cat_ret -ne 0 ]; then
            eval "$old_trap" 2>/dev/null || trap - INT
            echo ""
            return 130
        fi
        if [ -z "$input_data" ]; then
            eval "$old_trap" 2>/dev/null || trap - INT
            err "未输入任何内容"
            return 1
        fi

        cecho "$CMD_delimiter"

        local tmp_script="$TMP_DIR/sh_M_$$_$(date +%s%N).sh"
        if ! printf '%s\n' "$input_data" > "$tmp_script" 2>/dev/null; then
            eval "$old_trap" 2>/dev/null || trap - INT
            err "无法创建临时脚本文件"
            return 1
        fi

        cecho "执行脚本 (解释器: $shell_bin, 临时文件: $tmp_script)"
        cecho "$CMD_delimiter"

        local child_pid=""
        trap 'interrupted=1; [ -n "$child_pid" ] && kill -INT "$child_pid" 2>/dev/null' INT

        "$shell_bin" "$tmp_script" </dev/null &
        child_pid=$!
        wait "$child_pid"
        local exit_code=$?

        eval "$old_trap" 2>/dev/null || trap - INT
        rm -f "$tmp_script" 2>/dev/null

        if [ $interrupted -eq 1 ]; then
            echo ""
            cecho "脚本被用户中断"
            return 130
        elif [ $exit_code -ne 0 ]; then
            echo ""
            err "脚本以退出码 $exit_code 退出"
            return $exit_code
        else
            echo ""
            cecho "脚本执行完成"
            return 0
        fi
    fi

    # -------- 脚本文件执行模式 --------
    if [ $# -eq 0 ]; then
        err "缺少脚本路径"
        cmd_sh_usage
        return 1
    fi
    local script="$1"
    shift
    if [ ! -f "$script" ]; then err "脚本文件不存在: $script"; return 1; fi
    if [ ! -r "$script" ]; then err "脚本文件不可读: $script"; return 1; fi
    if ! confirm "确认要执行此脚本吗?(解释器: $shell_bin, 请确认脚本内不含危险代码!)"; then
        return 0
    fi
    cecho "执行脚本: $script (解释器: $shell_bin)"
    local old_trap child_pid="" interrupted=0
    old_trap=$(trap -p INT)
    trap 'interrupted=1; [ -n "$child_pid" ] && kill -INT "$child_pid" 2>/dev/null' INT
    "$shell_bin" "$script" "$@" <&0 &
    child_pid=$!
    wait "$child_pid"
    local exit_code=$?
    eval "$old_trap" 2>/dev/null || trap - INT
    if [ $interrupted -eq 1 ]; then
        echo ""
        cecho "脚本被用户中断"
        return 130
    elif [ $exit_code -ne 0 ]; then
        echo ""
        err "脚本以退出码 $exit_code 退出"
        return $exit_code
    else
        echo ""
        cecho "脚本执行完成"
        return 0
    fi
}

# 记录通过 FUN 定义的函数名(重启后失效)
USER_DEFINED_FUNCS=()
cmd_fun() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cecho -b "用法: FUN [参数] [函数体]"
        cecho -b "参数:"
        cecho "  -h, --help           显示本帮助"
        cecho "  -l, --list           列出已定义函数"
        cecho "  -d, --delete <名称>  删除指定函数"
        cecho "  -r, --remove         删除全部函数"
        cecho -b "定义函数:"
        cecho "  FUN                  交互模式(多行输入, Ctrl+D 结束)"
        cecho "  FUN [函数体]         单行定义"
        cecho "示例: FUN hello() { echo 'Hello'; }"
        err "注意: 同名函数/内建/命令会被覆盖, 覆盖后原定义不可恢复"
        return 0
    fi

    if [[ "$1" == "-l" || "$1" == "--list" ]]; then
        if [ ${#USER_DEFINED_FUNCS[@]} -eq 0 ]; then
            err "未找到用户函数"
            return 0
        fi
        cecho -b "已定义函数: "
        local i=1 f
        for f in "${USER_DEFINED_FUNCS[@]}"; do
            if type -t "$f" >/dev/null 2>&1; then
                cecho "  $i. $f"
            else
                cecho "  $i. $f (已失效)"
            fi
            ((i++))
        done
        return 0
    fi

    if [[ "$1" == "-d" || "$1" == "--delete" ]]; then
        shift
        if [ $# -eq 0 ] || [ -z "$1" ]; then
            err "用法: FUN -d <函数名>"
            return 1
        fi
        local target="$1" found=0 f
        for f in "${USER_DEFINED_FUNCS[@]}"; do
            [ "$f" = "$target" ] && { found=1; break; }
        done
        if [ $found -eq 0 ]; then
            err "未找到函数: $target"
            return 1
        fi
        if ! confirm "删除 $target?"; then
            return 0
        fi
        unset -f "$target" 2>/dev/null
        local new_list=()
        for f in "${USER_DEFINED_FUNCS[@]}"; do
            [ "$f" != "$target" ] && new_list+=("$f")
        done
        USER_DEFINED_FUNCS=("${new_list[@]}")
        cecho "已删除: $target"
        return 0
    fi

    if [[ "$1" == "-r" || "$1" == "--remove" ]]; then
        if [ ${#USER_DEFINED_FUNCS[@]} -eq 0 ]; then
            err "未找到用户函数"
            return 0
        fi
        if ! confirm "删除全部 ${#USER_DEFINED_FUNCS[@]} 个函数?"; then
            return 0
        fi
        local cnt=${#USER_DEFINED_FUNCS[@]} f
        for f in "${USER_DEFINED_FUNCS[@]}"; do
            unset -f "$f" 2>/dev/null
        done
        USER_DEFINED_FUNCS=()
        cecho "已删除 $cnt 个函数"
        return 0
    fi

    if [[ "$1" == -* ]]; then
        err "未知参数: $1"
        return 1
    fi

    local func_body=""
    if [ $# -eq 0 ]; then
        cecho "输入函数体(按 Ctrl+D 结束): "
        func_body=$(cat)
    else
        func_body="$*"
    fi

    if [ -z "$func_body" ]; then
        err "未输入任何内容"
        return 1
    fi

    local func_name=""
    local trimmed="${func_body#"${func_body%%[![:space:]]*}"}"
    if [[ "$trimmed" =~ ^function[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
        func_name="${BASH_REMATCH[1]}"
    elif [[ "$trimmed" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(\) ]]; then
        func_name="${BASH_REMATCH[1]}"
    fi

    if [ -z "$func_name" ]; then
        err "无法识别函数名"
        return 1
    fi

    local exist_type
    exist_type=$(type -t "$func_name" 2>/dev/null)
    if [ -n "$exist_type" ]; then
        local type_desc=""
        case "$exist_type" in
            function) type_desc="函数" ;;
            builtin)  type_desc="bash 内建" ;;
            keyword)  type_desc="保留字" ;;
            alias)    type_desc="别名" ;;
            file)     type_desc="外部命令" ;;
            *)        type_desc="$exist_type" ;;
        esac
        err "已存在同名定义: $func_name ($type_desc)"
        err "覆盖后不可逆"
        if ! confirm "覆盖 $func_name?"; then
            return 0
        fi
    fi

    if eval "$func_body" 2>/dev/null; then
        local already=0 f
        for f in "${USER_DEFINED_FUNCS[@]}"; do
            [ "$f" = "$func_name" ] && { already=1; break; }
        done
        [ $already -eq 0 ] && USER_DEFINED_FUNCS+=("$func_name")
        cecho "已定义: $func_name"
    else
        err "定义失败, 请检查语法"
        return 1
    fi
}

cmd_kill() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -eq 0 ]; then
        ccat << "EOF"
//cecho -b "用法: KILL [选项] <PID>"
//cecho -b "信号:"
  -2,  -INT     中断 (SIGINT)
  -15, -TERM    终止 (SIGTERM, 默认)
  -9,  -KILL    强制终止 (SIGKILL)
//cecho -b "模式:"
  -t, --tree    递归整棵进程树
//cecho -b "说明:"
  递归模式下, 非 -9 信号先发一次, 0.5s 没退出则升级 SIGKILL
  -t -9 跳过等待, 每层直接 SIGKILL
  不允许终止当前脚本自身或祖先进程(请用killself)
EOF
        return 0
    fi

    # ---------- 解析选项 (顺序任意) ----------
    local signal="TERM"
    local mode="single"
    while [ $# -gt 0 ]; do
        case "$1" in
            -9|-KILL|-SIGKILL)       signal="KILL";  shift ;;
            -15|-TERM|-SIGTERM)      signal="TERM";  shift ;;
            -2|-INT|-SIGINT)         signal="INT";   shift ;;
            -t|--tree)               mode="tree";    shift ;;
            --)                      shift; break ;;
            *)                       break ;;
        esac
    done

    if [ $# -eq 0 ]; then
        err "需要指定进程ID, 使用 KILL -h 查看帮助"
        return 1
    fi

    local pid="$1"

    # ---------- PID 合法性(纯 bash) ----------
    if ! [[ "$pid" =~ ^[0-9]+$ ]]; then
        err "无效的进程ID: $pid"
        return 1
    fi
    if [ "$pid" -le 1 ]; then
        err "拒绝操作: PID $pid 是特殊进程 (init/kthreadd)"
        return 1
    fi

    # ---------- 存在性检查( /proc 优先, 无 /proc 才用 $_PS ) ----------
    if [ -d "/proc" ]; then
        if [ ! -d "/proc/$pid" ]; then
            err "进程 $pid 不存在或已终止"
            return 1
        fi
    else
        if ! $_PS -p "$pid" >/dev/null 2>&1; then
            err "进程 $pid 不存在或已终止"
            return 1
        fi
    fi

    # ---------- 前置友好检查: 自身 ----------
    # 祖先检查在 _kill_process_tree 里做(返回 2 时才算命中)
    if [ "$pid" -eq "$$" ]; then
        err "拒绝操作: 不能终止当前脚本自身 (PID: $$) (请用killself)"
        return 1
    fi

    # ---------- 收集进程信息( /proc 优先, 避免 $_PS -o 兼容问题 ) ----------
    local proc_info="PID: $pid"
    if [ -d "/proc" ] && [ -r "/proc/$pid" ]; then
        local _comm="" _uid=""
        if [ -r "/proc/$pid/comm" ]; then
            _comm=$($_CAT "/proc/$pid/comm" 2>/dev/null)
            _comm="${_comm%$'\n'}"
        fi
        if [ -r "/proc/$pid/status" ]; then
            _uid=$($_AWK -F'[[:space:]]+' '/^Uid:/ {print $2; exit}' "/proc/$pid/status" 2>/dev/null)
        fi
        if [ -n "$_comm" ]; then
            proc_info="$pid  ${_uid:-?}  $_comm"
        fi
    elif command -v ps >/dev/null 2>&1; then
        proc_info=$($_PS -o pid,user,comm= -p "$pid" 2>/dev/null | $_TAIL -n 1)
        [ -z "$proc_info" ] && proc_info="PID: $pid"
    fi

    # ================= 树模式 =================
    if [ "$mode" = "tree" ]; then
        cecho -c 93 "将递归终止进程 $pid 及其所有子进程"
        cecho "进程信息: $proc_info"
        if [ "$signal" = "KILL" ]; then
            cecho -c 91 "最终信号: SIGKILL (每层不等待)"
        else
            cecho "最终信号: SIG$signal (0.5s 后升级 SIGKILL)"
        fi
        if ! confirm "确认杀整棵进程树吗?"; then
            return 0
        fi

        _kill_process_tree "$pid" "$signal"
        local _ret=$?
        if [ "$_ret" -eq 2 ]; then
            err "拒绝操作: $pid 是当前脚本 (PID $$) 的自身或祖先进程"
            return 1
        fi
        cecho "已对进程树发送 SIG$signal (PID $pid)"
        return 0
    fi

    # ================= 单进程模式 =================
    if [ "$signal" = "KILL" ]; then
        cecho "发送 SIGKILL (强制终止) 信号给进程 $pid?"
        cecho "进程信息: $proc_info"
        echo ""
        if ! confirm "强制终止此进程吗?"; then
            return 0
        fi
    else
        cecho "发送 SIG$signal 信号给进程 $pid?"
        cecho "进程信息: $proc_info"
        echo ""
        if ! confirm "终止此进程吗?"; then
            return 0
        fi
    fi

    if kill -"$signal" "$pid" 2>/dev/null; then
        cecho "已发送 SIG$signal 信号到进程 $pid"
        if [ "$signal" = "TERM" ] || [ "$signal" = "INT" ]; then
            cecho "等待进程退出..."
            local waited=0
            while kill -0 "$pid" 2>/dev/null && [ $waited -lt 5 ]; do
                sleep 0.5
                waited=$((waited + 1))
            done
            if kill -0 "$pid" 2>/dev/null; then
                cecho "进程 $pid 未响应 SIG$signal, 尝试强制终止..."
                if kill -KILL "$pid" 2>/dev/null; then
                    cecho "已强制终止进程 $pid"
                else
                    err "强制终止失败, 进程可能已被保护或无权限"
                    return 1
                fi
            else
                cecho "进程 $pid 已成功终止"
            fi
        fi
        return 0
    else
        local kill_result=$?
        case "$kill_result" in
            1)   err "操作不允许: 无法终止进程 $pid" ;;
            127) err "KILL: 命令不可用" ;;
            *)   err "终止进程失败 (错误码: $kill_result)" ;;
        esac
        return 1
    fi
}

# ---------- debug ----------
debug_0() {
    if [ $# -eq 0 ]; then
        PRIV_LEVEL="$PRIV_LEVEL_0"
        cecho "已恢复到: $PRIV_LEVEL"
    else
        case "$1" in
            root|adb|normal) PRIV_LEVEL="$1" ;;
            *) err "无效调试参数"; return 1 ;;
        esac
    fi
    # 同步更新提示符符号
    case "$PRIV_LEVEL" in
        root) PROMPT_SYMBOL="#" ;;
        adb)  PROMPT_SYMBOL="$" ;;
        *)    PROMPT_SYMBOL="->" ;;
    esac
}
# debug_1已死
debug_2() {
    # 加载 codewc
    lazy_load "codewc" || {
        err "无法加载 codewc"
        return 1
    }
    type -t cmd_codewc >/dev/null 2>&1 || {
        err "cmd_codewc 未定义"
        return 1
    }

    # 主程序统计(原始+有效)
    local main_file="$0"
    local main_name="${main_file##*/}"          # 内建替代 basename

    local main_lines=0 main_bytes=0
    read -r main_lines main_bytes _ < <(wc -lc < "$main_file" 2>/dev/null) || true
    [[ -z "$main_lines" ]] && main_lines=0
    [[ -z "$main_bytes" ]] && main_bytes=0

    local main_eff_lines=0 main_eff_words=0 main_eff_chars=0
    local main_eff_output
    main_eff_output=$(cmd_codewc -t shell "$main_file" 2>/dev/null)
    # Bash 正则替代 grep|head|grep 一串管道
    [[ $main_eff_output =~ 有效行数:[[:space:]]*([0-9]+)   ]] && main_eff_lines=${BASH_REMATCH[1]}
    [[ $main_eff_output =~ 有效单词数:[[:space:]]*([0-9]+) ]] && main_eff_words=${BASH_REMATCH[1]}
    [[ $main_eff_output =~ 有效字符数:[[:space:]]*([0-9]+) ]] && main_eff_chars=${BASH_REMATCH[1]}

    # 资源目录统计：一次遍历, 边算边缓存明细
    local res_total_lines=0 res_total_bytes=0 file_count=0
    local -a detail=()

    if [[ -d "$RESOURCE_DIR" ]]; then
        shopt -s globstar nullglob dotglob
        local -a bash_files=("$RESOURCE_DIR"/**/*.bash)
        shopt -u globstar nullglob dotglob

        local file rel l b
        for file in "${bash_files[@]}"; do
            [[ -f "$file" ]] || continue
            # wc -lc 一次拿行数和字节数(替代两次 wc + 两次 tr)
            read -r l b _ < <(wc -lc < "$file" 2>/dev/null) || true
            [[ -z "$l" ]] && l=0
            [[ -z "$b" ]] && b=0
            rel="${file#"$RESOURCE_DIR"/}"
            detail+=("  $rel: $l 行, $b 字节")
            res_total_lines=$((res_total_lines + l))
            res_total_bytes=$((res_total_bytes + b))
            ((++file_count))
        done
    fi

    local total_lines=$((main_lines + res_total_lines))
    local total_bytes=$((main_bytes + res_total_bytes))

    cecho -b "--- 代码统计 ---"
    cecho "主程序 ($main_name): $main_lines 行, $main_bytes 字节 | 有效: $main_eff_lines 行, $main_eff_words 单词, $main_eff_chars 字符"

    if ((file_count > 0)); then
        cecho -b "资源目录 (共 $file_count 个 .bash 文件):"
        local line
        for line in "${detail[@]}"; do
            cecho "$line"
        done
        cecho "资源目录合计: $res_total_lines 行, $res_total_bytes 字节"
    else
        err "资源目录未发现任何 .bash"
    fi

    cecho -b "总计: $total_lines 行, $total_bytes 字节"
}
# ---------- 主逻辑 ---------
# ps:自定义解析器、命令提示符设定已被移至前面
# 标题
get_title
echo ""
echo ""

# ---------- 初始化临时目录 ----------
# 如果 TMP_DIR 未设置或无效, 则回退到默认
if [ -z "$TMP_DIR" ] || [ ! -d "$TMP_DIR" ] || [ ! -w "$TMP_DIR" ]; then
    if mkdir -p "$SCRIPT_DIR/tmp" 2>/dev/null && [ -w "$SCRIPT_DIR/tmp" ]; then
        TMP_DIR="$SCRIPT_DIR/tmp"
    else
        TMP_DIR="/storage/emulated/0/tmp"
        mkdir -p "$TMP_DIR" 2>/dev/null || true
    fi
fi

# 检查临时目录大小
check_tmpdir_size() {
    if [ -d "$TMP_DIR" ]; then
        local size_mb=$(du -sm "$TMP_DIR" 2>/dev/null | cut -f1)
        [ -z "$size_mb" ] && return 0
        if [ "$size_mb" -gt 1 ]; then
            cecho -b -c 33 "[TMPDIR]临时目录 ($TMP_DIR) 大小达 ${size_mb}MB, 建议使用 TMPDIR -c 清理"
        fi
    fi
}
check_tmpdir_size

# 网络工具提示
    if [ "$net_tools_only_one" -eq 1 ]; then
      if [ "$HAS_CURL" -eq 1 ]; then
        cecho -c 93 -b "[NET] 你只有一个网络工具(CURL), 网络功能可能受限"
    else
        cecho -c 93 -b "[NET] 你只有一个网络工具(WGET), 网络功能可能受限"
    fi
fi

# ---------- 版本更新检查 ----------
# 支持的版本格式:
#   数字段: x.xx / x.xx.x / x.xx.x.x  (逐段比较, 缺省补 0)
#   后缀:
# _pre       第一个预发布版本 (= _pre1)
# _preN      第N个预发布版本 (N >= 1)
# _re        正式版(与无后缀等价)
# _bug_a     当前数字段的 Bug 修复 (字母 a-z)
# 相同数字段排序:
# _pre1 < _pre2 < ... < 正式(无后缀=_re) < _bug_a < _bug_b < ... < 下一数字段

# 配置兜底: 即使配置里漏了, 也不至于让 UPDATE_PRE 为空
UPDATE_PRE="${UPDATE_PRE:-0}"

# 字母 -> 序号 (a=1, b=2, ..., z=26), 无 fork
_letter_ord() {
    local c="$1"
    case "$c" in
        [a-z]) ;;
        *) return 1 ;;
    esac
    local ord
    printf -v ord '%d' "'$c"
    printf '%d' "$((ord - 96))"
}

# 解析版本到全局变量:
#   _PV_MAJOR / _PV_MINOR / _PV_PATCH / _PV_EXTRA   数字段(缺省为 0)
#   _PV_SUFFIX_TYPE   0=_pre  1=正式(含 _re)  2=_bug_*
#   _PV_SUFFIX_VAL    _pre 时=预发布编号(默认1), _bug 时=字母序号(1-26), 正式=0
# 解析失败返回 1, 全程无 fork
_parse_ver() {
    local raw="$1"
    raw="${raw#"${raw%%[![:space:]]*}"}"
    raw="${raw%"${raw##*[![:space:]]}"}"
    raw="${raw#v}"
    raw="${raw#V}"

    local suffix
    if [[ "$raw" =~ ^([0-9]+)\.([0-9]+)(\.([0-9]+))?(\.([0-9]+))?(.*)$ ]]; then
        _PV_MAJOR="${BASH_REMATCH[1]}"
        _PV_MINOR="${BASH_REMATCH[2]}"
        _PV_PATCH="${BASH_REMATCH[4]:-0}"
        _PV_EXTRA="${BASH_REMATCH[6]:-0}"
        suffix="${BASH_REMATCH[7]}"
    else
        return 1
    fi

    _PV_SUFFIX_TYPE=1
    _PV_SUFFIX_VAL=0

    case "$suffix" in
        ""|"_re")
            ;;
        "_pre"*)
            local n="${suffix#_pre}"
            if [ -z "$n" ]; then
                _PV_SUFFIX_VAL=1
            elif [[ "$n" =~ ^[0-9]+$ ]]; then
                _PV_SUFFIX_VAL=$((10#$n))
            else
                return 1
            fi
            _PV_SUFFIX_TYPE=0
            ;;
        "_bug_"*)
            local l="${suffix#_bug_}"
            [[ "$l" =~ ^[a-z]$ ]] || return 1
            _PV_SUFFIX_TYPE=2
            _PV_SUFFIX_VAL=$(_letter_ord "$l") || return 1
            ;;
        *)
            return 1
            ;;
    esac
    return 0
}

# 比较版本, 结果放入 _VER_CMP_RESULT
#   1: v1 > v2    0: v1 == v2    -1: v1 < v2    ?: 解析失败
# 全程无 fork
_VER_CMP_RESULT=""
_ver_cmp_g() {
    local v1="$1" v2="$2"

    if ! _parse_ver "$v1"; then
        _VER_CMP_RESULT="?"
        return 0
    fi
    local a_major="$_PV_MAJOR" a_minor="$_PV_MINOR" a_patch="$_PV_PATCH" a_extra="$_PV_EXTRA"
    local a_type="$_PV_SUFFIX_TYPE" a_val="$_PV_SUFFIX_VAL"

    if ! _parse_ver "$v2"; then
        _VER_CMP_RESULT="?"
        return 0
    fi
    local b_major="$_PV_MAJOR" b_minor="$_PV_MINOR" b_patch="$_PV_PATCH" b_extra="$_PV_EXTRA"
    local b_type="$_PV_SUFFIX_TYPE" b_val="$_PV_SUFFIX_VAL"

    _VER_CMP_RESULT=0
    if   (( a_major != b_major )); then
        if (( a_major > b_major )); then _VER_CMP_RESULT=1; else _VER_CMP_RESULT=-1; fi
    elif (( a_minor != b_minor )); then
        if (( a_minor > b_minor )); then _VER_CMP_RESULT=1; else _VER_CMP_RESULT=-1; fi
    elif (( a_patch != b_patch )); then
        if (( a_patch > b_patch )); then _VER_CMP_RESULT=1; else _VER_CMP_RESULT=-1; fi
    elif (( a_extra != b_extra )); then
        if (( a_extra > b_extra )); then _VER_CMP_RESULT=1; else _VER_CMP_RESULT=-1; fi
    elif (( a_type != b_type )); then
        if (( a_type > b_type )); then _VER_CMP_RESULT=1; else _VER_CMP_RESULT=-1; fi
    elif (( a_val != b_val )); then
        if (( a_val > b_val )); then _VER_CMP_RESULT=1; else _VER_CMP_RESULT=-1; fi
    fi
    return 0
}

# v1 >= v2 返回 0(真), 无 fork
_ver_ge() {
    _ver_cmp_g "$1" "$2"
    [ "$_VER_CMP_RESULT" -ge 0 ] 2>/dev/null
}

# 从任意字符串中提取第一个版本号到 _EXTRACTED_VER, 无 fork
_EXTRACTED_VER=""
_extract_ver_g() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    if [[ "$s" =~ [vV]?([0-9]+\.[0-9]+(\.[0-9]+)?(\.[0-9]+)?(_pre[0-9]*|_re|_bug_[a-z])?) ]]; then
        _EXTRACTED_VER="${BASH_REMATCH[1]}"
        return 0
    fi
    return 1
}

# 获取远程所有 release, 汇总最高正式版和最高预发布版
# 输出(制表符): re_name  re_tag  re_ver  pre_name  pre_tag  pre_ver
# 关键优化: 单次 curl/wget + 单次 awk 输出 (tag pre draft) 三元组, bash 内零 fork 比较
_get_remote_versions() {
    local url="https://api.github.com/repos/DC10Xraya/Android-CMD/releases?per_page=100"
    local json=""

    if [ "$HAS_CURL" -eq 1 ]; then
        json=$($_CURL -s -L --connect-timeout 5 \
            -H 'Accept: application/vnd.github+json' \
            -H 'User-Agent: Android-CMD' \
            "$url" 2>/dev/null)
    elif [ "$HAS_WGET" -eq 1 ]; then
        json=$($_WGET -qO- --timeout=5 \
            --header='Accept: application/vnd.github+json' \
            --header='User-Agent: Android-CMD' \
            "$url" 2>/dev/null)
    else
        return 1
    fi

    [ -z "$json" ] && return 1

    local re_name="" re_tag="" re_ver=""
    local pre_name="" pre_tag="" pre_ver=""
    local tag pre draft ver

    while IFS=' ' read -r tag pre draft; do
        [ -z "$tag" ] && continue
        [ "$draft" = "true" ] && continue

        _extract_ver_g "$tag" || continue
        ver="$_EXTRACTED_VER"

        if [ "$pre" = "true" ]; then
            if [ -z "$pre_ver" ]; then
                pre_name="$tag"; pre_tag="$tag"; pre_ver="$ver"
            else
                _ver_cmp_g "$ver" "$pre_ver"
                if [ "$_VER_CMP_RESULT" = "1" ]; then
                    pre_name="$tag"; pre_tag="$tag"; pre_ver="$ver"
                fi
            fi
        else
            if [ -z "$re_ver" ]; then
                re_name="$tag"; re_tag="$tag"; re_ver="$ver"
            else
                _ver_cmp_g "$ver" "$re_ver"
                if [ "$_VER_CMP_RESULT" = "1" ]; then
                    re_name="$tag"; re_tag="$tag"; re_ver="$ver"
                fi
            fi
        fi
    done < <(
        printf '%s' "$json" | $_AWK '
            BEGIN { RS = "\"tag_name\"" ; ORS = "\n" }
            NR > 1 {
                line = $0
                sub(/^[^"]*"/, "", line)
                sub(/".*/, "", line)
                if (line == "") next
                pre = "false"; draft = "false"
                if ($0 ~ /"prerelease"[[:space:]]*:[[:space:]]*true/) pre = "true"
                if ($0 ~ /"draft"[[:space:]]*:[[:space:]]*true/) draft = "true"
                print line " " pre " " draft
            }
        '
    )

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$re_name" "$re_tag" "$re_ver" \
        "$pre_name" "$pre_tag" "$pre_ver"
}

_update_cache="$TMP_DIR/latest_version"
_update_prompted=0
_update_check_count=0
# 后台执行检查(异步, 失败静默)
(
    rm -f "$_update_cache"

    _upd_info=$(_get_remote_versions 2>/dev/null) || exit 0
    IFS=$'\t' read -r _upd_re_name _upd_re_tag _upd_re_ver \
                    _upd_pre_name _upd_pre_tag _upd_pre_ver <<< "$_upd_info"

    _extract_ver_g "$CMD_VER"
    _upd_cur="$_EXTRACTED_VER"
    [ -z "$_upd_cur" ] && exit 0

    _upd_name=""; _upd_tag=""; _upd_ver=""

    if [ "$UPDATE_PRE" = "1" ]; then
        # 关注预发布: 取 pre / re 中较高者提示
        if [ -n "$_upd_pre_ver" ] && [ -n "$_upd_re_ver" ]; then
            _ver_cmp_g "$_upd_pre_ver" "$_upd_re_ver"
            if [ "$_VER_CMP_RESULT" = "1" ]; then
                _upd_name="$_upd_pre_name"; _upd_tag="$_upd_pre_tag"; _upd_ver="$_upd_pre_ver"
            else
                _upd_name="$_upd_re_name"; _upd_tag="$_upd_re_tag"; _upd_ver="$_upd_re_ver"
            fi
        elif [ -n "$_upd_pre_ver" ]; then
            _upd_name="$_upd_pre_name"; _upd_tag="$_upd_pre_tag"; _upd_ver="$_upd_pre_ver"
        else
            _upd_name="$_upd_re_name"; _upd_tag="$_upd_re_tag"; _upd_ver="$_upd_re_ver"
        fi
    else
        # 不关注预发布: 只提示正式版
        _upd_name="$_upd_re_name"; _upd_tag="$_upd_re_tag"; _upd_ver="$_upd_re_ver"
    fi

    if [ -n "$_upd_ver" ] && [ -n "$_upd_cur" ]; then
        if ! _ver_ge "$_upd_cur" "$_upd_ver"; then
            printf '%s\n%s\n' "$_upd_name" "$_upd_tag" > "$_update_cache"
        fi
    fi
) >/dev/null 2>&1 &

cmd_update() {
    if [ "${1:-}" = "--pre" ]; then
        if [ $# -ne 2 ]; then
            err "用法: UPDATE --pre <0|1>"
            return 1
        fi
        case "$2" in
            0|1)
                UPDATE_PRE="$2"
                save_config
                if [ "$UPDATE_PRE" = "1" ]; then
                    cecho "已关注预发布版本 (UPDATE --pre 1)"
                else
                    cecho "已取消关注预发布版本 (UPDATE --pre 0)"
                fi
                return 0
                ;;
            *)
                err "UPDATE --pre 只接受 0 或 1"
                return 1
                ;;
        esac
    fi

    if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        cecho -b "用法: UPDATE [--pre <0|1>]"
        cecho "  --pre 0    不关注预发布(默认)"
        cecho "  --pre 1    关注预发布，同时比较正式版和预发布版"
        return 0
    fi

    if [ $# -gt 0 ]; then
        err "未知参数: $1, 使用 UPDATE -h 查看帮助"
        return 1
    fi

    local info
    info=$(_get_remote_versions) || {
        err "获取发布信息失败, 请检查网络"
        cecho -c "#6CA8F1" -u "https://github.com/DC10Xraya/Android-CMD/releases"
        return 1
    }

    local re_name re_tag re_ver
    local pre_name pre_tag pre_ver
    IFS=$'\t' read -r re_name re_tag re_ver pre_name pre_tag pre_ver <<< "$info"

    _extract_ver_g "$CMD_VER"
    local current_ver="$_EXTRACTED_VER"
    if [ -z "$current_ver" ]; then
        err "无法解析当前版本: $CMD_VER"
        return 1
    fi

    local release_url="https://github.com/DC10Xraya/Android-CMD/releases"
    local tag_url_re=""
    local tag_url_pre=""
    [ -n "$re_tag" ]  && tag_url_re="$release_url/tag/$re_tag"
    [ -n "$pre_tag" ] && tag_url_pre="$release_url/tag/$pre_tag"

    local cmp_re_now cmp_pre_now cmp_pre_re

    # ================= UPDATE_PRE=0：只看正式版 =================
    if [ "$UPDATE_PRE" != "1" ]; then
        if [ -z "$re_ver" ]; then
            err "未找到正式版本"
            cecho -c "#6CA8F1" -u "$release_url"
            return 1
        fi

        _ver_cmp_g "$re_ver" "$current_ver"
        cmp_re_now="$_VER_CMP_RESULT"

        case "$cmp_re_now" in
            1)
                cecho -c 96 "发现新正式版: $re_name"
                cecho -c 96 "当前版本: $CMD_VER"
                cecho -c "#6CA8F1" -u "$tag_url_re"
                ;;
            0)
                cecho -c 92 "已是最新正式版: $re_name"
                cecho -c "#6CA8F1" -u "$release_url"
                ;;
            -1)
                # 当前比正式版新, 判断是否是预发布版本
                local is_pre_release=0
                if [ -n "$pre_ver" ]; then
                    _ver_cmp_g "$pre_ver" "$current_ver"
                    cmp_pre_now="$_VER_CMP_RESULT"
                    [ "$cmp_pre_now" = "0" ] && is_pre_release=1
                fi

                if [ "$is_pre_release" -eq 1 ]; then
                    cecho -c 93 "当前是预发布版本: $pre_name"
                    cecho -c 90 "最新正式版: $re_name"
                    cecho -c 90 "使用 UPDATE --pre 1 可关注预发布版本"
                    cecho -c "#6CA8F1" -u "$release_url"
                else
                    err "未知版本: 当前版本高于仓库所有正式/预发布版本"
                    cecho -c 93 "当前版本: $CMD_VER"
                    cecho -c 93 "最新正式: $re_name"
                    [ -n "$pre_ver" ] && cecho -c 93 "最新预发布: $pre_name"
                    cecho -c "#6CA8F1" -u "$release_url"
                fi
                ;;
            *)
                err "版本比较失败"
                return 1
                ;;
        esac

        rm -f "$_update_cache"
        return 0
    fi

    # ================= UPDATE_PRE=1：关注预发布 =================
    if [ -z "$pre_ver" ] && [ -z "$re_ver" ]; then
        err "仓库无可用版本"
        cecho -c "#6CA8F1" -u "$release_url"
        return 1
    fi

    # 只有正式版
    if [ -z "$pre_ver" ]; then
        cecho -c 93 "仓库暂无预发布版本，按正式版处理"
        _ver_cmp_g "$re_ver" "$current_ver"
        cmp_re_now="$_VER_CMP_RESULT"
        case "$cmp_re_now" in
            1)
                cecho -c 96 "发现新正式版: $re_name"
                cecho -c "#6CA8F1" -u "$tag_url_re"
                ;;
            0)
                cecho -c 92 "已是最新正式版: $re_name"
                cecho -c "#6CA8F1" -u "$release_url"
                ;;
            -1)
                err "未知版本: 当前版本高于仓库最新正式版"
                cecho -c 93 "当前版本: $CMD_VER"
                cecho -c 93 "最新正式: $re_name"
                cecho -c "#6CA8F1" -u "$release_url"
                ;;
            *)
                err "版本比较失败"
                return 1
                ;;
        esac
        rm -f "$_update_cache"
        return 0
    fi

    # 只有预发布版
    if [ -z "$re_ver" ]; then
        _ver_cmp_g "$pre_ver" "$current_ver"
        cmp_pre_now="$_VER_CMP_RESULT"
        case "$cmp_pre_now" in
            1)
                cecho -c 96 "发现新预发布版本: $pre_name (PRE)"
                cecho -c "#6CA8F1" -u "$tag_url_pre"
                ;;
            0)
                cecho -c 92 "已是最新预发布版本: $pre_name (PRE)"
                cecho -c "#6CA8F1" -u "$release_url"
                ;;
            -1)
                err "未知版本: 当前版本高于仓库最新预发布版"
                cecho -c 93 "当前版本: $CMD_VER"
                cecho -c 93 "最新预发布: $pre_name"
                cecho -c "#6CA8F1" -u "$release_url"
                ;;
            *)
                err "版本比较失败"
                return 1
                ;;
        esac
        rm -f "$_update_cache"
        return 0
    fi

    _ver_cmp_g "$pre_ver" "$re_ver"
    cmp_pre_re="$_VER_CMP_RESULT"
    _ver_cmp_g "$pre_ver" "$current_ver"
    cmp_pre_now="$_VER_CMP_RESULT"
    _ver_cmp_g "$re_ver" "$current_ver"
    cmp_re_now="$_VER_CMP_RESULT"

    if [ "$cmp_pre_re" = "1" ]; then
        # 正常情况: pre > re
        if [ "$cmp_re_now" = "1" ]; then
            # pre > re > now
            cecho -c 96 "发现新正式版: $re_name"
            cecho -c 96 "发现新预发布: $pre_name (PRE)"
            cecho -c 90 "当前版本: $CMD_VER"
            cecho -c "#6CA8F1" -u "$tag_url_pre"
            cecho -c "#6CA8F1" -u "$tag_url_re"

        elif [ "$cmp_re_now" = "0" ]; then
            # pre > re = now
            cecho -c 93 "当前已是最新正式版: $re_name"
            cecho -c 96 "发现新预发布: $pre_name (PRE)"
            cecho -c "#6CA8F1" -u "$tag_url_pre"

        else
            # now > re
            if [ "$cmp_pre_now" = "0" ]; then
                # pre = now > re
                cecho -c 92 "已是最新预发布版本: $pre_name (PRE)"
                cecho -c 90 "最新正式版: $re_name"
                cecho -c "#6CA8F1" -u "$release_url"

            elif [ "$cmp_pre_now" = "-1" ]; then
                # now > pre > re
                err "未知版本: 当前版本高于仓库所有正式/预发布版本"
                cecho -c 93 "当前版本: $CMD_VER"
                cecho -c 93 "最新正式: $re_name"
                cecho -c 93 "最新预发布: $pre_name"
                cecho -c "#6CA8F1" -u "$release_url"

            else
                # pre > now > re
                cecho -c 96 "当前超过正式版，发现新预发布: $pre_name (PRE)"
                cecho -c 90 "当前版本: $CMD_VER   最新正式: $re_name"
                cecho -c "#6CA8F1" -u "$tag_url_pre"
            fi
        fi
    else
        # 异常/少见情况: re >= pre
        err "版本关系异常: 正式版 $re_ver 不低于预发布 $pre_ver"

        if [ "$cmp_re_now" = "1" ]; then
            cecho -c 96 "发现新正式版: $re_name"
            cecho -c 90 "预发布: $pre_name 较旧，忽略"
            cecho -c "#6CA8F1" -u "$tag_url_re"

        elif [ "$cmp_re_now" = "0" ]; then
            cecho -c 92 "已是最新正式版: $re_name"
            cecho -c "#6CA8F1" -u "$release_url"

        else
            err "未知版本: 当前版本高于仓库所有正式/预发布版本"
            cecho -c 93 "当前版本: $CMD_VER"
            cecho -c 93 "最新正式: $re_name"
            cecho -c 93 "最新预发布: $pre_name"
            cecho -c "#6CA8F1" -u "$release_url"
        fi
    fi

    rm -f "$_update_cache"
    return 0
}

# ---------- 命令分发 ----------
# 参数: $1 = 命令名(大小写不敏感), $2... = 参数
_dispatch_cmd() {
    local cmd="${1,,}"
    shift
    local args_array=("$@")
    case "$cmd" in
    copy|cp)           cmd_copy "${args_array[@]}" ;;
    del|rm|erase)      cmd_del "${args_array[@]}" ;;
    md|mkdir)          cmd_md "${args_array[@]}" ;;
    dir|ls)            cmd_dir "${args_array[@]}" ;;
    touch|new)         cmd_touch "${args_array[@]}" ;;
    move|ren|rename)   cmd_move "${args_array[@]}" ;;
    rd|rmdir)          cmd_rd "${args_array[@]}" ;;
    ln|link)           cmd_ln "${args_array[@]}" ;;
    head|h)            cmd_head "${args_array[@]}" ;;
    tail|t)            cmd_tail "${args_array[@]}" ;;
    dd|diskdd)         cmd_dd "${args_array[@]}" ;;
    cgrep)             cmd_cgrep "${args_array[@]}" ;;
    pwd)               cmd_pwd "${args_array[@]}" ;;
    now|date)          cmd_date "${args_array[@]}" ;;
    env|export)        cmd_env "${args_array[@]}" ;;
    exts|exes)         cmd_exts "${args_array[@]}" ;;
    tl|tasklist)       cmd_tasklist ;;
    help|\?|/\?|/？|？) QAQ_cmd_help ;;
    cls|clear)         cmd_cls "${args_array[@]}" ;;
    clsd|cleard)       cmd_clsd "${args_array[@]}" ;;
    echo|print)        cmd_echo "${args_array[@]}" ;;
    exit|exit15)       cmd_exit15 ;;
    exitk|killself)    cmd_killself ;;
    info)              cmd_info ;;
    etc|config)        cmd_config "${args_array[@]}" ;;
    c|cmd|eval)        cmd_cmd "${args_array[@]}" ;;
    cc|multicmd|mc)    cmd_cc ;;
    sh|run|r)          cmd_sh "${args_array[@]}" ;;
    fun|function)      cmd_fun "${args_array[@]}" ;;
    # ---------- 显式调用 ----------
    df)
    if [ ${#args_array[@]} -eq 0 ]; then
        $_DF -h 2>&1 | while IFS= read -r line; do cecho "$line"; done
    else
        $_DF "${args_array[@]}" 2>&1 | while IFS= read -r line; do cecho "$line"; done
    fi
    ;;
    home)
    if [ "${args_array[0]:-}" = "set" ] && [ -n "${args_array[1]:-}" ]; then
        _newhome="${args_array[1]}"
        if confirm "确定更改HOME目录? (可能导致一大堆莫名其妙的问题)"; then
            export HOME="$_newhome"
            cecho "HOME 已更新"
        else
            echo ""
        fi
    else
        cecho "$HOME"
    fi
    ;;
    scriptdir|sdir)    cecho "$SCRIPT_DIR" ;;
    self)              cecho "$0" ;;
    netstat)
    if [ ${#args_array[@]} -eq 0 ]; then
        $_NETSTAT 2>&1 | while IFS= read -r line; do cecho "$line"; done
    else
        $_NETSTAT "${args_array[@]}" 2>&1 | while IFS= read -r line; do cecho "$line"; done
    fi
    ;;
    hostname)
    if [ ${#args_array[@]} -eq 0 ]; then
        cecho "$($_HOSTNAME 2>/dev/null || echo 'localhost')"
    else
        $_HOSTNAME "${args_array[@]}" 2>&1 | while IFS= read -r line; do cecho "$line"; done
    fi
    ;;
    printf)            printf "${args_array[@]}"; echo "" ;;
    err)               err "${args_array[*]}" ;;
    cd)                cd "${args_array[*]}" ;;
    # ---------- debug/laugh ------------
    debug|debug_|debug__|debug_help|help_debug|debughelp|helpdebug|debug___|debug_help_|help_debug_)
        err "调试模式还在设计中(真的吗?)" ;;
    debug_1)                    err "No Way" ;;
    debug_2|debug_wc|codewcme)  debug_2 ;;
    debug_0|debug_lev)          debug_0 "${args_array[@]}" ;;
    # brooooooo
    $CMD_delimiter|cmd_delimiter|$CMD_delimiter/cmd_delimiter)   err "bro 复制这个何意味?" ;;
    $USERNAME)    cmd_username ;;
    911)          err "bro 这并不好笑" ;;
    ctrl+c|^c)    cmd_exit15_0 ;;
    helo)         err "helo: 命令未找到: 你打错了help吧" ;;
    deta)         err "deta: 命令未找到: 你打错了date吧" ;;
    '?!'|'?！'|'？!'|'？！'|'!?'|'!？'|'！?'|'！？')   err '?!问号和感叹号!?' ;;
    # ---------- laugh ----------
    114514)     lazy_load "laugh_114514" && cmd_laugh_114514 ;;
    100|dve100) lazy_load "laugh_100" && cmd_laugh_100 ;;
    200|dev200) lazy_load "laugh_200" && cmd_laugh_200 ;;
    yesyesyes|yyy|yy|yesyes) lazy_load "laugh_yyy" && cmd_laugh_yyy ;;
    command|commandnotfound) lazy_load "laugh_command_not_found" && cmd_laugh_command_not_found "${args_array[@]}" ;;
    permission|permissiondenied) lazy_load "laugh_permission_denied" && cmd_laugh_permission_denied "${args_array[@]}" ;;
    mcserver)     lazy_load "laugh_mcserver" && cmd_laugh_mcserver ;;
    walmart)      lazy_load "laugh_walmart" && cmd_laugh_walmart ;;
    wtf)
        lazy_load "hack"  # 预加载依赖
        lazy_load "laugh_wtf" && cmd_laugh_wtf ;;
    wtf2)
        lazy_load "hack2" # 预加载依赖
        lazy_load "laugh_wtf2" && cmd_laugh_wtf2 ;;
    netneig|netneigh|netneighbor)  
        lazy_load "scan"  # 预加载依赖
        lazy_load "netneig" && cmd_netneig ;;
    ping6)
        lazy_load "ping" # 预加载依赖
        lazy_load "ping6" && cmd_ping6 "${args_array[@]}" ;;
    # ---------- 资源目录别名 ----------
    codewc|wccode) lazy_load "codewc" && cmd_codewc "${args_array[@]}" ;;
    tm|top|taskmgr|taskmanager) lazy_load "taskmanager" && cmd_taskmanager ;;
    systeminfo|sysinfo) lazy_load "systeminfo" && cmd_systeminfo ;;
    300|china)   lazy_load "china" && cmd_china "${args_array[@]}" ;;
    # 哈希/编码类合集: resource/psd/cmd_checksum.bash
    sha256|sha256sum)          lazy_load checksum && cmd_sha256 "${args_array[@]}" ;;
    sha1|sha1sum)              lazy_load checksum && cmd_sha1   "${args_array[@]}" ;;
    sha224|sha224sum)          lazy_load checksum && cmd_sha224 "${args_array[@]}" ;;
    sha384|sha384sum)          lazy_load checksum && cmd_sha384 "${args_array[@]}" ;;
    sha512|sha512sum)          lazy_load checksum && cmd_sha512 "${args_array[@]}" ;;
    md5|md5sum)                lazy_load checksum && cmd_md5    "${args_array[@]}" ;;
    b2sum|blake2)              lazy_load checksum && cmd_b2sum  "${args_array[@]}" ;;
    crc32)                     lazy_load checksum && cmd_crc32  "${args_array[@]}" ;;
    b64|base64)                lazy_load checksum && cmd_base64 "${args_array[@]}" ;;
    b32|base32)                lazy_load checksum && cmd_base32 "${args_array[@]}" ;;
    # 计算器合集: resource/other/cmd_calc_all.bash
    awkc)                      lazy_load calc_all && cmd_awkc "${args_array[@]}" ;;
    bc)                        lazy_load calc_all && cmd_bc "${args_array[@]}" ;;
    # ---------- 自定义函数 / 懒惰加载 / 系统命令(tip) / 未知命令 ----------
    # 大部分命令直接通过lazy load加载(在lazy load的内部检查函数是否已定义, 如果已经定义就直接加载)
    *)
    # 优先执行用户自定义函数
    if type -t "$cmd" >/dev/null 2>&1 && [[ $(type -t "$cmd") == "function" ]]; then
        "$cmd" "${args_array[@]}"
    else
        # 尝试加载资源文件中的函数
        if lazy_load "$cmd"; then
            "cmd_$cmd" "${args_array[@]}"
        else
            if command -v "$cmd" >/dev/null 2>&1; then
               _full="C $cmd"
               [ ${#args_array[@]} -gt 0 ] && _full+=" ${args_array[*]}"
               [ ${#_full} -gt 30 ] && _full="${_full:0:27}..."
               cecho -c 90 "$cmd: 系统命令(使用 \"$_full\" 来执行)"
        else
    err "$cmd: 命令未找到"
fi
        fi
    fi
    ;;
esac
}
# SP 版本提示符调色板(固定, 提前构建避免每轮重建数组)
SP_PALETTE=(196 202 208 214 220 226 46 51 21 27 33 39 45 81 117 153 129 165 201 207 213 219 225)
SP_PAL_LEN=${#SP_PALETTE[@]}
# ---------- 主循环 ----------
while true; do
    # 判断是否使用默认颜色(黑底亮白)
    if [ "$BG" = "40" ] && [ "$FG" = "97" ]; then
        case "$PRIV_LEVEL" in
            root) CMD_prompt_fg___=95 ;;   # 紫色
            adb)  CMD_prompt_fg___=96 ;;   # 蓝色
            *)    CMD_prompt_fg___=97 ;;   # 普通用户亮白
        esac
    else
        CMD_prompt_fg___="$FG"             # 跟随用户自定义
    fi
    # sp
    if [ $_IAMDC10XRAY_ -eq 1 ]; then
        CMD_prompt_fg___='38;5;201'
    fi

    # 显示更新提示(仅检查5次)
    if [ $_update_prompted -eq 0 ] && [ $_update_check_count -lt 5 ]; then
        if [ -f "$_update_cache" ] && [ -s "$_update_cache" ]; then
            new_name=""
            new_tag=""
            {
                IFS= read -r new_name
                IFS= read -r new_tag
            } < "$_update_cache"
            cecho -c 96 -b "[UPDATE]发现新版本: $new_name ($new_tag) (使用 UPDATE 查看详情)"
            _update_prompted=1
            rm -f "$_update_cache"
        else
            _update_check_count=$((_update_check_count + 1))
        fi
    fi

    # 构建命令提示符
    # 避免长输入时回绕、光标错位、提示符重复渲染
    if [ "$_IAMDC10XRAY_" = "1" ]; then
        # SP 版本: 用户名逐字符彩虹着色, 字符数与用户名一致
        _sp_len=${#USERNAME}
        _sp_prompt=""
        for (( _sp_i=0; _sp_i<_sp_len; _sp_i++ )); do
            printf -v _sp_seg '\001\033[%s;38;5;%sm\002%s' \
                "$BG" "${SP_PALETTE[$(( _sp_i % SP_PAL_LEN ))]}" "${USERNAME:_sp_i:1}"
            _sp_prompt+="$_sp_seg"
        done
        # 符号沿用 SP 粉紫主色(201)
        printf -v PROMPT_STR '%s\001\033[%s;38;5;201m\002%s \001\033[0m\002' \
            "$_sp_prompt" "$BG" "$PROMPT_SYMBOL"
    else
        printf -v PROMPT_STR '\001\033[%s;%sm\002%s%s \001\033[0m\002' \
            "$BG" "$CMD_prompt_fg___" "$USERNAME" "$PROMPT_SYMBOL"
    fi

    if ! read -e -r -p "$PROMPT_STR" input; then
        cmd_exit15
    fi

    # 判断空输入或纯注释
    ignore=0
    if [ -z "$input" ]; then
        ignore=1
    else
        # 去除首尾空格
        trimmed="${input#"${input%%[![:space:]]*}"}"
        trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
        if [ -z "$trimmed" ] || [[ "$trimmed" == \#* ]]; then
            ignore=1
        fi
    fi

    if [ $ignore -eq 1 ]; then
        printf '\033[0m'      # 只重置颜色, 不换行
        continue
    fi

    # 非忽略输入: 记录历史并换行
    history -s "$input"    # 添加到当前会话历史
    history -w "$HISTFILE" # 立即写入文件
    printf '\033[0m\n'

    # dev0.205核心更新: 使用自定义解析器(谁还记得dev0.56的IFS)
    parse_line "$input"
    if [ ${#PARSED_ARGS[@]} -eq 0 ]; then
        continue
    fi

    # 提取命令(第一个单词, 转为小写)和参数数组
    cmd="${PARSED_ARGS[0],,}"
    args_array=("${PARSED_ARGS[@]:1}")

    # 命令分发(统一入口见上)
    _dispatch_cmd "$cmd" "${args_array[@]}"
done