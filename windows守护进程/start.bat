@echo off

set _task1=Dynaserver.exe
set _svr1=F:\SVG-Dynas\
set _des1=start1.bat
set _task2=DYNAS.exe
set _svr2=F:\SVG-Dynas\
set _des2=start2.bat

:checkserver
SET Dynaserver_status=1  
(TASKLIST|FIND /I "%_task1%"||SET Dynaserver_status=0) 2>nul 1>nul
IF %Dynaserver_status% EQU 1 (goto checksvr ) ELSE (goto startsvr)

:checkclient
SET Dynasclient_status=1 
(TASKLIST|FIND /I "%_task2%"||SET Dynasclient_status=0) 2>nul 1>nul
IF %Dynasclient_status% EQU 1 (goto checkcli ) ELSE (goto startcli)

:startsvr
echo %time% 
echo ********����˳���ʼ����********
echo ����˳������������� %date%%time% ,����ϵͳ��־ >> restart_service.txt
echo cd /d %_svr1% >> %_des1%
echo start %_task1% >> %_des1%
echo exit >> %_des1%
start %_des1%
set/p=.<nul
for /L %%i in (1 1 10) do set /p a=.<nul&ping.exe /n 2 127.0.0.1>nul
echo .
choice /t 10 /d y /n >nul 
del %_des1% /Q
echo ********�����������********
goto checkclient

:startcli
echo %time% 
echo ********�ͻ��˳���ʼ����********
echo �ͻ��˳������������� %date%%time% ,����ϵͳ��־ >> restart_client.txt
echo cd /d %_svr2% >> %_des2%
echo start %_task2% >> %_des2%
echo exit >> %_des2%
start %_des2%
set/p=.<nul
for /L %%i in (1 1 10) do set /p a=.<nul&ping.exe /n 2 127.0.0.1>nul
echo .
choice /t 10 /d y /n >nul 
del %_des2% /Q
echo ********�����������********
goto checkserver

:checksvr
echo %time% ����˳�����������,10���������.. 
choice /t 10 /d y /n >nul 
goto checkclient

:checkcli
echo %time% �ͻ��˳�����������,10���������.. 
choice /t 10 /d y /n >nul 
goto checkserver