#Requires -Version 5.1
<#
.SYNOPSIS
    水杉输入法（MetasequoiaIME v0.13.2）+ 自定义配置 + CapsLock 切换脚本 一键安装工具
#>

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ImeVersion = "v0.13.2"
$ImeDownloadUrl = "https://github.com/metasequoiaime/msime-windows/releases/download/v0.13.2/MetasequoiaIME_Setup_v0.13.2.exe"
$AhkDownloadUrl = "https://www.autohotkey.com/download/ahk-v2.exe"

$ImeServerPath = "C:\Program Files\metasequoiaime\server\MetasequoiaImeServer.exe"
$ImeWatchdogPath = "C:\Program Files\metasequoiaime\server\MetasequoiaImeWatchdog.exe"
$AhkExePath = "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"

$LocalDataDir = Join-Path $env:LOCALAPPDATA "metasequoiaime"
$StartupDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup"
$StartupAhkPath = Join-Path $StartupDir "Metasequoia Caps.ahk"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigSrcDir = Join-Path $ScriptDir "config"
$LocalInstallerDir = Join-Path $ScriptDir "installers"

function Write-Step($msg) {
    Write-Host "`n==> $msg" -ForegroundColor Cyan
}

function Find-LocalInstaller($pattern) {
    foreach ($dir in @($LocalInstallerDir, $ScriptDir)) {
        if (Test-Path $dir) {
            $found = Get-ChildItem -Path $dir -Filter $pattern -File -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) { return $found.FullName }
        }
    }
    return $null
}

function Download-File($url, $dest) {
    Write-Host "正在下载: $url" -ForegroundColor Gray
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
}

# 检查管理员权限
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "当前未以管理员身份运行，若需安装输入法或 AutoHotkey 可能失败。建议右键使用“一键安装.bat”运行。"
}

# 1. 安装水杉输入法
Write-Step "1/4 检查并安装水杉输入法 ($ImeVersion)"
if (Test-Path $ImeServerPath) {
    Write-Host "检测到已安装水杉输入法，跳过主程序安装。" -ForegroundColor Green
} else {
    $imeInstaller = Find-LocalInstaller "MetasequoiaIME_Setup*.exe"
    $tempIme = $false
    if (-not $imeInstaller) {
        $imeInstaller = Join-Path $env:TEMP "MetasequoiaIME_Setup_$ImeVersion.exe"
        Download-File $ImeDownloadUrl $imeInstaller
        $tempIme = $true
    } else {
        Write-Host "使用本地安装包: $imeInstaller" -ForegroundColor Green
    }

    Write-Host "正在静默安装水杉输入法，请稍候..." -ForegroundColor Yellow
    $proc = Start-Process -FilePath $imeInstaller -ArgumentList "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART" -Wait -PassThru
    if ($proc.ExitCode -ne 0) {
        throw "水杉输入法安装失败，退出码: $($proc.ExitCode)"
    }
    if ($tempIme -and (Test-Path $imeInstaller)) {
        Remove-Item $imeInstaller -Force -ErrorAction SilentlyContinue
    }
    Write-Host "水杉输入法安装完成。" -ForegroundColor Green
}

# 2. 安装 AutoHotkey v2
Write-Step "2/4 检查并安装 AutoHotkey v2"
if (Test-Path $AhkExePath) {
    Write-Host "检测到已安装 AutoHotkey v2，跳过安装。" -ForegroundColor Green
} else {
    $ahkInstaller = Find-LocalInstaller "AutoHotkey*.exe"
    if ($ahkInstaller) {
        Write-Host "使用本地安装包: $ahkInstaller" -ForegroundColor Green
        $proc = Start-Process -FilePath $ahkInstaller -ArgumentList "/silent" -Wait -PassThru
        if ($proc.ExitCode -ne 0) { throw "AutoHotkey 安装失败，退出码: $($proc.ExitCode)" }
    } elseif (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "正在通过 winget 安装 AutoHotkey v2..." -ForegroundColor Yellow
        winget install --id AutoHotkey.AutoHotkey -e --silent --accept-package-agreements --accept-source-agreements
    } else {
        $tempAhk = Join-Path $env:TEMP "ahk-v2-setup.exe"
        Download-File $AhkDownloadUrl $tempAhk
        $proc = Start-Process -FilePath $tempAhk -ArgumentList "/silent" -Wait -PassThru
        Remove-Item $tempAhk -Force -ErrorAction SilentlyContinue
        if ($proc.ExitCode -ne 0) { throw "AutoHotkey 安装失败，退出码: $($proc.ExitCode)" }
    }

    if (-not (Test-Path $AhkExePath)) {
        throw "未找到 $AhkExePath，请手动安装 AutoHotkey v2 后重试。"
    }
    Write-Host "AutoHotkey v2 安装完成。" -ForegroundColor Green
}

# 3. 部署配置文件、皮肤和 CapsLock 脚本
Write-Step "3/4 部署输入法配置、皮肤与 CapsLock 脚本"
if (-not (Test-Path $LocalDataDir)) {
    New-Item -ItemType Directory -Path $LocalDataDir -Force | Out-Null
}
$SkinsDestDir = Join-Path $LocalDataDir "skins"
if (-not (Test-Path $SkinsDestDir)) {
    New-Item -ItemType Directory -Path $SkinsDestDir -Force | Out-Null
}

$TargetConfig = Join-Path $LocalDataDir "config.toml"
if (Test-Path $TargetConfig) {
    $bakName = "config.toml.bak-" + (Get-Date -Format "yyyyMMdd-HHmmss")
    Copy-Item $TargetConfig (Join-Path $LocalDataDir $bakName) -Force
    Write-Host "已备份原有配置为: $bakName" -ForegroundColor Gray
}

Copy-Item (Join-Path $ConfigSrcDir "config.toml") $TargetConfig -Force
Copy-Item (Join-Path $ConfigSrcDir "caps-ime.ahk") (Join-Path $LocalDataDir "caps-ime.ahk") -Force
Copy-Item (Join-Path $ConfigSrcDir "caps-ime.ahk") $StartupAhkPath -Force

$SkinSrc = Join-Path $ConfigSrcDir "skins\bigfish-peek"
if (Test-Path $SkinSrc) {
    Copy-Item $SkinSrc $SkinsDestDir -Recurse -Force
}
Write-Host "配置、皮肤 (bigfish-peek) 与自启脚本已部署完成。" -ForegroundColor Green

# 4. 重启服务并启动 CapsLock 脚本
Write-Step "4/4 应用配置并启动服务"
Get-Process -Name "MetasequoiaImeServer" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 800
if (-not (Get-Process -Name "MetasequoiaImeServer" -ErrorAction SilentlyContinue)) {
    if (Test-Path $ImeWatchdogPath) {
        Start-Process -FilePath $ImeWatchdogPath
    } elseif (Test-Path $ImeServerPath) {
        Start-Process -FilePath $ImeServerPath
    }
}

Get-Process -Name "AutoHotkey64" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 300
Start-Process -FilePath $AhkExePath -ArgumentList "`"$StartupAhkPath`""

Write-Host "`n==========================================" -ForegroundColor Green
Write-Host " 全部安装与配置已完成！" -ForegroundColor Green
Write-Host " - CapsLock：切换中英文（英文默认小写，Shift+字母大写）" -ForegroundColor White
Write-Host " - 单独按 Shift：不会触发中英文切换" -ForegroundColor White
Write-Host " - 皮肤：bigfish-peek（深色主题，无悬浮工具栏）" -ForegroundColor White
Write-Host "==========================================" -ForegroundColor Green
