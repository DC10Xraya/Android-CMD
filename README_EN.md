[简体中文](README.md) | **English**

Android CMD
============

![Language](https://img.shields.io/badge/Language-Bash-blue)
![License](https://img.shields.io/badge/License-MIT-blue)
![Lines](https://img.shields.io/badge/Code-8800%2B-blue)
![Android](https://img.shields.io/badge/Platform-Android-brightgreen?logo=android)

An interactive Bash script integrating common system administration, network, and system monitoring features (and jokes), specifically designed for Android.

<details>
<summary><b>Commands (91)</b></summary>
  
| Command | Description |
| :--- | :--- |
| COPY/CP | Copy files/directories |
| RM/DEL | Delete files or directories |
| RD/RMDIR | Delete empty directories |
| FIND | Search in specified files |
| MD/MKDIR | Create directory |
| NEW/TOUCH | Create new file |
| MOVE | Move or rename |
| REN | Rename file |
| DIR | List directory contents |
| DU | List directory sizes |
| SIZE | List file size |
| STAT | Show file details |
| LN -s | Create symbolic link |
| TREE | Display directory tree |
| TYPE | View text file |
| MORE | Paginated view |
| ZIP | Create ZIP archive |
| UNZIP | Extract ZIP archive |
| NOW | Show current clock |
| CAL | Show calendar |
| CLOCK | Real-time clock |
| FREE | Memory usage |
| DF | Disk usage |
| GETPROP | System properties |
| ENV/EXPORT | Environment variables |
| LOGCAT | System logs |
| UPTIME | System uptime |
| RES/WM | Screen info |
| BATT | Battery info |
| SYSTEMINFO | System info |
| TL/TASKLIST | Process list |
| TM/TOP/TASKMGR | Task manager |
| TEMP | Temperature monitor |
| MONITOR | Monitor time, memory, temp |
| WHOAMI/OP | User UID and permissions |
| WHICH | Find command path |
| DISKC | Mount point R/W speed |
| DISKT | Storage R/W speed |
| PWD | Current directory |
| SELF | Script path |
| NETSTAT | Network connections |
| HOSTNAME | Hostname |
| DNS | Convert IPv4/Domain |
| NETNEIG | Scan LAN hosts |
| FTP | FTP functionality |
| PING | Test network connection |
| SCAN | Scan live hosts |
| PORTSCAN | Scan live ports |
| DOWNLOAD | Download network file |
| ST/SPEEDTEST | Network speed test |
| MCMODDOWNLOAD | Download MC Java mods |
| BASE64/B64 | Base64 encode/decode |
| SHA256 | Calculate SHA256 |
| SHA1 | Calculate SHA1 |
| MD5 | Calculate MD5 |
| CRC32 | Calculate CRC32 |
| PSD | Generate random passwords |
| RAND | Generate random numbers |
| ECHO/PRINT | Display message |
| PRINTF/ECHO -e | Parse code display |
| CECHO | Custom display |
| ERR | Display error |
| YES | Screen spam until Ctrl+C |
| HACK | Brute force target |
| HACK2 | Binary search brute force |
| AWKC | AWK calculator |
| BC | Arbitrary precision calculator |
| TIMER | Countdown/Alarm |
| SLEEP | Sleep for specified time |
| WATCH | Loop execute command |
| REPEAT | Repeat execution N times |
| CLS/CLEAR | Clear screen |
| CLSD/CLEARD | Set default clear behavior |
| COLOR | Set console color |
| TITLE | Set console title |
| TMPDIR | Set temporary directory |
| RESOURCE | View/Reload resources |
| HISTORY | Command history |
| CONFIG | Show config or restore |
| UPDATE | Check updates |
| INFO | Show script info |
| HELP | View help |
| EXIT/EXIT15 | Normal exit |
| EXIT9 | Force exit |
| EXITK/KILLSELF | Kill self to exit |
| ULIMIT | Limit SHELL |
| SH | Execute external shell script |
| C/CMD | Execute system command |
| ADB | Execute ADB commands |
| RUNNING | Launch application |
| KILL | Terminate process |

</details>

### Core Modules
- **System & Files**: TREE, STAT, SIZE/DU, COPY/MOVE/DEL
- **Network Tools**: PING, SCAN, PORTSCAN, FTP, DOWNLOAD
- **Encoding & Checksums**: BASE64, URL, MD5, SHA1, CRC32
- **Performance Monitor**: TM/TASKMGR, TEMP, FREE/DF
- **Console Extensions**: CECHO, AWKC/BC, TIMER, WATCH
- **Laugh**: Some easter eggs, not telling you awa

### Features
- One-click download and extract, easy to use
- Modular design, Lazy loading, fast startup; new functions placed in resource directory; config and history in etc directory
- Interactive: Arrow keys for history, HISTORY command to manage
- Config saves your Color, Title, TMPDIR, Clsd settings
- Recognizes your permissions and gives different prompts
- Over 230 dev versions
- Features related to Minecraft

### How to Run
1. Extract the downloaded .tar.gz file
2. Open terminal and run:
```bash
cd #Directory of the main program (cmd_main_dev)
bash CMD_main_dev.bash
```

Enter HELP or /? after startup to see all commands.

Dependencies

Requires Bash 4.0+, and these must be pre-installed:

```txt
Awk, Grep, Sed, Cat, Cut, Head, Tail, BC, wget<or>curl
```

The script will not start if missing the above. Missing others might break some commands.

Misc

Developed for over 230 dev versions, it may still have flaws. Feel free to raise issues, but please don't hate on it qwq

License

MIT License
Copyright (c) 2026 DC10Xray

https://img.shields.io/badge/Email-3896444757@qq.com-brightgreen?logo=gmail&logoColor=white
