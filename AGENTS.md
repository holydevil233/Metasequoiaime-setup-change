# AGENTS.md — 水杉输入法（MetasequoiaIME）一键安装包 AI 维护指南

本文档面向 AI 编程助手，用于快速理解本项目的结构、关键设计约束（避免误改导致功能回退）以及常见故障排查方法。

---

## 1. 项目结构

```text
metasequoiaime-setup/
├── AGENTS.md                        # 本文件（AI 专用上下文与约束说明）
├── README.md                        # 人类用户使用说明
├── 一键安装.bat                      # 入口脚本：自动 UAC 提权并调用 install.ps1
├── install.ps1                      # PowerShell 主安装脚本（支持在线下载与离线 installers/）
└── config/
    ├── config.toml                  # 水杉输入法配置文件（目标：%LOCALAPPDATA%\metasequoiaime\config.toml）
    ├── caps-ime.ahk                 # AutoHotkey v2 脚本（目标：%LOCALAPPDATA%\metasequoiaime\caps-ime.ahk 及开机启动目录）
    └── skins/
        └── bigfish-peek/            # 候选框皮肤资源（目标：%LOCALAPPDATA%\metasequoiaime\skins\bigfish-peek\）
```

---

## 2. 运行时架构与系统路径

- **输入法版本**：MetasequoiaIME `v0.13.2`（纯 TSF 架构）
  - 服务端：`C:\Program Files\metasequoiaime\server\MetasequoiaImeServer.exe`
  - 守护进程：`C:\Program Files\metasequoiaime\server\MetasequoiaImeWatchdog.exe`（由计划任务 `Metasequoia IME Watchdog` 拉起）
  - TSF DLL：`C:\Windows\system32\IME\MetasequoiaIME\msime_v0.13.2\MetasequoiaImeTsf.dll`（及 `SysWow64` 对应路径）
  - TSF CLSID：`{E3062E9A-D834-4637-8958-ED8CFA427D01}`，Profile：`{4D59B1B4-D503-44AE-9259-BAD9BB2778AB}`，LangID：`0x0804`
  - 命名管道：`\\.\pipe\FanyImeNamedPipe`、`\\.\pipe\FanyImeToTsfNamedPipe` 等
- **用户数据目录**：`%LOCALAPPDATA%\metasequoiaime\`
  - 配置文件：`%LOCALAPPDATA%\metasequoiaime\config.toml`
  - 诊断日志：`%LOCALAPPDATA%\metasequoiaime\logs\水杉IME诊断日志-{server,tsf}-*.log`
- **按键映射依赖**：AutoHotkey v2（`C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe`）
  - 开机自启：`%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Metasequoia Caps.ahk`

---

## 3. 关键设计约束（请勿随意更改）

### 3.1 为什么 `config.toml` 必须保留 `switch_language_shift = true`
- **不要**改成 `switch_language_shift = false` + `switch_language_ctrl_alt_space = true`。
- **原因**：在 Electron / Chromium 类应用（如 Antigravity、VS Code 等）以及部分 Windows 11 窗口中，`Ctrl+Alt+Space` 会被系统或宿主窗口拦截，无法到达 `MetasequoiaImeTsf.dll` 的 `OnTestKeyDown`，导致 `CapsLock` 完全失效。
- 水杉输入法原生最稳定的中英文切换方式是 `bare-shift-keyup`（`switch_language_shift = true`）。

### 3.2 `caps-ime.ahk` 如何实现「仅 Caps 切换、Shift 不切换、英文默认小写」
1. `SetCapsLockState "AlwaysOff"`：永久关闭系统原生大写锁定。切到英文模式后默认输入小写，`Shift + 字母` 输入大写。
2. `CapsLock::` 发送 `{LShift down}{LShift up}`：触发水杉输入法的 `bare-shift-keyup` 切换中英文。
3. `*LShift` / `*RShift up`：当单独按松物理 `Shift`（`A_PriorKey = "LShift"` 或 `"RShift"`）时，在释放前注入无副作用的未分配键码 `{Blind}{vkE8}`，打断 TSF 的 `bare-shift` 判定，从而**物理 `Shift` 不会切换中英文**；`Shift + 字母`、`Shift + 点击` 等组合键由于 `A_PriorKey` 不是 `Shift`，不受影响。

### 3.3 在自动化终端中重启 `AutoHotkey64.exe` 的注意事项
- 在 AI 工具的命令沙箱/子终端中直接用 `Start-Process` 启动 `AutoHotkey64.exe`，进程可能会绑定到当前终端的 Job Object 并在命令结束时被一并杀死。
- 如需在自动化脚本/工具回合中持久化启动 `AutoHotkey64.exe`，请使用 WMI `Win32_Process.Create`（`Invoke-CimMethod`）使其脱离当前终端 Job Object：
  ```powershell
  $cmd = '"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" "C:\Users\Administrator\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\Metasequoia Caps.ahk"'
  Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine=$cmd}
  ```

---

## 4. 常见故障排查清单（AI 排查顺序）

### 4.1 无输入候选框
1. **检查服务进程**：确认 `MetasequoiaImeServer.exe` 与 `MetasequoiaImeWatchdog.exe` 均在运行；若卡死可 `Stop-Process -Name "MetasequoiaImeServer" -Force` 让 Watchdog 自动拉起。
2. **开启诊断日志**（排障完成后务必改回 `false`）：
   修改 `config.toml` 的 `[general]`：
   ```toml
   diagnostic_log = true
   tsf_diagnostic_log = true
   candidate_window_diagnostic_log = true
   ```
   重启 `MetasequoiaImeServer.exe` 后打字，检查 `%LOCALAPPDATA%\metasequoiaime\logs\`：
   - 若无 `tsf` 日志或无 `keydown` 记录：检查 `HKLM:\SOFTWARE\Microsoft\CTF\TIP\{E3062E9A-D834-4637-8958-ED8CFA427D01}` 注册表项，以及 `MetasequoiaImeTsf.dll` 的 `icacls` 是否包含 `ALL APPLICATION PACKAGES:(I)(RX)`（影响 UWP/新版记事本）。
   - 若有 `candidate-frame show ... visible=true cloaked=no` 但用户仍看不见：检查运行库（WebView2 Runtime、VC++ 2015-2022 x64）以及当前皮肤（`bigfish-peek`）或 Windows 11 26H2 DirectComposition（`composition=1`）渲染状态。

### 4.2 CapsLock 无法切换中英文 / 切换后变成大写 / Shift 也能切换
1. 检查 `AutoHotkey64.exe` 是否存活且只有一个实例在运行（多实例或旧脚本未退出会导致行为异常）：
   ```powershell
   Get-CimInstance Win32_Process -Filter "Name='AutoHotkey64.exe'" | Select-Object ProcessId, CommandLine
   ```
2. 检查 `[Console]::CapsLock` 是否为 `False`。
3. 核对 `config.toml` 中 `switch_language_shift = true` 且 `caps-ime.ahk` 内容与启动目录一致。

---

## 5. 修改配置后的验证步骤

1. 若修改了 `install.ps1`，执行语法检查：
   ```powershell
   $e=$null; $t=$null; [System.Management.Automation.Language.Parser]::ParseFile(".\install.ps1", [ref]$t, [ref]$e) | Out-Null; $e
   ```
2. 若修改了 `config.toml` 或 `caps-ime.ahk`，需同步更新 `metasequoiaime-setup\config\` 下对应文件，并确认 `diagnostic_log`、`tsf_diagnostic_log`、`candidate_window_diagnostic_log` 均为 `false`。
