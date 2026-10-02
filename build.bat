@echo off
:: 双击运行：调用 build.py 打包 Windows 版本，完成后停留窗口查看结果
cd /d "%~dp0"
python build.py %*
pause
