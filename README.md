**简体中文** | [English](README_EN.md)

Android CMD
============

![Language](https://img.shields.io/badge/Language-Bash-blue)
![License](https://img.shields.io/badge/License-MIT-blue)
![Lines](https://img.shields.io/badge/Code-8800%2B-blue)
![Android](https://img.shields.io/badge/Platform-Android-brightgreen?logo=android)

一个集成了常用运维, 网络与系统监控功能(还有笑话)的交互式 Bash 脚本,  专门在 Android 上运行

<details>
<summary><h2>命令 (91) 点击以查看</h2></summary>

注：不包含隐藏（laugh）和调试命令
  
| 命令 | 描述 |
| :--- | :--- |
| COPY/CP | 复制文件/目录 |
| RM/DEL | 删除文件或目录 |
| RD/RMDIR | 删除空目录 |
| FIND | 在指定文件中搜索 |
| MD/MKDIR | 创建目录 |
| NEW/TOUCH | 创建新文件 |
| MOVE | 移动或重命名 |
| REN | 重命名文件 |
| DIR | 列出目录内容 |
| DU | 列出目录大小 |
| SIZE | 列出文件大小 |
| STAT | 显示文件详细信息 |
| LN -s | 创建软链接 |
| TREE | 显示目录树 |
| TYPE | 查看文本文件 |
| MORE | 分页查看 |
| ZIP | 创建ZIP压缩包 |
| UNZIP | 解压ZIP压缩包 |
| NOW | 显示当前时钟 |
| CAL | 显示日历 |
| CLOCK | 实时时间 |
| FREE | 内存使用 |
| DF | 磁盘使用 |
| GETPROP | 系统属性 |
| ENV/EXPORT | 环境变量 |
| LOGCAT | 系统日志 |
| UPTIME | 运行时间 |
| RES/WM | 屏幕信息 |
| BATT | 电池信息 |
| SYSTEMINFO | 系统信息 |
| TL/TASKLIST | 进程列表 |
| TM/TOP/TASKMGR | 任务管理器 |
| TEMP | 温度监控 |
| MONITOR | 监控时间、内存、温度 |
| WHOAMI/OP | 用户UID和权限 |
| WHICH | 查找命令路径 |
| DISKC | 挂载点读写速度 |
| DISKT | 存储设备读写速度 |
| PWD | 当前目录 |
| SELF | 脚本路径 |
| NETSTAT | 网络连接统计 |
| HOSTNAME | 主机名 |
| DNS | 转换IPV4或域名 |
| NETNEIG | 扫描局域网主机 |
| FTP | FTP功能 |
| PING | 测试网络连接 |
| SCAN | 扫描存活主机 |
| PORTSCAN | 扫描存活端口 |
| DOWNLOAD | 下载网络文件 |
| ST/SPEEDTEST | 网络测速 |
| MCMODDOWNLOAD | 从Modrinth下载模组 |
| BASE64/B64 | Base64编解码 |
| SHA256 | 计算SHA256 |
| SHA1 | 计算SHA1 |
| MD5 | 计算MD5 |
| CRC32 | 计算CRC32 |
| PSD | 生成随机密码 |
| RAND | 生成随机数 |
| ECHO/PRINT | 显示消息 |
| PRINTF/ECHO -e | 解析代码显示 |
| CECHO | 自定义显示 |
| ERR | 显示错误 |
| YES | 刷屏 |
| HACK | 穷举目标 |
| HACK2 | 二分法穷举目标 |
| AWKC | AWK计算器 |
| BC | 任意精度计算器 |
| TIMER | 倒计时/闹钟 |
| SLEEP | 睡眠指定时间 |
| WATCH | 循环执行命令 |
| REPEAT | 重复执行指定次数 |
| CLS/CLEAR | 清除屏幕 |
| CLSD/CLEARD | 设置清除屏幕默认行为 |
| COLOR | 设置控制台颜色 |
| TITLE | 设置控制台标题 |
| TMPDIR | 设置临时目录 |
| RESOURCE | 查看/重载资源 |
| HISTORY | 历史命令 |
| CONFIG | 显示配置或恢复 |
| UPDATE | 检查更新 |
| INFO | 显示脚本信息 |
| HELP | 查看帮助 |
| EXIT/EXIT15 | 正常退出 |
| EXIT9 | 强制退出 |
| EXITK/KILLSELF | 杀掉自己 |
| ULIMIT | 限制SHELL |
| SH | 执行外部SHELL脚本 |
| C/CMD | 执行系统命令 |
| ADB | 执行ADB命令 |
| RUNNING | 启动应用程序 |
| KILL | 终止指定进程 |

</details>

### 核心模块
- **系统与文件**: TREE(目录树), STAT(文件元数据), SIZE/DU(空间占用), COPY/MOVE/DEL
- **网络工具**: PING(支持大包与洪水模拟), SCAN(IP 存活探测), PORTSCAN, FTP(伪交互), DOWNLOAD
- **编解码与校验**: BASE64, URLENCODE/DECODE, MD5, SHA1, CRC32
- **性能监控**: TM/TASKMGR(进程详情与内存), TEMP(传感器温度), FREE/DF
- **控制台扩展**: CECHO(自定义高亮输出), AWKC/BC(二种计算器), TIMER, WATCH(循环执行)
- **Laugh**: 一些彩蛋, 不告诉你 awa

### 特色
- 下载解压一键式使用, 上手简单
- 模块化设计, Lazy加载(0.05+), 启动更快 ; 新的函数可以放在 resource 目录中, 易于维护 ; 配置与历史记录保存在 etc 目录下(0.06+)
- 交互增强: 上下箭头调用历史命令, HISTORY 命令管理记录(0.06+)
- 配置保存: 保存你的Color、Title、TMPDIR、Clsd设置
- 识别你的权限, 给你不同的命令提示符
- 命令众多, 功能强大, 已超过 230 个开发版本
- 还有关于我的世界的功能和设计

### 启动方式
1. 解压下载得到的 .tar.gz 压缩包
2. 打开终端, 执行以下命令:
```bash
cd #主程序(cmd_main_dev)所在目录
bash CMD_main_dev.bash
```

启动后输入 HELP 或 /? 即可查看所有命令列表

运行依赖

基础环境为 Bash 4.0+, 必须预装:

```txt
Awk, Grep, Sed, Cat, Cut, Head, Tail, BC, wget<or>curl
```

缺失以上依赖无法启动脚本。其他的依赖缺失可能导致部分命令无法使用。

杂七杂八

这个脚本虽然开发了很久(230多个dev), 但是难免会有不足, 遇到任何问题都可以提出, 不喜欢也别喷qwq

许可证

MIT License
Copyright (c) 2026 DC10Xray

[![Email](https://img.shields.io/badge/Email-3896444757%40qq.com-brightgreen?logo=gmail&logoColor=white)](mailto:3896444757@qq.com)
