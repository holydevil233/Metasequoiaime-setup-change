@echo off
chcp 65001 >nul
setlocal

:: 检查管理员权限，若无则自动提权
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo 正在请求管理员权限以安装水杉输入法及依赖...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo ==========================================
echo  水杉输入法 + 自定义配置 一键安装工具
echo ==========================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"

echo.
pause
