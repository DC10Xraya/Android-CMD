# Android CMD
### 一个为 Android 终端环境设计的 Bash 交互脚本, 旨在模仿CMD.exe, 并且加入更多特色功能

---

### 怎样使用?

1. 下载最新发行版到固定目录(每次都会覆盖旧包):
```bash
curl -L -o /storage/emulated/0/Download/Android-CMD.tar.gz \
  "$(curl -s https://api.github.com/repos/DC10Xraya/Android-CMD/releases/latest \
  | grep -o 'https://[^"]*\.tar\.gz' \
  | head -n1)"
```
或者用wget(如果上面curl的不行)
```bash
wget -O /storage/emulated/0/Download/Android-CMD.tar.gz \
  "$(wget -qO- https://api.github.com/repos/DC10Xraya/Android-CMD/releases/latest \
  | grep -o 'https://[^"]*\.tar\.gz' \
  | head -n1)"
```

2. 解压并运行:

```bash
# 设置解压目录(可改成你想要的路径)
INSTALL_DIR="/storage/emulated/0/Android-CMD"

# 1. 创建目录
mkdir -p "$INSTALL_DIR"

# 2. 解压并删除原来的压缩包
tar -xzf /storage/emulated/0/Download/Android-CMD.tar.gz -C "$INSTALL_DIR" \
  && rm -f /storage/emulated/0/Download/Android-CMD.tar.gz

# 3. 运行脚本
cd "$INSTALL_DIR"
bash CMD_main_dev.bash
```

启动后输入 HELP 或 /? 即可查看内置命令列表

如果想运行系统命令, 可以使用C(eval)或BASH命令来运行系统命令

如果想在内部继续运行其他脚本, 可以使用SH

### 运行依赖

基础环境为 Bash 4.0+, 必须预装:

```txt
Awk, Grep, Sed, Cat, Cut, Head, Tail, BC, wget 或 curl
```

缺失以上依赖无法启动脚本, 其他的依赖缺失可能导致部分命令无法使用

* 如果curl、wget只存在一个, 每次启动时都会提醒, 并且一些网络功能不可用; 如果都不存在, 则无法启动

---

MIT License

Copyright (c) 2026 DC10Xray

更多信息: https://github.com/DC10Xraya/Android-CMD

* 此文件仅在运行前提供帮助, 不是真正的README, 一些内容在新版本中可能过时