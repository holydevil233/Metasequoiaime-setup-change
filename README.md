# 水杉输入法（MetasequoiaIME）一键安装与配置包

将整个 `metasequoiaime-setup` 文件夹复制到目标 Windows 10/11 电脑上，双击运行 **`一键安装.bat`** 即可。

## 包含内容
- **自动安装主程序**：检测并静默安装水杉输入法 `v0.13.2` 与 `AutoHotkey v2`（已安装则自动跳过）。
- **个性化配置**（`config\config.toml`）：
  - 主题：`dark`（深色模式）
  - 候选框皮肤：`bigfish-peek`（大肥鱼·探头，已附带皮肤资源 `config\skins\bigfish-peek`）
  - 悬浮工具栏：关闭（`floating_toolbar = false`）
- **CapsLock 独立切换中英文**（`config\caps-ime.ahk`）：
  - `CapsLock`：切换中英文，且保持系统大写锁定始终关闭（英文默认小写，`Shift + 字母` 为大写）。
  - 单独按物理 `Shift`：不会触发中英文切换。
  - 自动加入开机启动（`%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Metasequoia Caps.ahk`）。

## 离线安装（可选）
如果目标设备没有网络，可提前下载以下安装包放到本目录的 `installers\` 文件夹下，脚本会自动优先使用本地安装包：
- `MetasequoiaIME_Setup_v0.13.2.exe`
- `AutoHotkey_2.x_setup.exe`
