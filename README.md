Android CMD
一个集成了常用运维、网络与系统监控功能的交互式终端脚本, 专为 Android 平台优化。

##核心模块

· 系统与文件：DIR/TREE（目录树）、STAT（文件元数据）、SIZE/DU（空间占用）、COPY/MOVE/DEL。

· 网络工具：PING（支持大包与洪水模拟）、SCAN（IP 存活探测）、PORTSCAN、FTP（交互式客户端）、DOWNLOAD。

· 编解码与校验：BASE64、URLENCODE/DECODE、MD5、SHA1、CRC32。

· 性能监控：TM/TASKMGR（进程详情与内存）、TEMP（传感器温度）、FREE/DF。

· 控制台扩展：CECHO（自定义高亮输出）、CALC/BC（计算器）、TIMER、WATCH（循环执行）。

##特色

模块化设计, 主程序从resource目录加载资源文件, 提高启动速度, 减小主程序大小


##启动方式

```bash
cd #主程序所在目录
bash CMD_main_dev.bash
```

启动后输入 HELP 或 /? 即可查看所有命令列表。

##运行依赖

基础环境为 Bash 4.0+, 部分模块需系统预装 bc、awk、netstat 与 ping。缺失依赖时, 对应功能会提示错误或降级运行。

##杂七杂八

作为这个作品的第一个正式版本, 难免会有不足, 遇到任何问题都可以向作者提出
(这真的是第163个开发版本)

MIT License
Copyright (c) 2026 DC10Xray
