Android CMD
============

![Language](https://img.shields.io/badge/Language-Shell-blue)
![License](https://img.shields.io/badge/License-MIT-blue)
![Lines](https://img.shields.io/badge/Code-8000%2B-blue)
![Android](https://img.shields.io/badge/Platform-Android-brightgreen?logo=android)

一个集成了常用运维, 网络与系统监控功能的交互式 Bash 脚本,  专门在 Android 上运行

核心模块
---------
- 系统与文件: DIR/TREE(目录树), STAT(文件元数据), SIZE/DU(空间占用), COPY/MOVE/DEL
- 网络工具: PING(支持大包与洪水模拟), SCAN(IP 存活探测), PORTSCAN, FTP(伪交互), DOWNLOAD
- 编解码与校验: BASE64, URLENCODE/DECODE, MD5, SHA1, CRC32
- 性能监控: TM/TASKMGR(进程详情与内存), TEMP(传感器温度), FREE/DF
- 控制台扩展: CECHO(自定义高亮输出), CALC/AWKC/BC(三种计算器), TIMER, WATCH(循环执行)
- Laugh: 一些彩蛋, 不告诉你 awa

特色
-----
- 下载解压一键式使用, 上手简单
- 模块化设计, 新的函数可以放在resource目录中, 易于维护 ; 减小主程序体积, 加快启动速度
- 命令众多, 功能强大

启动方式
---------
1. 解压下载得到的 Releases.*.tar.gz 压缩包
2. 打开终端, 执行以下命令:
```bash
cd #主程序(cmd_main_dev)所在目录
bash CMD_main_dev.bash
```
启动后输入 HELP 或 /? 即可查看所有命令列表

运行依赖
---------
基础环境为 Bash 4.0+, 需系统预装 bc, awk, ping
缺失依赖时, 对应功能会提示错误或降级运行

杂七杂八
---------
这个脚本虽然开发了很久(100多个dev), 但是难免会有不足, 遇到任何问题都可以向我提出, 不喜欢也别喷qwq

许可证
-------
MIT License

Copyright (c) 2026 DC10Xray

![QQ](https://img.shields.io/badge/QQ-3896444757-blue?logo=tencent-qq&logoColor=white)
[![Email](https://img.shields.io/badge/Email-3896444757@qq.com-brightgreen?logo=gmail&logoColor=white)](mailto:3896444757@qq.com)