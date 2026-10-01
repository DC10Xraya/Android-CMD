cmd_china() {
    local current_year=$(date +%Y)
    local anniversary=$((current_year - 1949))
    ccat << EOF
//cecho -b -c "#DE2910" "         1949  -  $current_year"
//cecho -b -c "#FFDE00" "★ 热烈庆祝中华人民共和国成立${anniversary}周年! ★"
//cecho -c "#DE2910" "生在红旗下, 长在春风里。"
//cecho -c "#DE2910" "目光所至皆为华夏, 五星闪耀皆为信仰!"
EOF
}