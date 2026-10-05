#/resource/cmd_laugh_command_not_found.bash
cmd_laugh_command_not_found() {
    if [ $# -gt 0 ]; then
        if [ $# -eq 2 ] && [ "$1" = "not" ] && [ "$2" = "found" ]; then
            :
        else
            err "command: 命令未找到"
            return 1
        fi
    fi

    local line_count_laugh=$(grep -nE '^[[:space:]]*(function[[:space:]]+)?cmd_exit15[[:space:]]*(\(\))?' "$0" | head -n1 | cut -d: -f1)
    local total_lines=$(wc -l < "$0")
    if ! confirm "command not found?(如不想影响你的工作,请输入N)"; then
        return
    fi
    if ! confirm "确认?(可能使你无法退出,造成的影响与作者无关,你已经被警告过了)"; then
        return
    fi
local CMD_prompt_fg___
if [ "$BG" = "40" ] && [ "$FG" = "97" ]; then
    case "$PRIV_LEVEL" in
        root) CMD_prompt_fg___=95 ;;
        adb)  CMD_prompt_fg___=96 ;;
        *)    CMD_prompt_fg___=97 ;;
    esac
else
    CMD_prompt_fg___="$FG"
fi
if [ $_IAMDC10XRAY_ -eq 1 ]; then
    CMD_prompt_fg___='38;5;201'
fi

local PROMPT_STR="\033[${BG};${CMD_prompt_fg___}m${USERNAME}${PROMPT_SYMBOL} \033[0m"

trap 'echo ""; echo "$0: line $line_count_laugh: cmd_exit15: command not found"' INT TERM QUIT
    while true; do
    printf "%b" "$PROMPT_STR"
    if ! read fake_input; then
        echo ""
        echo "$0: line $line_count_laugh: cmd_exit15: command not found"
        continue
    fi
    [ -z "$fake_input" ] && continue
    local cmd_name="cmd_${fake_input%% *}"
    local cmd_line=$(grep -nE "^[[:space:]]*(function[[:space:]]+)?${cmd_name}[[:space:]]*(\(\))?([[:space:]]|$)" "$0" | head -n1 | cut -d: -f1)
    [ -z "$cmd_line" ] && cmd_line="$total_lines"
    echo "$0: line $cmd_line: ${cmd_name}: command not found"
done
}