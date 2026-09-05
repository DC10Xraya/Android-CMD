cmd_laugh_walmart () {
    local old_trap=$(trap -p INT)

    trap 'break' INT

    colors=(31 32 33 34 35 36 37 90 91 92 93 94 95 96 97)
    while true; do
        idx=$((RANDOM % ${#colors[@]}))
        color=${colors[$idx]}
        printf "\033[${color}m沃尔玛购物袋\033[0m\n"
    done
    if [[ -n "$old_trap" ]]; then
        eval "$old_trap"
    else
        trap - INT
    fi
}