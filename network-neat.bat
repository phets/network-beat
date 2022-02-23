@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

:loop
SET hostName=%COMPUTERNAME%

:: Use WMIC to retrieve date and timestamp%
FOR /F "skip=1 tokens=1-6" %%G IN ('WMIC Path Win32_UTCTime Get Day^,Hour^,Minute^,Month^,Second^,Year /Format:table') DO (
  IF "%%~L"=="" goto s_done
    SET _yyyy=%%L
	SET _mm=00%%J
	SET _dd=00%%G
	SET _hour=00%%H
	SET _minute=00%%I
	SET _second=00%%K
)
:s_done

:: Pad digits with leading zeros
SET _mm=%_mm:~-2%
SET _dd=%_dd:~-2%
SET _hour=%_hour:~-2%
SET _minute=%_minute:~-2%
SET _second=%_second:~-2%

SET timestamp=%_yyyy%-%_mm%-%_dd%T%_hour%:%_minute%:%_second%Z

SET numLines=0
FOR /F "usebackq skip=3 tokens=1,2,4,5,6,7 delims= " %%F IN (`netsh interface show interface`) DO (
  SET /A numLines=!numLines!+1
  IF %%F==Enabled (SET networkEnabled[!numLines!]=1) ELSE (SET networkEnabled[!numLines!]=0)
  IF %%G==Connected (SET networkStatus[!numLines!]=1) ELSE (SET networkStatus[!numLines!]=0)
  SET networkName[!numLines!]=%%H%%I%%J%%K
)

SET postBody={\"@timestamp\":\"%timestamp%\",\"host.hostname\":\"%hostName%\",
FOR /L %%i in (1,1,%numLines%) DO (
  SET postBody[%%i]=!postBody!\"network.name\":\"!networkName[%%i]!\",\"network.enabled\":\"!networkEnabled[%%i]!\",\"network.status\":\"!networkStatus[%%i]!\"}

)

FOR /L %%i in (1,1,%numLines%) DO (
  ECHO !postBody[%%i]!
  curl -X POST -H "Content-type: application/json" --data !postBody[%%i]! http://rsimst:9200/network-status/_doc
)

timeout /t 15
goto loop
