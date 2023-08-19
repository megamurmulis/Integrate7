@echo off
TITLE Download All Hotfixes
pause
:: ## MODS:
:: ## 1. pause
:: ## 2. Add echo filename
CLS

ECHO.
ECHO.
ECHO =========================================
ECHO Pre-downloading all Windows 7 Updates...
ECHO so they can be used later (offline)
ECHO =========================================
ECHO.

set "HostArchitecture=x86"
If exist "%WinDir%\SysWOW64" set "HostArchitecture=amd64"

cd /d "%~dp0hotfixes"

FOR /F "eol=; tokens=1,2*" %%i in (hfixes_all.txt) do if not exist "%~dp0hotfixes\%%i" echo Downloading: %%i & "%~dp0tools\%HostArchitecture%\wget.exe" -q --show-progress --no-hsts --no-check-certificate -O "%%i" "%%j"
FOR /F "eol=; tokens=1,2*" %%i in (ie11_all.txt)   do if not exist "%~dp0hotfixes\%%i" echo Downloading: %%i & "%~dp0tools\%HostArchitecture%\wget.exe" -q --show-progress --no-hsts --no-check-certificate -O "%%i" "%%j"
FOR /F "eol=; tokens=1,2*" %%i in (net4_all.txt)   do if not exist "%~dp0hotfixes\%%i" echo Downloading: %%i & "%~dp0tools\%HostArchitecture%\wget.exe" -q --show-progress --no-hsts --no-check-certificate -O "%%i" "%%j"
FOR /F "eol=; tokens=1,2*" %%i in (dx9.txt)        do if not exist "%~dp0hotfixes\%%i" echo Downloading: %%i & "%~dp0tools\%HostArchitecture%\wget.exe" -q --show-progress --no-hsts --no-check-certificate -O "%%i" "%%j"

ECHO.
ECHO.
ECHO.
ECHO All finished.
ECHO.
ECHO Press any key to end the script.
ECHO.
PAUSE >NUL


:end
