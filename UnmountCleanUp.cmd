@echo off
TITLE Windows 7 Integrator Clean up script
pause
:: ## MODS:
:: ## 1. pause
CLS

::
:: This script is only needed if execution of Integrate7 gets interrupted,
:: leaving garbage behind.
::
:: Orherwise, It has no effect because normally Integrate7 has built in clean up.
::

REM Check admin rights
fsutil dirty query %systemdrive% >nul 2>&1
if ERRORLEVEL 1 (
 ECHO.
 ECHO.
 ECHO ===================================================================
 ECHO The script needs Administrator permissions!
 ECHO.
 ECHO Please run it as the Administrator or disable User Account Control.
 ECHO ===================================================================
 ECHO.
 PAUSE >NUL
 goto end
)

REM Check parenthesis in script PATH, which brakes subsequent for loops
set incorrectPath=0

echo "%~dp0" | findstr /l /c:"(" >nul 2>&1 && set incorrectPath=1
echo "%~dp0" | findstr /l /c:")" >nul 2>&1 && set incorrectPath=1

if not "%incorrectPath%"=="0" (
 ECHO.
 ECHO.
 ECHO ================================================================
 ECHO Script cannot be run from this location!
 ECHO Current location contatins parenthesis in the PATH.
 ECHO.
 ECHO Please copy and run script from Desktop or another directory!
 ECHO ================================================================
 ECHO.
 PAUSE >NUL
 goto end
)


set "HostArchitecture=x86"
If exist "%WinDir%\SysWOW64" set "HostArchitecture=amd64"

set "PF=%ProgramFiles%"
if not "%ProgramFiles(x86)%"=="" set "PF=%ProgramFiles(x86)%"


ECHO.
ECHO.
ECHO ================================================================
ECHO Unmounting mounted registry keys...
ECHO ================================================================
ECHO.


reg unload HKLM\TK_DEFAULT >nul 2>&1
reg unload HKLM\TK_NTUSER >nul 2>&1
reg unload HKLM\TK_SOFTWARE >nul 2>&1
reg unload HKLM\TK_SYSTEM >nul 2>&1
reg unload HKLM\TK_COMPONENTS >nul 2>&1

ECHO.
ECHO Done!
ECHO.

ECHO.
ECHO.
ECHO ================================================================
ECHO Unmounting mounted images...
ECHO ================================================================
ECHO.


for /L %%i in (1, 1, 10) do (
 if exist "%~dp0mount\%%i\Windows\explorer.exe" (
  "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Unmount-Wim /MountDir:"%~dp0mount\%%i" /Discard
 )
)

if exist "%~dp0mount\Boot\Windows\regedit.exe" (
 "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Unmount-Wim /MountDir:"%~dp0mount\Boot" /Discard
)

if exist "%~dp0Win10_Installer\mount\Windows\explorer.exe" (
 "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Unmount-Wim /MountDir:"%~dp0Win10_Installer\mount" /Discard
)

rd /s /q "%~dp0mount" >nul 2>&1
rd /s /q "%~dp0Win10_Installer\mount" >nul 2>&1
mkdir "%~dp0mount" >nul 2>&1
rd /s /q "%~dp0hotfixes\unpacked" >nul 2>&1

"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Cleanup-Mountpoints

ECHO.
ECHO.
ECHO All done!
ECHO.

ECHO.
ECHO Press any key to end the script.
ECHO.

PAUSE >NUL

:end
