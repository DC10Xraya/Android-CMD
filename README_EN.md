[简体中文](README.md) | **English**

# Android CMD
<p align="left">
  <img src="icon.png" alt="Android CMD" width="250">
</p>

![Language](https://img.shields.io/badge/Language-Bash-blue)
![License](https://img.shields.io/badge/License-MIT-blue)
![Lines](https://img.shields.io/badge/Code-8800%2B-blue)
![Android](https://img.shields.io/badge/Platform-Android-brightgreen?logo=android)

An interactive Bash script integrating common system administration, network, and system monitoring features (and jokes), specifically designed for Android.

<details>
<summary><h2>Command (91) Click to view</h2></summary>

Note: Excluding hidden (laugh) and debug commands.
  
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

## Core Foundation Modules(Built into the main script)

1. **Color & Output System** (`_cprint`/`cecho`/`ccat`)  
   Provides styled terminal output with colors (16‑color, 256‑color, and hex RGB), bold, italic, underline, and strikethrough. Also parses `//cecho` directives inside files for rich text rendering.

2. **Command Line Parser** (`parse_line`)  
   A custom argument parser that handles single quotes, double quotes, escape characters, and comments (`#`). Splits input into the `PARSED_ARGS` array for command dispatching.

3. **Configuration Management** (`load_config`/`save_config`)  
   Reads and writes user settings (background, foreground, title display, temp directory) from/to `etc/cmd_config` for persistence.

4. **History Management** (`HISTFILE` and related functions)  
   Automatically loads and saves command history, with size checking, deduplication, and full support for the `HISTORY` command.

5. **Signal Handling & Exit Mechanism** (`exit9`/`exit15`/traps)  
   Handles SIGINT, SIGTERM, etc., recursively kills child process trees, cleans up temporary files, and ensures safe exit (either forceful or graceful).

6. **Utility Functions** (`confirm`/`kill_tree`/`file_op`/`err`)  
   Provides interactive confirmation, process‑tree killing, file copy/move with overwrite confirmation, and red error output.

7. **Privilege Detection** (`PRIV_LEVEL`/`PROMPT_SYMBOL`)  
   Detects root, adb, or normal user via `id`, `ps`, and `getprop` at startup, and sets the prompt symbol (`#`/`$`/`->`) accordingly.

8. **Path & Directory Management** (`SCRIPT_DIR`/`RESOURCE_DIR`/`ETC_DIR`/`TMP_DIR`)  
   Defines and ensures the existence/writability of script root, resource, config, and temporary directories.

9. **Lazy Loader** (`lazy_load`)  
   Dynamically loads external command files (`cmd_*.bash`) from the `resource/` directory on demand, reducing startup overhead.

10. **Initialization** (`init_tools`/`load_splashes`/`get_title`)  
    Detects `busybox`, sets tool prefixes, loads random splash messages, and displays the startup title and version info.

11. **Update Checker** (background check + `cmd_update`)  
    Periodically queries the GitHub API for new releases in the background, caches the result, and prompts for updates in the main loop. The `UPDATE` command shows details manually.

### Features
- One-click download and extract, easy to use
- Modular design, Lazy loading, fast startup; new functions placed in resource directory; config and history in etc directory
- Interactive: Arrow keys for history, HISTORY command to manage
- Config saves your Color, Title, TMPDIR, Clsd settings
- Recognizes your permissions and gives different prompts
- Over 230 dev versions
- Hidden (laugh) command
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

[![Email](https://img.shields.io/badge/Email-3896444757%40qq.com-brightgreen?logo=gmail&logoColor=white)](mailto:3896444757@qq.com)
