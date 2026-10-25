#resource/cmd_rand.bash
cmd_rand() {
    if [ $# -eq 0 ]; then
        cecho $RANDOM
        echo ""
    else
        tr -dc '0-9' < /dev/urandom 2>/dev/null | head -c ${1:-4} | sed 's/^0*//' || cecho $RANDOM
        echo ""
    fi
}