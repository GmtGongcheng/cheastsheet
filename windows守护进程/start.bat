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
echo ********����ʼ����********
echo �������������� %date%%time% ,����ϵͳ��־ >> restart_service.txt
echo cd /d %_svr% >> %_des%
echo start %_task% >> %_des%
echo exit >> %_des%
start %_des%
set/p=.<nul
for /L %%i in (1 1 10) do set /p a=.<nul&ping.exe /n 2 127.0.0.1>nul
echo .
choice /t 10 /d y /n >nul 
del %_des% /Q
echo ********�����������********
goto checkstart

:checkag
echo %time% ������������,10���������.. 
choice /t 10 /d y /n >nul 
goto checkstart