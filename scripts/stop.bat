@echo off
taskkill /FI "WINDOWTITLE eq QimingHat*" /T /F >nul 2>&1
echo 已发送停止请求；如服务由终端启动，请在该终端按 Ctrl+C。
