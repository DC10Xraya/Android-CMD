#!/bin/bash
# Android CMD(VER: ⤸)
CMD_VER="0.10 (dev0.230)"
# MIT License
# Copyright (c) 2026 DC10Xray
# https://github.com/DC10Xraya/Android-CMD

# ---------运行前---------
ulimit -u 1024
err() { printf "\033[31m%s\033[0m\n" "$*" >&2; }
CMD_RUNNING_Err_title="----------------CMD ERROR----------------"
CMD_Target="要求:必须由 bash 4.0+ 执行,且支持数组特性"

#bash 
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

#必须工具
MISSING=""
for cmd in awk grep sed cat cut head tail bc; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING="$MISSING $cmd"
    fi
done
if [ -n "$MISSING" ]; then
    err "$CMD_RUNNING_Err_title"
    err "缺少以下必须命令: $MISSING"
    err "请安装对应的软件包, 否则无法启动"
    exit 127
fi

echo -e "\033[32m---------------CMD Running---------------\033[0m"

# ------- 工具检测 -------
init_tools() {
    if command -v busybox >/dev/null 2>&1; then
        _AWK="busybox awk"; _CAT="busybox cat"; _CUT="busybox cut"
        _DATE="busybox date"; _GREP="busybox grep"; _HEAD="busybox head"
        _HOSTNAME="busybox hostname"; _IFCONFIG="busybox ifconfig"
        _IP="busybox ip"; _LS="busybox ls"; _MKDIR="busybox mkdir"
        _MV="busybox mv"; _CP="busybox cp"; _RM="busybox rm"
        _RMDIR="busybox rmdir"; _NETSTAT="busybox netstat"
        _PS="busybox ps"; _PING="busybox ping"; _UPTIME="busybox uptime"
        _WHOAMI="busybox whoami"; _FREE="busybox free"; _DF="busybox df"
        _UNAME="busybox uname"; _SED="busybox sed"; _FIND="busybox find"
        _SORT="busybox sort"; _TAIL="busybox tail"; _STAT="busybox stat"
        _WGET="busybox wget"; _CURL="busybox curl"
    else
        _AWK="awk"; _CAT="cat"; _CUT="cut"; _DATE="date"; _GREP="grep"
        _HEAD="head"; _HOSTNAME="hostname"; _IFCONFIG="ifconfig"
        _IP="ip"; _LS="ls"; _MKDIR="mkdir"; _MV="mv"; _CP="cp"
        _RM="rm"; _RMDIR="rmdir"; _NETSTAT="netstat"; _PS="ps"
        _PING="ping"; _UPTIME="uptime"; _WHOAMI="whoami"; _FREE="free"
        _DF="df"; _UNAME="uname"; _SED="sed"; _FIND="find"; _SORT="sort"
        _TAIL="tail"; _STAT="stat"
        _WGET="wget"; _CURL="curl"
    fi
}
init_tools

#------------------------------------------
# ------------------初始化------------------
CMD_delimiter="----------------------------------------------------"
# ---------- 主逻辑part:自定义命令行解析器 BETA ----------
PARSED_ARGS=()   # 全局数组, 存储解析后的参数
# 解析一行输入, 结果存入 PARSED_ARGS
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
        if [ $escape -eq 1 ]; then
            current="$current$char"
            escape=0
            continue
        fi
        if [ $in_single -eq 0 ] && [ $in_double -eq 0 ]; then
            case "$char" in
                "'")
                    in_single=1
                    continue
                    ;;
                '"')
                    in_double=1
                    continue
                    ;;
                "\\")
                    escape=1
                    continue
                    ;;
                "#")
                    # 注释开始, 截断剩余内容
                    break
                    ;;
                [[:space:]])
                    if [ -n "$current" ]; then
                        result+=("$current")
                        current=""
                    fi
                    continue
                    ;;
                *)
                    current="$current$char"
                    ;;
            esac
        elif [ $in_single -eq 1 ]; then
            if [ "$char" = "'" ] && [ $escape -eq 0 ]; then
                in_single=0
            else
                current="$current$char"
            fi
        elif [ $in_double -eq 1 ]; then
            if [ "$char" = '"' ] && [ $escape -eq 0 ]; then
                in_double=0
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
# c或者cb支持两位数字颜色码和16进制颜色码
# 当 BG 为 40 或 100(背景为0)时,不输出背景(所以请强制使用黑色背景控制台,命令提示符无论何时都有背景)
_cprint() {
    local opt_n=false
    local custom_fg=""   # 可以是 "31" 或 "#FF0000"
    local custom_bg=""   # 可以是 "41" 或 "#00FF00"
    local bold=0 italic=0 underline=0 strikethrough=0
    local plain=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n) opt_n=true; shift ;;
            -c) custom_fg="$2"; shift 2 ;;
            -cb) custom_bg="$2"; shift 2 ;;
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

    # 构建属性列表(样式 + 背景 + 前景)
    local attrs=()
    [ $bold -eq 1 ] && attrs+=("1")
    [ $italic -eq 1 ] && attrs+=("3")
    [ $underline -eq 1 ] && attrs+=("4")
    [ $strikethrough -eq 1 ] && attrs+=("9")

    # ---背景色处理---
    local bg_code=""
    if [ -n "$custom_bg" ]; then
        if [[ "$custom_bg" =~ ^#([0-9A-Fa-f]{6})$ ]]; then
            # 十六进制颜色,转换为 48;2;R;G;B
            local r=$((16#${BASH_REMATCH[1]:0:2}))
            local g=$((16#${BASH_REMATCH[1]:2:2}))
            local b=$((16#${BASH_REMATCH[1]:4:2}))
            bg_code="48;2;$r;$g;$b"
        else
            # 纯数字颜色码
            bg_code="$custom_bg"
        fi
    elif [ "$BG" != "40" ] && [ "$BG" != "100" ]; then
        bg_code="$BG"
    fi

    # ---前景色处理---
    local fg_code=""
    if [ -n "$custom_fg" ]; then
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

    # 将背景码和前景码加入属性列表
    [ -n "$bg_code" ] && attrs+=("$bg_code")
    attrs+=("$fg_code")

    # 生成转义序列
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
#   无引号展开变量, 带引号不展开
#   ccat "可选文件路径(支持相对路径,使用脚本自身路径拼接)" << "EOF"
#   普通行(默认颜色)
#   //cecho -c 93 "特殊颜色文本"
#   EOF
ccat() {
    local input_file=""
    if [ $# -eq 0 ]; then
        input_file="/dev/stdin"
    elif [ $# -eq 1 ]; then
        local user_path="$1"
        # 如果已经是绝对路径，直接使用
        if [[ "$user_path" = /* ]]; then
            input_file="$user_path"
        else
            # 先尝试当前目录
            if [ -f "$user_path" ]; then
                input_file="$user_path"
            # 再尝试脚本目录
            elif [ -f "$SCRIPT_DIR/$user_path" ]; then
                input_file="$SCRIPT_DIR/$user_path"
            else
                err "ccat: 文件不存在: $user_path (当前目录和脚本目录均未找到)"
                return 1
            fi
        fi
        # 最后确认确实是普通文件
        if [ ! -f "$input_file" ]; then
            err "ccat: 不是普通文件: $input_file"
            return 1
        fi
    else
        err "ccat: 用法: ccat [文件]  (无参数时从标准输入读取)"
        return 1
    fi

    local line
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*//cecho[[:space:]]+(.*) ]]; then
            local args="${BASH_REMATCH[1]}"
            if [[ ! "$args" =~ .*[\'\"][^\'\"]*[\'\"]$ ]]; then
                err "ccat: //cecho 内容必须用引号包裹: $line"
                continue
            fi
            parse_line "$args"
            if [ ${#PARSED_ARGS[@]} -eq 0 ]; then
                err "ccat: //cecho 缺少参数"
                continue
            fi
            cecho "${PARSED_ARGS[@]}"
        else
            cecho "$line"
        fi
    done < "$input_file"
}

# -------- 懒惰加载 --------
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
TMP_DIR=""    # 临时目录, 稍后初始化

load_config() {
    if [ -f "$COLOR_CONFIG_FILE" ]; then
        while IFS='=' read -r key value; do
            [[ -z "$key" || "$key" == \#* ]] && continue
            key="$(echo "$key" | xargs)"
            value="$(echo "$value" | xargs)"
            case "$key" in
                BG)   BG="$value" ;;
                FG)   FG="$value" ;;
                CLS_TITLE) CLS_TITLE="${value:-1}" ;;
                TMPDIR) TMP_DIR="$value" ;;
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
    } > "$COLOR_CONFIG_FILE" 2>/dev/null
}

load_config

cmd_config() {
    if [ "$1" = "-r" ] || [ "$1" = "--reset" ]; then
        if confirm "确定重置所有配置为默认值吗?"; then
            BG=40; FG=97; CLS_TITLE=1; CUSTOM_TITLE=""
            if mkdir -p "$SCRIPT_DIR/tmp" 2>/dev/null; then
                TMP_DIR="$SCRIPT_DIR/tmp"
            else
                TMP_DIR="/storage/emulated/0/tmp"
                mkdir -p "$TMP_DIR" 2>/dev/null
            fi
            save_config
            cecho "配置已重置为默认值"
        fi
        return
    fi

    # 显示配置文件内容
    if [ -f "$COLOR_CONFIG_FILE" ]; then
        cecho -b "当前配置($COLOR_CONFIG_FILE): "
        cat "$COLOR_CONFIG_FILE" | while IFS= read -r line; do
            cecho "$line"
        done
    else
        cecho "配置文件不存在, 使用默认配置"
    fi
}
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
                # 样式切换（b/i/u/s）或重置（r）
                case "$next" in
                    b) ((bold = !bold)) ;;
                    i) ((italic = !italic)) ;;
                    u) ((underline = !underline)) ;;
                    s) ((strikethrough = !strikethrough)) ;;
                    r)  # 重置为默认（无颜色、无样式）
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

    # 末尾重置样式（避免影响后续输出）
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
            elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | grep -q sha256sum; then
                hash=$(busybox sha256sum "$check_file" | awk '{print $1}')
            fi
            if [[ -n "$hash" && "$hash" == "332601600768b5fa71769e7def4c2cc21be1b1a87ab96a3139fed39d201eddcb" ]]; then
                _IAMDC10XRAY_=1
            fi
        fi
    fi
fi
PRIV_LEVEL_0="$PRIV_LEVEL"
# ---------- 标题 ----------
CUSTOM_TITLE=""
get_title() {
    if [ -f "$COLOR_CONFIG_FILE" ]; then
        local title_line=$($_GREP -E '^TITLE=' "$COLOR_CONFIG_FILE" | $_HEAD -1)
        if [ -n "$title_line" ]; then
            CUSTOM_TITLE="${title_line#*=}"
            CUSTOM_TITLE="$(echo "$CUSTOM_TITLE" | xargs)"
        else
            CUSTOM_TITLE=""
        fi
    fi

    if [ -n "$CUSTOM_TITLE" ]; then
        cecho "$CUSTOM_TITLE"
    else
        local osver=$(getprop ro.build.version.release 2>/dev/null || echo '?')
        local kernel=$($_UNAME -r 2>/dev/null || echo '?')
        local title_prefix="Android CMD [版本 $CMD_VER]"
        cecho -b "$title_prefix"
    fi

    if [ "$_IAMDC10XRAY_" = "1" ]; then
        cecho -c 36 "◇Welcome DC10Xray(~v~)◇"
    else
        cecho "Copyright (c) 2026 DC10Xray"
    fi

if [ ${#SPLASHES[@]} -gt 0 ]; then
    local random_index=$(( RANDOM % ${#SPLASHES[@]} ))
    local splash="${SPLASHES[$random_index]}"
    render_splash "$splash"
fi

    if [ "$_IAMDC10XRAY_" != "1" ]; then
        cecho -c "#C0C0C0" "使用 HELP 或 /? 来查看命令列表(Ctrl+C退出)"
        cecho -c 36 "若参数包含空格, 用双引号或者单引号包裹即可"
        else
        cecho -c "#C0C0C0" "我是帮助x2(you know)"
    fi
}
#------------------------------
# ---------- 辅助函数 ----------
#------------------------------
# 二次确认
confirm() {
    while true; do
        printf "\033[1;33m%b[Y/N]: \033[0m" "$*"
        read -r answer
        case "$answer" in
            [Yy]) return 0 ;;
            [Nn]) return 1 ;;
            *) err "请回答Y或N" ;;
        esac
    done
}

# 递归杀死进程树
_kill_process_tree() {
    local pid=$1
    local sig=$2
    [ -z "$sig" ] && sig="TERM"
    [ "$pid" -eq $$ ] && return

    if [ -d "/proc" ]; then
        local children=$(grep -l "^PPid:[[:space:]]*$pid$" /proc/*/status 2>/dev/null | cut -d/ -f3)
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
}

# 暴力版本
_kill_process_tree_force() {
    local pid=$1
    [ "$pid" -eq $$ ] && return
    if [ -d "/proc" ]; then
        local children=$(grep -l "^PPid:[[:space:]]*$pid$" /proc/*/status 2>/dev/null | cut -d/ -f3)
        for child in $children; do
            _kill_process_tree_force "$child"
        done
    fi
    kill -KILL "$pid" 2>/dev/null
}

# 文件操作函数
# 用法: file_op <copy|move> <源1> [源2 ...] <目标>
file_op() {
    local op="$1"
    shift
    if [ $# -lt 2 ]; then
        err "缺少参数"
        return 1
    fi

    local dest="${!#}"
    local sources=("${@:1:$#-1}")

    local dest_is_dir=0
    if [ -d "$dest" ]; then
        dest_is_dir=1
    fi

    if [ ${#sources[@]} -gt 1 ] && [ $dest_is_dir -eq 0 ] && [ -e "$dest" ]; then
        err "多个源文件时目标必须是目录"
        return 1
    fi

    for src in "${sources[@]}"; do
        if [ ! -e "$src" ]; then
            err "源文件/目录不存在: $src"
            return 1
        fi

        local target="$dest"
        if [ $dest_is_dir -eq 1 ]; then
            local src_basename=$(basename "$src")
            target="$dest/$src_basename"
        fi

        if [ -e "$target" ]; then
            confirm "覆盖 $target 吗?" || { cecho "跳过 $src"; continue; }
        fi

        if [ "$op" = "copy" ]; then
            if [ -d "$src" ]; then
                $_CP -r "$src" "$target" 2>/dev/null || { err "复制目录 $src 失败"; return 1; }
            else
                $_CP "$src" "$target" 2>/dev/null || { err "复制文件 $src 失败"; return 1; }
            fi
        else  # move
            $_MV "$src" "$target" 2>/dev/null || { err "移动 $src 失败"; return 1; }
        fi
    done
    return 0
}

# ---------- EXIT ----------
GLOBAL_CMD_RUNNING=0
GLOBAL_CHILD_PID=0
GLOBAL_SIGNAL_RECEIVED=0
GLOBAL_EXIT9_ACTIVE=0
GLOBAL_WORKER_PIDS=()
GLOBAL_PROGRESS_PID=0

cmd_exit9() {
    if [ $GLOBAL_EXIT9_ACTIVE -eq 1 ]; then return; fi
    GLOBAL_EXIT9_ACTIVE=1
    echo ""
    err "------------CMD Stopping-----------" >&2
    if [ -n "$GLOBAL_CHILD_PID" ] && kill -0 "$GLOBAL_CHILD_PID" 2>/dev/null; then
        _kill_process_tree_force "$GLOBAL_CHILD_PID"
        GLOBAL_CHILD_PID=0
    fi
    if [ ${#GLOBAL_WORKER_PIDS[@]} -gt 0 ]; then
        for pid in "${GLOBAL_WORKER_PIDS[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                _kill_process_tree_force "$pid"
            fi
        done
        GLOBAL_WORKER_PIDS=()
    fi
    if [ $GLOBAL_PROGRESS_PID -ne 0 ] && kill -0 "$GLOBAL_PROGRESS_PID" 2>/dev/null; then
        _kill_process_tree_force "$GLOBAL_PROGRESS_PID"
        wait "$GLOBAL_PROGRESS_PID" 2>/dev/null || true
        GLOBAL_PROGRESS_PID=0
    fi
    GLOBAL_SIGNAL_RECEIVED=1
    GLOBAL_EXIT9_ACTIVE=0
    cleanup_temp_files
    exit 130
}

handle_signal() {
    if [ "$GLOBAL_CMD_RUNNING" -eq 1 ]; then
        cmd_exit9
    else
        cmd_exit15
    fi
}

trap handle_signal INT TERM QUIT HUP
cmd_exit15_0() {
    echo "bro 不是这个ctrl+c!!! 但是我还是会帮你"
    sleep 0.2
    cmd_exit15
}

cmd_exit15() {
    echo ""
    err "-------------CMD Exit------------" >&2
    exit 0
}

# 物理强制退出
cmd_killself() {
    if confirm "强制终止当前脚本进程? (PID: $$)"; then
        err "------------CMD KILLED-----------"
        kill -9 $$ 2>/dev/null
    else
        echo ""
    fi
}
# ---临时文件清理 ---
cleanup_temp_files() {
    if [ -d "$TMP_DIR" ]; then
        rm -f "$TMP_DIR/ping_tmp_$$_"* 2>/dev/null
        rm -rf "$TMP_DIR/scan_$$" 2>/dev/null
        rm -rf "$TMP_DIR/portscan_$$" 2>/dev/null
        rm -f "$TMP_DIR/tree_$$_"* 2>/dev/null
    fi
}
#--------------------------------------
#---------- 命令实现函数(序章) ----------
#--------------------------------------
# 颜色设置
cmd_color() {
        if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -eq 0 ]; then
        {
            cecho -b "设置控制台默认前景和背景色"
            cecho "COLOR -def            恢复默认颜色(黑底亮白)"
            cecho "COLOR [背景][前景]    设置颜色,如 COLOR 0A"
            echo ""
            cecho -b "颜色代码: "
            cecho "   0 = 黑色       8 = 灰色"
            cecho "   1 = 蓝色       9 = 淡蓝"
            cecho "   2 = 绿色       A = 淡绿"
            cecho "   3 = 青色       B = 淡青"
            cecho "   4 = 红色       C = 淡红"
            cecho "   5 = 紫色       D = 淡紫"
            cecho "   6 = 黄色       E = 淡黄"
            cecho "   7 = 白色       F = 亮白"
            echo ""
            cecho "示例: COLOR 0A    黑色背景亮绿前景"
        }
        return 0
    fi
    if [ "$1" = "-def" ]; then
        BG=40; FG=97; save_config; cecho "颜色已重置为默认值"; return 0
    fi
    if [ $# -gt 1 ]; then
        err "参数数量错误用法: COLOR [背景][前景] 或 COLOR -def 恢复默认"
        return 1
    fi
    local arg=$(echo "$1" | tr -d ' ' | tr '[:lower:]' '[:upper:]')
    if [ ${#arg} -ne 2 ]; then
        err "无效颜色参数, 使用 COLOR -h 查看帮助"
        return 1
    fi
    local bg_char=$(echo "$arg" | cut -c1)
    local fg_char=$(echo "$arg" | cut -c2)
    case $bg_char in
        0) BG=40;;   1) BG=44;;   2) BG=42;;   3) BG=46;;
        4) BG=41;;   5) BG=45;;   6) BG=43;;   7) BG=47;;
        8) BG=100;;  9) BG=104;;  A) BG=102;;  B) BG=106;;
        C) BG=101;;  D) BG=105;;  E) BG=103;;  F) BG=107;;
        *) err "无效背景颜色代码 '$bg_char', 使用 COLOR -h 查看帮助"; return 1;;
    esac
    case $fg_char in
        0) FG=30;;   1) FG=34;;   2) FG=32;;   3) FG=36;;
        4) FG=31;;   5) FG=35;;   6) FG=33;;   7) FG=37;;
        8) FG=90;;   9) FG=94;;   A) FG=92;;   B) FG=96;;
        C) FG=91;;   D) FG=95;;   E) FG=93;;   F) FG=97;;
        *) err "无效前景颜色代码 '$fg_char', 使用 COLOR -h 查看帮助"; return 1;;
    esac
    cecho "颜色已设置为背景[$bg_char]前景[$fg_char]"
    save_config
}
# 临时目录
cmd_tmpdir() {
    if [ $# -eq 0 ] || [ "$1" != "set" ]; then
        cecho "当前临时目录: $TMP_DIR"
        return 0
    fi

    if [ $# -lt 2 ] || [ -z "$2" ]; then
        err "用法: TMPDIR set <目录>"
        return 1
    fi
    local newdir="$2"
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
}

# 资源加载
cmd_resource() {
        if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -eq 0 ]; then
        cecho -b "用法: RESOURCE [子命令]"
        cecho "  RESOURCE           显示本帮助"
        cecho "  RESOURCE load      列出可用的外部资源文件"
        cecho "  RESOURCE reload    重载资源列表(重新扫描)"
        echo ""
        cecho "资源文件位于 resource/ 目录及其子目录下, "
        cecho "以 cmd_*.bash 命名, 主程序启动时自动扫描"
        cecho "如果某个命令的资源文件缺失, 则该命令将不可用"
        return 0
    fi
    case "$1" in
        load)
            local show_all=0
            [ "$2" = "-debug" ] && show_all=1
            shopt -s globstar nullglob dotglob
            local files=()
            for f in "$RESOURCE_DIR"/**/cmd_*.bash; do
                [ -f "$f" ] && files+=("$f")
            done
            shopt -u globstar nullglob dotglob
            if [ ${#files[@]} -eq 0 ]; then
                cecho "没有找到任何资源文件"
                return
            fi
            local sorted
            sorted=$(printf '%s\n' "${files[@]}" | sort)
            local filtered=()
            while IFS= read -r file; do
                local rel="${file#$SCRIPT_DIR/}"
                if [ $show_all -eq 1 ] || [[ ! "${rel,,}" =~ laugh|debug ]]; then
                    filtered+=("$rel")
                fi
            done <<< "$sorted"
            if [ ${#filtered[@]} -eq 0 ]; then
                cecho "没有可显示的资源文件(可能被过滤, 使用 debug 参数查看全部)"
                return
            fi
            cecho -b "可用的外部资源文件:"
            local idx=1
            for rel_path in "${filtered[@]}"; do
                cecho "  $idx. $rel_path"
                ((idx++))
            done
            ;;
        reload)
            cmd_resource load "$2"
            ;;
        *)
            err "未知子命令, 使用 RESOURCE -h 查看帮助"
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
            cecho -b "用法: HISTORY [选项]"
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
        echo "用法: TITLE [-def]/[字符串]"
        echo "  TITLE             显示本帮助"
        echo "  TITLE -def        恢复控制台标题为默认值"
        echo "  TITLE <字符串>    设置自定义标题"
        echo "示例: TITLE cmd.exe [版本 16.0]"
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
cmd_help() {
ccat << EOF
$CMD_delimiter
//cecho -b "文件和目录操作"
//cecho -c 93 "若参数包含空格, 用双引号或者单引号包裹即可"
  COPY/CP [源...] [目标]    复制文件/目录 ⤸
  -(支持多个源,目标为目录时复制到目录下)
  RM/DEL [文件]             删除文件或目录
  RD/RMDIR [目录]           删除空目录
  FIND <关键词/正则表达式> <文件1> [文件2...] ⤸
  -在指定文件中搜索字符串/正则表达式
  MD/MKDIR [目录]           创建目录
  NEW/TOUCH <文件>          创建新文件或者更新文件时间
  MOVE [源...] [目标]       移动文件/目录,或重命名(同目录下)
  REN  [旧名] [新名]        重命名文件(=MOVE)
  DIR [路径]                列出目录内容
  DU [目录]                 列出目录大小
  SIZE [文件]               列出文件大小
  STAT <文件>               显示文件的详细信息
  LN -s <源> <目标>         创建软链接(符号链接)
  TREE [选项] [路径]        显示目录树
  TYPE [文件]               查看文本文件
  MORE < 文件               分页查看文本文件(不支持颜色)
  ZIP <输出文件> <源文件/目录> [-f 格式] [-l 级别] ⤸
  -创建 ZIP 压缩包(支持目录递归)
  UNZIP <压缩包> [-d 目标]    解压 ZIP 压缩包

//cecho -b "系统信息"
  NOW             显示当前时钟
  CAL [模式/年份] [月份] 显示日历
  CLOCK           显示实时时间(每0.1s刷新)
  FREE            显示当前内存使用
  DF              显示磁盘使用情况
  GETPROP [KEY]   系统属性(空KEY分页显示全部)
  ENV/EXPORT      环境变量(空参数帮助)
  LOGCAT          系统日志相关功能
  UPTIME          系统运行时间
  RES/WM          显示屏幕相关信息(WM详细,RES兼容)
  BATT            显示电池信息
  SYSTEMINFO      一些系统信息
  TL/TASKLIST     进程列表
  TM/TOP/TASKMGR  任务管理器
  TEMP            显示温度传感器、温度墙和温控状态
  MONITOR         监控时间、内存和温度(约每2s刷新)
  WHOAMI/OP       显示当前用户UID和权限
  WHICH           查找命令路径
  DISKC [参数]    检测各可读(写)挂载点的读写速度
  DISKT [参数]    检测当前存储设备的顺序和随机读写速度
  PWD             显示当前工作目录
  SELF            显示当前脚本路径

//cecho -b "网络"
  NETSTAT           网络连接统计
  HOSTNAME          显示主机名
  DNS [IPV4/域名]   相互转换IPV4或域名
  NETNEIG           扫描局域网下的主机
  FTP [参数]        FTP功能
  PING [参数]       测试网络连接
  SCAN [参数]       扫描网络中的存活主机
  PORTSCAN [参数]   扫描指定地址的存活端口
  DOWNLOAD <URL> <本地路径> 下载网络文件到本地
  ST/SPEEDTEST [-u URL] [-t 超时] ⤸
  -网络测速(默认 Cloudflare 10MB,注意流量消耗)

//cecho -b "编解码与校验"
  BASE64/B64 -d <字符串>/[-d] -f <文件>  Base64编码/解码
  SHA256 -d <字符串>/-f <文件>           计算文件的SHA256
  SHA1 -d <字符串>/-f <文件>             计算文件的SHA1
  MD5 <文件>                计算文件的MD5
  CRC32 <文件>              计算文件的CRC32(cksum)
  PSD [-n 长度] [-C 数量] [-a/-u/-l/-d/-s/-c 字符集] ⤸
  -生成符合要求的随机密码
  RAND [长度]               生成随机数(默认四位数)

//cecho -b "杂项"
  ECHO/PRINT [消息]       显示消息
  PRINTF/ECHO -e          解析代码的显示消息
  CECHO [参数] [消息]     ME自定义的显示消息
  ERR [消息]              显示错误样式消息(红色)
  YES [内容]              刷屏某一内容直至按下Ctrl+C
  HACK <目标>             穷举可打印字符直到找到目标
  HACK2 <目标>            同上,但是使用二分法
  AWKC <表达式>/<无参数进入交互>           AWK计算器
  BC [-s 精度] <表达式>/<无参数进入交互>   任意精度计算器
  TIMER [秒数]/[时间戳]   倒计时/闹钟
  SLEEP <秒数>            睡眠指定时间
  WATCH <秒数> <命令> [参数]    每隔指定时间清除屏幕并运行命令
  REPEAT <次数> <命令> [参数]   重复执行指定次数命令
//cecho -b "控制台"
  CLS/CLEAR              清除屏幕(-n无标题/-r/-y有)
  CLSD/CLEARD            设置清除屏幕默认行为
  COLOR [-def]/[BF]      设置控制台颜色
  TITLE [-def]/[文本]    设置控制台标题
  TMPDIR set [目录]/~           设置/查看临时目录
  RESOURCE load/reload          查看加载资源/重载资源
  HISTORY [参数]                历史命令
  CONFIG <-r 默认/无参数显示>   显示配置或恢复默认配置
  UPDATE                        检查更新
  INFO                          显示脚本自身信息
  HELP <OR> /?                  此命令列表
  EXIT/EXIT15                   正常退出
  EXIT9                         强制退出
  EXITK/KILLSELF                杀掉自己以退出
//cecho -c "#C0C0C0" "  #按下Ctrl+C退出命令, 未说明时退出脚本"
  ULIMIT [选项] [限制值]        限制SHELL
  SH <脚本路径> [参数]          执行外部 SHELL 脚本
  C/CMD <系统命令> [参数]       执行任意系统命令
  ADB <参数>                    执行 ADB 命令
  RUNNING <包名>                启动应用程序
  KILL [-9/-15/-2] <PID>        终止指定进程
$CMD_delimiter
EOF
}

# ------CMDINFO------
cmd_cmdinfo() {
cecho -b "--- 关于 Android CMD ---"
    ccat << EOF
版本: $CMD_VER
作者: DC10Xray
许可证: MIT   Copyright (c) 2026 DC10Xray
QQ: 3896444757
电子邮件: 3896444757@qq.com
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
        cecho -c 36 "[YES YES YES/YYY]"
        return 130
    fi
}

cmd_echo() {
    # 显示帮助
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cecho -b "用法: ECHO [-e] [-n] [消息]"
        cecho -b "支持选项:"
        cecho "  -e       启用转义字符解析(如 \\n, \\t)"
        cecho "  -n       不换行输出"
        cecho "  -en/-ne  同时启用 -e 和 -n"
        return 0
    fi

    local opts=()
    local args=()
    # 解析选项(仅支持 -e、-n、-en、-ne)
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

# ---------- CECHO 命令 ----------
cmd_cecho() {
    # 显示帮助
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then

cecho -b "用法: CECHO [选项] [消息]"
cecho -b "选项:"
ccat << "EOF"
-n              不换行
-c <颜色>       设置前景色 (数字颜色码或十六进制码)
-cb <颜色>      设置背景色 (数字颜色码或十六进制码)
-b              粗体
-i              斜体
-u              下划线
-s              删除线
-r              纯文本模式 (忽略所有样式和颜色)
-h, --help      显示本帮助
EOF
        return 0
    fi

    # 初始化变量
    local opt_n=false
    local custom_fg=""
    local custom_bg=""
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
                    err "选项 -c 需要指定颜色值"
                    return 1
                fi
                custom_fg="$2"; shift 2 ;;
            -cb)
                if [ $# -lt 2 ]; then
                    err "选项 -cb 需要指定颜色值"
                    return 1
                fi
                custom_bg="$2"; shift 2 ;;
            -b) bold=1; shift ;;
            -i) italic=1; shift ;;
            -u) underline=1; shift ;;
            -s) strikethrough=1; shift ;;
            -r) plain=1; shift ;;
            --) shift; break ;;
            -*)
                err "未知选项: $1"
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
    [ -n "$custom_fg" ] && call_args+=("-c" "$custom_fg")
    [ -n "$custom_bg" ] && call_args+=("-cb" "$custom_bg")
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
# ---------- LN 创建软链接 ----------
cmd_ln() {
        if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -eq 0 ]; then
        cecho -b "用法: LN -s <源> <目标>"
        cecho "示例: LN -s /path/to/original /path/to/link"
        return 0
    fi
    if [ $# -ne 3 ] || [ "$1" != "-s" ]; then
        err "参数错误"
        return 1
    fi
    local src="$2"
    local target="$3"
    if [ ! -e "$src" ]; then
        err "源文件/目录不存在: $src"
        return 1
    fi
    if [ -e "$target" ] || [ -L "$target" ]; then
        confirm "目标 '$target' 已存在, 是否覆盖?" || { cecho "已取消"; return 0; }
        rm -f "$target" 2>/dev/null || { err "无法删除已存在的目标: $target"; return 1; }
    fi
    ln -s "$src" "$target" 2>/dev/null
    local ret=$?
    if [ $ret -eq 0 ]; then
        cecho "软链接已创建: $target -> $src"
    else
        err "创建软链接失败(错误码 $ret)"
        return $ret
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

cmd_del() {
    [ $# -eq 0 ] && { err "命令语法不正确"; return; }
    for f in "$@"; do
        if [ -e "$f" ]; then
            confirm "删除 $f 吗?" || { cecho "操作已取消"; continue; }
            if [ -d "$f" ]; then
                $_RM -r "$f" 2>/dev/null && cecho "已删除目录: $f" || err "删除目录 $f 失败"
            else
                $_RM "$f" 2>/dev/null && cecho "已删除文件: $f" || err "删除文件 $f 失败"
            fi
        else
            err "系统找不到指定的路径: $f"
        fi
    done
}

cmd_md() {
    [ $# -eq 0 ] && { err "命令语法不正确"; return; }
    for dir in "$@"; do
        $_MKDIR -p "$dir" 2>/dev/null || err "目录创建失败: $dir"
    done
}

cmd_touch() {
        if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -eq 0 ]; then
        cecho -b "用法: TOUCH/NEW 文件名"
        return 0
    fi
    if [ $# -ne 1 ]; then
        err "参数错误"
        return 1
    fi
    local file="$1"
    local dir=$(dirname "$file")
    if [ -n "$dir" ] && [ ! -d "$dir" ]; then
        mkdir -p "$dir" 2>/dev/null || { err "无法创建目录 '$dir'"; return 1; }
    fi
    if [ -e "$file" ]; then
        touch "$file" 2>/dev/null && cecho "已更新: $file" || err "无法更新: $file"
    else
        touch "$file" 2>/dev/null && cecho "已创建: $file" || err "创建失败: $file"
    fi
}

cmd_rd() {
    [ $# -eq 0 ] && { err "命令语法不正确"; return; }
    for dir in "$@"; do
        if [ -d "$dir" ]; then
            confirm "删除目录 $dir 吗?" || { cecho "操作已取消"; continue; }
            $_RMDIR "$dir" 2>/dev/null || err "目录删除失败(可能非空): $dir"
        else
            err "系统找不到指定的路径: $dir"
        fi
    done
}

cmd_copy() {
    if [ $# -lt 2 ]; then
        err "命令语法不正确用法: COPY 源... 目标"
        cecho "示例: COPY file1.txt file2.txt ../dir/   # 复制多个文件到目录"
        cecho "      COPY old.txt new.txt               # 复制并重命名(目标不是目录)"
        return 1
    fi

    local dest="${!#}"
    local dest_dir=$(dirname "$dest")
    if [ -n "$dest_dir" ] && [ ! -d "$dest_dir" ]; then
        mkdir -p "$dest_dir" 2>/dev/null || {
            err "无法创建目标目录 '$dest_dir',请检查权限"
            return 1
        }
    fi

    file_op "copy" "$@"
}

cmd_move() {
    if [ $# -lt 2 ]; then
        err "用法: MOVE [源...] [目标]   (重命名时源和目标应在同一目录)"
        cecho "示例: MOVE file1.txt ../dir/       # 移动"
        cecho "      MOVE old.txt new.txt         # 重命名"
        return 1
    fi

    local dest="${!#}"
    local dest_dir=$(dirname "$dest")
    if [ -n "$dest_dir" ] && [ ! -d "$dest_dir" ]; then
        mkdir -p "$dest_dir" 2>/dev/null || {
            err "无法创建目标目录 '$dest_dir',请检查权限"
            return 1
        }
    fi

    file_op "move" "$@"
}

cmd_free() {
    $_FREE -h 2>&1 | while IFS= read -r line; do cecho "$line"; done
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
    
    # ---------- 2. 温度读取函数 ----------
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
    
    # ---------- 3. 先输出三行占位 ----------
    printf "\n\n\n"
    
    # ---------- 4. 主显示循环 ----------
    while [ $stop_monitor -eq 0 ]; do
        # 4.1 获取当前时间
        local current_time=$($_DATE "+%Y-%m-%d %a %H:%M:%S")
        
        # 4.2 获取内存信息
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
        
        # 4.3 读取温度
        local cpu_temp=$(_read_temp "$cpu_sensor_path" "N/A")
        local gpu_temp=$(_read_temp "$gpu_sensor_path" "N/A")
        local bat_temp=$(_read_temp "$battery_sensor_path" "N/A")
        
        # ---------- 5. 原地刷新三行 ----------
        printf "\033[3A"
        
        printf "\r\033[K"
        _cprint -c 92 "实时时钟: $current_time"
        
        printf "\r\033[K"
        _cprint -c 93 "内存使用率: $percent%   已用: ${mem_used_mb}M / 总共: ${mem_total_mb}M"
        
        printf "\r\033[K"
        _cprint -c 96 -n "CPU: ${cpu_temp:-N/A}  "
        _cprint -c 95 -n "GPU: ${gpu_temp:-N/A}  "
        _cprint -c 92 "Battery: ${bat_temp:-N/A}"
        
        # 6. 精确等待到下一秒
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
    err "此汉化帮助可能和您的系统选项不同, 仅供参考, 更多信息请使用ULIMIT -a"
        ccat << "EOF"
//cecho -b "用法: ULIMIT [选项] [限制值]"
显示或设置当前 Shell 进程的资源限制

//cecho -b "选项:"
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
        err "无效选项或参数"
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

cmd_env() {
        if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -eq 0 ]; then
        cecho -b "用法:"
        cecho "  ENV list/show       显示所有环境变量(分页)"
        cecho "  ENV set KEY=VALUE     设置环境变量(也支持 KEY VALUE 空格格式)"
        cecho "  ENV unset KEY         删除环境变量"
        return 0
    fi
    local subcmd="$1"
    shift
    case "$subcmd" in
        list|show)
            if command -v env >/dev/null 2>&1; then
                if command -v more >/dev/null 2>&1; then
                    env | more
                else
                    env | while IFS= read -r line; do cecho "$line"; done
                fi
            elif command -v export >/dev/null 2>&1; then
                if command -v more >/dev/null 2>&1; then
                    export -p | more
                else
                    export -p | while IFS= read -r line; do cecho "$line"; done
                fi
            else
                err "无法显示环境变量"
                return 1
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
        *)
            err "未知子命令: $subcmd"
            cecho "使用 ENV -h 查看帮助"
            return 1
            ;;
    esac
}

cmd_watch() {
        if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -eq 0 ]; then
        cecho -b "用法: WATCH <秒数> <命令> [参数]"
        cecho "示例: WATCH 2 cmd_systeminfo"
        cecho "      WATCH 5 ls -l /sdcard"
        cecho "提示: 通过<内部命令名称>运行此脚本内置命令"
        cecho "按Ctrl+C随时退出"
        return 0
    fi

    if [ $# -lt 2 ]; then
        err "用法: WATCH <秒数> <命令> [参数]"
        cecho "示例: WATCH 2 systeminfo"
        cecho "      WATCH 5 ls -l /sdcard"
        cecho "提示: 通过<内部命令名称>运行此脚本内置命令"
        cecho "按Ctrl+C随时退出"
        return 1
    fi

    local interval="$1"
    shift
    local cmd_line="$*"

    # 检查间隔是否为有效的正数(整数或小数)
    if ! [[ "$interval" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        err "错误:秒数必须是正数"
        return 1
    fi
    # 使用 bc 检查是否>0
    if [ "$(echo "$interval <= 0" | bc)" -eq 1 ]; then
        err "错误:秒数必须大于0"
        return 1
    fi

    if ! confirm "每 ${interval} 秒清屏并执行: \"$cmd_line\"?(按Ctrl+C随时退出)"; then
        cecho "已取消"
        return 0
    fi

    # 保存旧的 INT 陷阱,设置自己的处理
    local old_trap=$(trap -p INT)
    local stop_watch=0
    trap 'stop_watch=1' INT

    while [ $stop_watch -eq 0 ]; do
        cmd_cls -n
        eval "$cmd_line"
        if [ $stop_watch -eq 0 ]; then
            sleep "$interval"   # sleep 已支持小数
        fi
    done

    # 恢复旧的陷阱
    if [ -n "$old_trap" ]; then
        eval "$old_trap"
    else
        trap - INT
    fi

    echo ""
    sleep 0.1

    # 退出时询问是否保留当前输出
    if ! confirm "是否保留输出?"; then
        cmd_cls
    fi

    return 0
}

cmd_repeat() {
        if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -eq 0 ]; then
        cecho -b "用法: REPEAT <次数> <命令> [参数]"
        cecho "示例: REPEAT 100 echo Hello World"
        cecho "      REPEAT 3 ls -l"
        cecho "按 Ctrl+C 可提前终止"
        return 0
    fi

    if [ $# -lt 2 ]; then
        err "用法: REPEAT <次数> <命令> [参数]"
        cecho "示例: REPEAT 100 echo Hello World"
        cecho "      REPEAT 3 ls -l"
        cecho "按 Ctrl+C 可提前终止"
        return 1
    fi

    local count="$1"
    shift
    local cmd_line="$*"

    # 验证次数为正整数
    if ! [[ "$count" =~ ^[0-9]+$ ]] || [ "$count" -eq 0 ]; then
        err "次数必须是正整数"
        return 1
    fi

    if ! confirm "执行 \"$cmd_line\" *$count?(按Ctrl+C随时退出)"; then
        cecho "已取消"
        return 0
    fi

    # 保存旧的 INT 陷阱,设置自己的处理
    local old_trap=$(trap -p INT)
    local stop_repeat=0
    trap 'stop_repeat=1' INT

    local i
    for ((i=1; i<=count; i++)); do
        if [ $stop_repeat -eq 1 ]; then
            break
        fi
        eval "$cmd_line"
    done

    # 恢复旧的 INT 陷阱
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

    local top_output=$(top -n 1 -b 2>/dev/null)
    local pid_line=$(echo "$top_output" | grep -n '^[ ]*PID' | head -1 | cut -d: -f1)
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
        ececho -b "用法: RUNNING <包名>"
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

cmd_systeminfo() {
    # ===== 基础信息 =====
    local hostname=$($_HOSTNAME 2>/dev/null || $_CAT /proc/sys/kernel/hostname 2>/dev/null || echo 'unknown')
    local osver=$(getprop ro.build.version.release 2>/dev/null || echo '?')
    local sdkver=$(getprop ro.build.version.sdk 2>/dev/null || echo '?')
    local manuf=$(getprop ro.product.manufacturer 2>/dev/null || echo '?')
    local model=$(getprop ro.product.model 2>/dev/null || echo '?')
    local cpu=$($_CAT /proc/cpuinfo 2>/dev/null | $_GREP -E 'Processor|Hardware' | $_HEAD -1 | $_CUT -d: -f2- | $_SED 's/^[ \t]*//')
    [ -z "$cpu" ] && cpu="unknown"
    local kernel=$($_UNAME -r 2>/dev/null || echo 'unknown')

    # ===== CPU核心数 =====
    local cpu_cores=$($_GREP -c '^processor' /proc/cpuinfo 2>/dev/null)
    [ -z "$cpu_cores" ] && cpu_cores="未知"

    # ===== 内存信息 =====
    local mem_total_kb=$($_CAT /proc/meminfo 2>/dev/null | $_GREP 'MemTotal' | $_AWK '{print $2}')
    local mem_avail_kb=$($_CAT /proc/meminfo 2>/dev/null | $_GREP 'MemAvailable' | $_AWK '{print $2}')
    local mem_used_kb=""
    local mem_percent=""
    local mem_total_display="未知"
    local mem_avail_display="未知"
    local mem_used_display="未知"

    if [ -n "$mem_total_kb" ] && [ -n "$mem_avail_kb" ]; then
        mem_used_kb=$((mem_total_kb - mem_avail_kb))
        mem_percent=$(( (mem_used_kb * 100) / mem_total_kb ))
        mem_total_display="${mem_total_kb} kB"
        mem_avail_display="${mem_avail_kb} kB"
        mem_used_display="${mem_used_kb} kB"
    else
        mem_percent="?"
    fi

    # ===== 运行时间 & 负载 =====
    local uptime_raw=$(uptime 2>/dev/null)
    [ -z "$uptime_raw" ] && uptime_raw="无法获取"

    # ===== 温度传感器 =====
    local thermal_base="/sys/class/thermal"
    local cpu_sensor=""
    local gpu_sensor=""
    local battery_sensor=""
    if [ -d "$thermal_base" ]; then
        for zone in "$thermal_base"/thermal_zone*; do
            [ -d "$zone" ] || continue
            local type_file="$zone/type"
            local temp_file="$zone/temp"
            [ -r "$type_file" ] && [ -r "$temp_file" ] || continue
            local sensor_type=$($_CAT "$type_file" 2>/dev/null | tr -d '\n\r')
            case "$sensor_type" in
                cpu-0-0|cpuss-0|cpu-0-1|cpuss-1|cpu-1-0) [ -z "$cpu_sensor" ] && cpu_sensor="$temp_file" ;;
                gpuss-0|gpuss-1|gpu) [ -z "$gpu_sensor" ] && gpu_sensor="$temp_file" ;;
                battery) battery_sensor="$temp_file" ;;
            esac
        done
    fi
    [ -z "$battery_sensor" ] && [ -r "/sys/class/power_supply/battery/temp" ] && battery_sensor="/sys/class/power_supply/battery/temp"

    _get_temp() {
        local path="$1"
        [ -n "$path" ] && [ -r "$path" ] || { echo "N/A"; return; }
        local raw=$($_CAT "$path" 2>/dev/null | tr -d '\n\r')
        [ -z "$raw" ] && { echo "N/A"; return; }
        if [ "$raw" -gt 1000 ] 2>/dev/null; then
            raw=$((raw / 1000))
        fi
        if [ "$raw" -gt 5 ] && [ "$raw" -lt 120 ] 2>/dev/null; then
            echo "${raw}°C"
        else
            echo "N/A"
        fi
    }

    local cpu_temp=$(_get_temp "$cpu_sensor")
    local gpu_temp=$(_get_temp "$gpu_sensor")
    local bat_temp=$(_get_temp "$battery_sensor")

    # ===== 最终输出 =====
    {
        cecho -b "系统信息"
        cecho "$CMD_delimiter"
        cecho "主机名: $hostname"
        cecho "系统版本: Linux(Android $osver, SDK $sdkver) (内核 $kernel)"
        cecho "制造商: $manuf"
        cecho "型号: $model"
        cecho "处理器: $cpu"
        cecho "CPU核心数: $cpu_cores"
        cecho "$CMD_delimiter"
        cecho "内存使用率: ${mem_percent}%"
        cecho "总内存: $mem_total_display"
        cecho "可用内存: $mem_avail_display"
        cecho "已用内存: $mem_used_display"
        cecho "$CMD_delimiter"
        cecho "CPU温度: $cpu_temp    GPU温度: $gpu_temp    电池温度: $bat_temp"
        cecho "$CMD_delimiter"
        cecho "运行时间及负载: $uptime_raw"
        cecho "$CMD_delimiter"
    }
}

cmd_find() {
        if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -eq 0 ]; then
        cecho -b "用法: FIND <关键词/正则表达式> <文件1> [文件2...]"
        return 0
    fi
    if [ $# -lt 2 ]; then
        err "参数不足, 使用 FIND -h 查看帮助"
        return 1
    fi
    local pattern="$1"; shift
    $_GREP "$pattern" "$@" 2>&1 | while IFS= read -r line; do cecho "$line"; done
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
    local path="."

    # 解析选项
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d) show_dirs_only=1; shift ;;
            -L)
                if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                    max_depth="$2"; shift 2
                else
                    shift
                fi
                ;;
            -s) show_size=1; shift ;;
            -h|--help)
                cecho "用法: TREE [选项] [路径]"
                cecho "选项:"
                cecho "  -d          只显示目录"
                cecho "  -L <深度>   限制递归深度"
                cecho "  -s          显示文件大小"
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
        trap 'rm -f "$tmpfile" 2>/dev/null' RETURN

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

            if [ -d "$full" ]; then
                if [ $show_dirs_only -eq 0 ] || [ $show_dirs_only -eq 1 ]; then
                    _cprint -c 34 "${prefix}${connector}${entry}"
                fi
                _tree_recursive "$full" "$child_prefix" $((depth+1))
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
}

cmd_adb() {
        if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -eq 0 ]; then
        cecho -b "用法: ADB <参数>"
        cecho "示例: ADB devices"
        return 0
    fi
    if ! confirm "确认要执行此ADB命令吗?(请确认命令是否安全!)"; then
        cecho "已取消执行"
        return 0
    fi
    if command -v adb >/dev/null 2>&1; then
        adb "$@" 2>&1 | while IFS= read -r line; do cecho "$line"; done
    else
        err "未找到 adb 命令"
        return 1
    fi
}

cmd_cmd() {
        if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -eq 0 ]; then
        cecho -b "用法: C/CMD <系统命令> [参数]"
        cecho "示例: C/CMD ls -l"
        return 0
    fi
    local force=0
    if [ "$1" = "--force" ]; then
        force=1; shift
    fi
    if [ $# -eq 0 ]; then
        err "用法: C/CMD <系统命令> [参数]"
        return 1
    fi
    local raw_cmd="$*"
    if [ $force -eq 0 ]; then
        local compact=$(printf "%s" "$raw_cmd" | tr -d '[[:space:]]"' | tr -d "'")
        if [[ "$compact" == *":(){"* && "$compact" == *":|:&"* ]]; then
            err "检测到你的命令貌似是个炸弹!"
            cecho "如果你确认这不危险,并想执行, 请使用 --force 参数强制执行"
            cecho "如果误判了你的安全命令, 请向作者反馈"
            echo ""
            return 0
        fi
    else
        err "警告: 已跳过炸弹检测"
    fi
    if ! confirm "确认要执行这个命令吗?(请确认命令是否安全!)"; then
        echo ""
        return 0
    fi
    local old_trap=$(trap -p INT)
    local child_pid=""
    local interrupted=0
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

cmd_sh() {
        if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -eq 0 ]; then
        cecho -b "用法: SH <脚本路径> [参数]"
        return 0
    fi
    local script="$1"
    shift
    if [ ! -f "$script" ]; then
        err "脚本文件不存在: $script"
        return 1
    fi
    if [ ! -r "$script" ]; then
        err "脚本文件不可读: $script"
        return 1
    fi
    if ! confirm "确认要执行此脚本吗?(请确认脚本内不含危险代码!)"; then
        cecho "已取消执行"
        return 0
    fi
    cecho "执行脚本: $script"
    local old_trap=$(trap -p INT)
    local child_pid=""
    local interrupted=0
    trap 'interrupted=1; [ -n "$child_pid" ] && kill -INT "$child_pid" 2>/dev/null' INT
    sh "$script" "$@" &
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

cmd_kill() {
        if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -eq 0 ]; then
        cecho -b "用法: KILL <PID> / KILL -9 <PID> (强制终止) / KILL -2 <PID> (中断)"
        cecho "使用 TASKLIST 查看进程列表"
        return 0
    fi
    local signal="TERM"
    local pid=""
    if [ "$1" = "-9" ] || [ "$1" = "-KILL" ] || [ "$1" = "-SIGKILL" ]; then
        signal="KILL"; shift
    elif [ "$1" = "-15" ] || [ "$1" = "-TERM" ] || [ "$1" = "-SIGTERM" ]; then
        signal="TERM"; shift
    elif [ "$1" = "-2" ] || [ "$1" = "-INT" ] || [ "$1" = "-SIGINT" ]; then
        signal="INT"; shift
    fi
    if [ $# -eq 0 ]; then
        err "需要指定进程ID, 使用 KILL -h 查看帮助"
        return 1
    fi
    pid="$1"
    if ! echo "$pid" | grep -qE '^[0-9]+$'; then
        err "无效的进程ID: $pid"
        return 1
    fi
    if ! ps -p "$pid" >/dev/null 2>&1; then
        err "进程 $pid 不存在或已终止"
        return 1
    fi
    local proc_info=""
    if command -v ps >/dev/null 2>&1; then
        proc_info=$(ps -o pid,user,comm= -p "$pid" 2>/dev/null | tail -1)
    else
        proc_info="PID: $pid"
    fi
    if [ "$signal" = "KILL" ]; then
        cecho "发送 SIGKILL (强制终止) 信号给进程 $pid?"
        cecho "进程信息: $proc_info"
        echo ""
        if ! confirm "强制终止此进程吗?"; then
            cecho "操作已取消"
            return 0
        fi
    else
        cecho "发送 SIG$signal 信号给进程 $pid?"
        cecho "进程信息: $proc_info"
        echo ""
        if ! confirm "终止此进程吗?"; then
            cecho "操作已取消"
            return 0
        fi
    fi
    if kill -$signal "$pid" 2>/dev/null; then
        cecho "已发送 SIG$signal 信号到进程 $pid"
        if [ "$signal" = "TERM" ] || [ "$signal" = "INT" ]; then
            cecho "等待进程退出..."
            local waited=0
            while kill -0 "$pid" 2>/dev/null && [ $waited -lt 5 ]; do
                sleep 0.5
                waited=$((waited + 1))
            done
            if kill -0 "$pid" 2>/dev/null; then
                cecho "进程 $pid 未响应 SIG$signal,尝试强制终止..."
                if kill -KILL "$pid" 2>/dev/null; then
                    cecho "已强制终止进程 $pid"
                else
                    err "强制终止失败,进程可能已被保护或无权限"
                    return 1
                fi
            else
                cecho "进程 $pid 已成功终止"
            fi
        fi
        return 0
    else
        local kill_result=$?
        case $kill_result in
            1) err "操作不允许: 无法终止进程 $pid" ;;
            127) err "KILL: 命令不可用" ;;
            *) err "终止进程失败 (错误码: $kill_result)" ;;
        esac
        return 1
    fi
}

# ---------- debug ----------
debug_help() {
cecho "$CMD_delimiter"
err "#以下显示的是debug命令:"
cecho "debug/debug_/debug__/debug_help/help_debug/debughelp/helpdebug -假的我"
cecho "debug___/debug_help_/help_debug_ -ME"
cecho "debug_0 <root/adb/normal/[空]> -更改我认为的你的权限"
cecho "debug_1/resource load -debug -查看隐藏资源(默认屏蔽调试和laugh命令)"
cecho "debug_2/debug_line -统计行数"
cecho "$CMD_delimiter"
err "#以下显示的是\$iamvar命令"
cecho "114514/1145141919810 -error stink"
cecho "100/dev100/dev_build_0.100 -正如名字所说"
cecho "yesyesyes/yyy/yy/yesyes -YES YES YES!!!"
cecho "command not found/commandnotfound -command not found!!!"
err "cmd_bomb_fork -炸弹,将会导致设备死机!!!"
cecho "$CMD_delimiter/CMD_delimiter -无意义"
cecho "wtf -wtffffffff"
cecho "wtf2 -wtffffffff"
cecho "$CMD_delimiter"
}
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
debug_2() {
    # 主程序
    local main_lines=$(wc -l < "$0" 2>/dev/null)
    [[ -z "$main_lines" ]] && main_lines=0
    local main_bytes=$(wc -c < "$0" 2>/dev/null)
    [[ -z "$main_bytes" ]] && main_bytes=0

    # 统计 resource 目录
    local res_total=0
    local res_bytes=0
    local file_count=0
    if [[ -d "$RESOURCE_DIR" ]]; then
        while IFS= read -r -d '' file; do
            local lines=$(wc -l < "$file" 2>/dev/null)
            if [[ $? -eq 0 ]]; then
                res_total=$((res_total + lines))
                ((file_count++))
                # 增加字节数统计
                local bytes=$(wc -c < "$file" 2>/dev/null)
                [[ -n "$bytes" ]] && res_bytes=$((res_bytes + bytes))
            fi
        done < <(find "$RESOURCE_DIR" -type f -name "*.bash" -print0 2>/dev/null)
    fi

    cecho -b "--- 代码统计 ---"
    cecho "主程序 ($(basename "$0")): $main_lines 行, $main_bytes 字节"
    if [[ $file_count -gt 0 ]]; then
        cecho "资源目录 (共 $file_count 个 .bash 文件): $res_total 行, $res_bytes 字节"
    else
        err "资源目录未发现bash文件"
    fi
    cecho -b "总行数: $((main_lines + res_total))  总字节数: $((main_bytes + res_bytes))"
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

# ---------- 版本更新检查 ----------
# 从字符串中提取版本号
_extract_ver() {
    echo "$1" | grep -oE '[0-9]+\.[0-9]+' | head -1
}
# 比较两个版本号, 如果 v1 >= v2 返回 0(真), 否则返回 1
_ver_ge() {
    local v1="$1" v2="$2"
    local major1=${v1%%.*} minor1=${v1##*.}
    local major2=${v2%%.*} minor2=${v2##*.}
    if [ "$major1" -gt "$major2" ]; then return 0; fi
    if [ "$major1" -lt "$major2" ]; then return 1; fi
    if [ "$minor1" -ge "$minor2" ]; then return 0; else return 1; fi
}
_get_latest_ver() {
    local url="https://api.github.com/repos/DC10Xraya/Android-CMD/releases/latest"
    local tag=""
    if command -v curl >/dev/null 2>&1; then
        tag=$(curl -s -L --connect-timeout 3 "$url" 2>/dev/null | grep tag_name | cut -d':' -f2 | cut -d'"' -f2)
    elif command -v wget >/dev/null 2>&1; then
        tag=$(wget -qO- --timeout=3 "$url" 2>/dev/null | grep tag_name | cut -d':' -f2 | cut -d'"' -f2)
    fi
    echo "$tag"
}
_update_cache="$TMP_DIR/latest_version"
_update_prompted=0
_update_check_count=0
# 后台执行检查
(
    rm -f "$_update_cache"
    remote_tag=$(_get_latest_ver)
    if [ -n "$remote_tag" ]; then
        remote_ver=$(_extract_ver "$remote_tag")
        current_ver=$(_extract_ver "$CMD_VER")
        if [ -n "$remote_ver" ] && [ -n "$current_ver" ] && ! _ver_ge "$current_ver" "$remote_ver"; then
            # 远程版本大于当前版本
            echo "$remote_tag" > "$_update_cache"
        else
            rm -f "$_update_cache"
        fi
    else
        rm -f "$_update_cache"
    fi
) &

cmd_update() {
   CMD_GITHUB_Link="cecho -c "#6CA8F1" -u "https://github.com/DC10Xraya/Android-CMD/releases""
    local url="https://api.github.com/repos/DC10Xraya/Android-CMD/releases/latest"
    local json=""
    if command -v curl >/dev/null 2>&1; then
        json=$(curl -s -L --connect-timeout 5 "$url" 2>/dev/null)
    elif command -v wget >/dev/null 2>&1; then
        json=$(wget -qO- --timeout=5 "$url" 2>/dev/null)
    else
        err "需要 curl 或 wget"
        return 1
    fi

    if [ -z "$json" ]; then
        err "获取发布信息失败, 请检查网络"
        return 1
    fi

    local tag_name=$(echo "$json" | grep tag_name | cut -d':' -f2 | cut -d'"' -f2)
    if [ -z "$tag_name" ]; then
        err "无法解析版本号"
        return 1
    fi

    local published_at=$(echo "$json" | grep published_at | cut -d':' -f2,3 | cut -d'"' -f2)

    remote_ver=$(_extract_ver "$tag_name")
    current_ver=$(_extract_ver "$CMD_VER")

    if [ -z "$remote_ver" ] || [ -z "$current_ver" ]; then
        err "无法提取版本号 (仓库: '$remote_ver', 当前: '$current_ver')"
        return 1
    fi

    # 比较版本
    if _ver_ge "$remote_ver" "$current_ver"; then
        if [ "$remote_ver" = "$current_ver" ]; then
            cecho -c 92 "已是最新版本 [当前: $remote_ver($tag_name)]"
            $CMD_GITHUB_Link
        else
            cecho -c 96 "新版本: $remote_ver($tag_name) 当前: [$current_ver]"
            [ -n "$published_at" ] && cecho -c 90 "发布时间: $published_at"
            $CMD_GITHUB_Link
        fi
    else
        # 远程版本小于当前版本
        err "未知的版本, 大于仓库的最新版本!"
        cecho -c 93 "当前版本: $current_ver, 仓库最新: $remote_ver($tag_name)"
        $CMD_GITHUB_Link
    fi

    # 执行完后立即删除缓存
    rm -f "$_update_cache"
}
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
    if [ -f "$_update_cache" ]; then
        new_tag=$(cat "$_update_cache")
        new_ver=$(_extract_ver "$new_tag")
        cur_ver=$(_extract_ver "$CMD_VER")
        cecho -c 96 -b "[UPDATE]发现新版本: $cur_ver -> $new_tag (使用 UPDATE 查看详情)"
        _update_prompted=1
        rm -f "$_update_cache"
    else
        _update_check_count=$((_update_check_count + 1))
    fi
    fi
   # 构建命令提示符
    PROMPT_STR="\033[${BG};${CMD_prompt_fg___}m${USERNAME}${PROMPT_SYMBOL} \033[0m"
    read -e -r -p "$(echo -e "$PROMPT_STR")" input

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
    history -s "$input"   # 添加到当前会话历史
    history -w "$HISTFILE" # 立即写入文件
    printf '\033[0m\n'
    
    #dev0.205核心更新: 使用自定义解析器(谁还记得dev0.56的IFS)
    parse_line "$input"
    if [ ${#PARSED_ARGS[@]} -eq 0 ]; then
        continue
    fi

    # 提取命令(第一个单词, 转为小写)和参数数组
    cmd="${PARSED_ARGS[0],,}"
    args_array=("${PARSED_ARGS[@]:1}")

    # 命令分发(按照命令列表顺序)
    case "$cmd" in
    # ---------- 文件和目录操作 ----------
    copy|cp)           cmd_copy "${args_array[@]}" ;;
    del|rm|erase)      cmd_del "${args_array[@]}" ;;
    find)              cmd_find "${args_array[@]}" ;;
    md|mkdir)          cmd_md "${args_array[@]}" ;;
    touch|new)         cmd_touch "${args_array[@]}" ;;
    move|ren|rename)   cmd_move "${args_array[@]}" ;;
    rd|rmdir)          cmd_rd "${args_array[@]}" ;;
    dir)               cmd_dir "${args_array[@]}" ;;
    du)                cmd_du "${args_array[@]}" ;;
    size)              cmd_size "${args_array[@]}" ;;
    ln)                cmd_ln "${args_array[@]}" ;;
    tree)              cmd_tree "${args_array[@]}" ;;
    type)              cmd_type "${args_array[@]}" ;;
    more)              cmd_more "${args_array[@]}" ;;
    # ---------- 系统信息 ----------
    now|date|time|datetime)  cecho "$($_DATE "+%Y-%m-%d %H:%M:%S (%A)")" ;;
    clock)             cmd_clock ;;
    free)              cmd_free ;;
    df)                $_DF -h 2>&1 | while IFS= read -r line; do cecho "$line"; done ;;
    getprop)           cmd_getprop "${args_array[@]}" ;;
    env|export)        cmd_env "${args_array[@]}" ;;
    path)              cecho "$PATH" ;;
    uptime)            $_UPTIME 2>&1 | while IFS= read -r line; do cecho "$line"; done ;;
    systeminfo)        cmd_systeminfo ;;
    tl|tasklist)       cmd_tasklist ;;
    which)             cmd_which "${args_array[@]}" ;;
    pwd)               cecho "$(pwd)" ;;
    self)              cecho "$0" ;;
    # ---------- 网络 ----------
    netstat)           $_NETSTAT 2>&1 | while IFS= read -r line; do cecho "$line"; done ;;
    hostname)          cecho "$($_HOSTNAME 2>/dev/null || echo 'localhost')" ;;
    # ---------- 控制台 / 杂项 ----------
    help|/? )          cmd_help ;;
    cls|clear)         cmd_cls "${args_array[@]}" ;;
    clsd|cleard)       cmd_clsd "${args_array[@]}" ;;
    title)             cmd_title "${args_array[@]}" ;;
    color)             cmd_color "${args_array[@]}" ;;
    tmpdir)            cmd_tmpdir "${args_array[@]}" ;;
    resource)          cmd_resource "${args_array[@]}" ;;
    history)           cmd_history "${args_array[@]}" ;;
    config)            cmd_config "${args_array[@]}" ;;
    update)            cmd_update ;;
    echo|print)        cmd_echo "${args_array[@]}" ;;
    printf)            printf "${args_array[@]}"; echo "" ;;
    cecho)             cmd_cecho "${args_array[@]}" ;;
    err)               err "${args_array[*]}" ;;
    yes)               cmd_yes "${args_array[@]}" ;;
    sleep)             cmd_sleep "${args_array[@]}" ;;
    awkc)              cmd_awkc "${args_array[@]}" ;;
    bc)                cmd_bc "${args_array[@]}" ;;
    watch)             cmd_watch "${args_array[@]}" ;;
    repeat)            cmd_repeat "${args_array[@]}" ;;
    exit|exit15)       cmd_exit15 ;;
    exit9)             cmd_exit9 ;;
    exitk|killself)    cmd_killself ;;
    cmdinfo|info)      cmd_cmdinfo ;;
    ctrl+c)            cmd_exit15_0 ;;
    ulimit)            cmd_ulimit "${args_array[@]}" ;;
    sh)                cmd_sh "${args_array[@]}" ;;
    c|cmd)             cmd_cmd "${args_array[@]}" ;;
    adb)               cmd_adb "${args_array[@]}" ;;
    running)           cmd_running "${args_array[@]}" ;;
    kill)              cmd_kill "${args_array[@]}" ;;
    # ---------- debug  ----------
    debug|debug_|debug__|debug_help|help_debug|debughelp|helpdebug)
        err "调试模式还在设计中(真的吗?)" ;;
    debug___|debug_help_|help_debug_)  debug_help ;;
    debug_0)  debug_0 "${args_array[@]}" ;;
    debug_1)  cmd_resource load -debug "${args_array[@]}" ;;
    debug_2|debug_line)  debug_2 ;;
    $CMD_delimiter|cmd_delimiter|$CMD_delimiter/cmd_delimiter)   err "bro 复制这个何意味?" ;;
    # ---------- 特殊 ----------
    114514)     lazy_load "laugh_114514" && cmd_laugh_114514 ;;
    100|dve100) lazy_load "laugh_100" && cmd_laugh_100 ;;
    200|dev200) lazy_load "laugh_200" && cmd_laugh_200 ;;
    yesyesyes|yyy|yy|yesyes) lazy_load "laugh_yyy" && cmd_laugh_yyy ;;
    command|commandnotfound) lazy_load "laugh_command_not_found" && cmd_laugh_command_not_found "${args_array[@]}" ;;
    permission|permissiondenied) lazy_load "laugh_permission_denied" && cmd_laugh_permission_denied "${args_array[@]}" ;;
    wtf)
        lazy_load "hack"  # 预加载依赖
        lazy_load "laugh_wtf" && cmd_laugh_wtf ;;
    wtf2)
        lazy_load "hack2" # 预加载依赖
        lazy_load "laugh_wtf2" && cmd_laugh_wtf2 ;;
    netneig)  
        lazy_load "scan"  # 预加载依赖
        lazy_load "netneig" && cmd_netneig ;;
    cmd_bomb_fork|bomb_fork|fork_bomb) lazy_load "bomb_fork" && cmd_bomb_fork ;;
    # ---------- 别名 ----------
    whoami|op) lazy_load "whoami_op" && cmd_whoami_op ;;
    b64)       lazy_load "base64" && cmd_base64 "${args_array[@]}" ;;
    st)       lazy_load "speedtest" && cmd_speedtest ;;
    sysinfo)  lazy_load "systeminfo" && cmd_systeminfo ;;
    tm|top|taskmgr|taskmanager) lazy_load "taskmanager" && cmd_taskmanager ;;
    sha256|sha256sum) lazy_load "sha256" && cmd_sha256 ;;
    sha1|sha1sum) lazy_load "sha1" && cmd_sha1 ;;
    # ---------- 懒惰加载 / 未知命令 ----------
    *)
        if lazy_load "$cmd"; then
            "cmd_$cmd" "${args_array[@]}"
        else
            err "$cmd: 命令未找到"
        fi
        ;;
esac
done
#null