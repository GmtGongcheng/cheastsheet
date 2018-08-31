@echo off

set _task=Dynaserver.exe
set _svr=E:\Dynas\Dynas.tcp\Release\
set _des=start1.bat

 :checkstart
SET status=1 
(TASKLIST|FIND /I "%_task%"||SET status=0) 2>nul 1>nul
ECHO %status%
IF %status% EQU 1 (goto checkag ) ELSE (goto startsvr)

:startsvr
echo %time% 
echo ********程序开始启动********
echo 程序重新启动于 %date%%time% ,请检查系统日志 >> restart_service.txt
echo cd /d %_svr% >> %_des%
echo start %_task% >> %_des%
echo exit >> %_des%
start %_des%
set/p=.<nul
for /L %%i in (1 1 10) do set /p a=.<nul&ping.exe /n 2 127.0.0.1>nul
echo .
choice /t 10 /d y /n >nul 
del %_des% /Q
echo ********程序启动完成********
goto checkstart

:checkag
echo %time% 程序运行正常,10秒后继续检查.. 
choice /t 10 /d y /n >nul 
goto checkstart