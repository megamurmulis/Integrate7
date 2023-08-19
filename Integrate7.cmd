@echo off
TITLE Windows 7 Integrator
CLS

::
:: Author: Wojciech Keller
:: Version: 5.24
:: License: free
::

:: ============================================================================================================
:: -------------- Start of Configuration Section --------------------------------------------------------------
:: ============================================================================================================

:: Download and integrate all post-SP1 updates up to August 2023
 set InstallHotfixes=1

:: Additional updates, installed silently after Windows Setup Ends
::
  :: - Silently install NET Framework 4.8
   set IncludeNET4=1
  :: - Execute queued NET compilations (takes some extra time after setup, but then Windows works faster)
   set ExecuteNGEN=0
  :: - Silently install DirectX 9 June 2010
   set IncludeDX9=1



:: Apply custom patches (from corresponding section below)
:: and integrate files from folder add_these_files_to_Windows\(x86 or x64)
 set ApplyCustPatches=1

  :: Custom Patches sub-sections:
  :: - Set default NTP time server instead of time.windows.com
   set NTPserver=pool.ntp.org
  :: - Disable time sync service entirely, regardless of the setting above.
  ::   It is recommended to disable it when you want to set your date/time manually or using third party TimeSync software.
   set DisableTimeSync=0
  :: - Disable automatic Internet Connection Checking
  ::   Otherwise Windows connects to http://www.msftconnecttest.com/connecttest.txt to check Internet connection
   set DisableInternetConnectionChecking=1
  :: - Disable search indexing.
  ::   It is recommended to disable it on systems installed on hard drives or other low resource computers.
   set DisableSearchIndexing=1
  :: - Remove System Restore
   set RemoveSR=1
  :: - Remove Windows Defender
   set RemoveDefender=1
  :: - Disable obsolete SMBv1 protocol (not needed unless you share disks and printers with Widows XP or older)
   set DisableSMBv1=1
  :: - Disable obsolete LLNR protocol (introduced in Vista, removed in W10, was used as naming service on LANs)
   set DisableLLNR=1
  :: - Disable automatic update of root certificates that are used for encrypted connections.
  ::   ExtraScripts\Security\UpdateRootCerts.cmd script can be used to update certificates manually
   set DisableRootCertUpdate=0
  :: - Disable All Event Logs (sometimes causes problems with Microsoft SQL or similar software)
   set DisableEventLogs=0
  :: - Disable ciphering protocols older than TLS 1.2 (improves security but could cause problems with some web sites and services)
   set DisableObsoleteSSL=0
  :: - 1 = Disable AutoPlay for all devices inlcuding CD/DVD media
  :: - 0 = Enable autoplay for CD/DVD media only, but disable for the rest for security.
  ::       AutoPlay has been one of the main sources of spreading of viruses in the past.
   set DisableCDAutoPlay=1
  ::  - Disable Prefetch and Superfetch 
  ::    May be useful for fast SSD drives or for systems with low RAM memory.
   set DisablePrefetcher=0
  ::  - Use NVMe driver backported from Win8 instead of standard Microsoft KB2990941 update.
  ::    You can try to switch on this option if NVMe doesn't work for you.
   set UseBackportedNVMe=0
  :: - Removes legacy VGA video driver, which is recommended for UEFI class 3 firmare
  ::   You MUST! provide vendor Video Card driver when legacy VGA is removed
   set RemoveLegacyVGA=0



:: Integrate drivers:
::  - from add_these_drivers_to_Installer\(x86 or x64) to boot.wim
::  - from add_these_drivers_to_Windows\(x86 or x64) to install.wim
::  - from add_these_drivers_to_Recovery\(x86 or x64) to winRE.wim (inside install.wim)
 set AddDrivers=1


:: Cleanup Images (redundant unless you manualy slipstreamed Service Pack 1)
 set CleanupImages=0


:: Repack/recompress boot.wim and install.wim to save some space
 set RepackImages=1

:: Split install.wim if its size exceed 4 GB
 set SplitInstallWim=1

:: Create ISO image or leave installer files in DVD folder
 set CreateISO=1


:: ============================================================================================================
:: ------------- End of Configuration Section -----------------------------------------------------------------
:: ============================================================================================================



:: ============================================================================================================


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
 ECHO The script cannot be run from this location!
 ECHO Current location contatins parenthesis in the PATH.
 ECHO.
 ECHO Please copy and run script from Desktop or another directory!
 ECHO ================================================================
 ECHO.
 PAUSE >NUL
 goto end
)


set MountRequired=0
if not "%InstallHotfixes%"=="0" set MountRequired=1
if not "%ApplyCustPatches%"=="0" set MountRequired=1
if not "%AddDrivers%"=="0" set MountRequired=1
if not "%CleanupImages%"=="0" set MountRequired=1


set "HostArchitecture=x86"
If exist "%WinDir%\SysWOW64" set "HostArchitecture=amd64"


set Win10ISOName=
set Win10ImageArchitecture=
for /f "delims=" %%i in ('dir /b "%~dp0Win*10*.iso" 2^>nul') do (set "Win10ISOName=%%i")

set ISOName=
for /f "delims=" %%i in ('dir /b "%~dp0*.iso" 2^>nul') do (
 if not "%%i"=="%Win10ISOName%" (
  echo %%i 2>nul | findstr /r /c:"^Windows7_x[86][46]_[a-zA-Z][a-zA-Z]-[a-zA-Z][a-zA-Z]*\.iso" >nul 2>&1 || set "ISOName=%%i"
 )
)


if "%ISOName%"=="" (
 if not exist "%~dp0DVD\sources\install.wim" (
  ECHO.
  ECHO.
  ECHO ================================================================
  ECHO ISO/DVD File not found in main script directory!
  ECHO.
  ECHO Please copy Windows 7 ISO DVD to the same location as Integrate7
  ECHO ================================================================
  ECHO.
  PAUSE >NUL
  goto end
 )
)


if not "%ISOName%"=="" (
 ECHO.
 ECHO.
 ECHO ===============================================================================
 ECHO Unpacking ISO/DVD image: "%ISOName%" to DVD directory...
 ECHO ===============================================================================
 ECHO.

 rd /s /q "%~dp0DVD" >nul 2>&1
 mkdir "%~dp0DVD" >nul 2>&1

 "%~dp0tools\%HostArchitecture%\7z.exe" x -y -o"%~dp0DVD" "%~dp0%ISOName%"
)


if not exist "%~dp0DVD\sources\install.wim" (
 ECHO.
 ECHO.
 ECHO ================================================================
 ECHO Install.wim not found inside DVD source image!
 ECHO ================================================================
 ECHO.
 PAUSE >NUL
 goto end
)

if not exist "%~dp0DVD\sources\boot.wim" (
 ECHO.
 ECHO.
 ECHO ================================================================
 ECHO Boot.wim not found inside DVD source image!
 ECHO ================================================================
 ECHO.
 PAUSE >NUL
 goto end
)



set ImageStart=1
REM Number of Windows 7 editions inside ISO image
for /f "tokens=2 delims=: " %%i in ('start "" /b "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /English /Get-WimInfo /WimFile:"%~dp0DVD\sources\install.wim" ^| findstr /l /i /c:"Index"') do (set ImageCount=%%i)


REM CPU architecture of Windows 7 ISO
for /f "tokens=2 delims=: " %%a in ('start "" /b "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /English /Get-WimInfo /WimFile:"%~dp0DVD\sources\install.wim" /Index:%ImageStart% ^| findstr /l /i /c:"Architecture"') do (set ImageArchitecture=%%a)
set PackagesArchitecture=amd64
if "%ImageArchitecture%"=="x86" set PackagesArchitecture=x86

REM Language of Windows 7 ISO
for /f "tokens=1 delims= " %%a in ('start "" /b "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /English /Get-WimInfo /WimFile:"%~dp0DVD\sources\install.wim" /Index:%ImageStart% ^| findstr /l /i /c:"(Default)"') do (set ImageLanguage=%%a)
for /f "tokens=1 delims= " %%a in ('echo %ImageLanguage%') do (set ImageLanguage=%%a)

REM Check Windows images
set checkErrors=0
for /L %%i in (%ImageStart%, 1, %ImageCount%) do (
 "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /English /Get-WimInfo /WimFile:"%~dp0DVD\sources\install.wim" /Index:%%i | findstr /l /i /c:"Architecture" | findstr /l /i /c:"%ImageArchitecture%" >nul 2>&1
 if ERRORLEVEL 1 set checkErrors=1
 "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /English /Get-WimInfo /WimFile:"%~dp0DVD\sources\install.wim" /Index:%%i | find /i "Name :" | find /i "Windows 7" >nul 2>&1
 if ERRORLEVEL 1 set checkErrors=1
 "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /English /Get-WimInfo /WimFile:"%~dp0DVD\sources\install.wim" /Index:%%i | findstr /l /i /c:"(Default)" | findstr /l /i /c:"%ImageLanguage%" >nul 2>&1
 if ERRORLEVEL 1 set checkErrors=1
)

if not "%checkErrors%"=="0" (
 ECHO.
 ECHO.
 ECHO ================================================================
 ECHO This script supports only original Windows 7 images!
 ECHO.
 ECHO Mixed images with multiple OSes, multiple langauges
 ECHO or multiple architectures are not supported!
 ECHO ================================================================
 ECHO.
 PAUSE >NUL
 goto end
)


REM Set ESU variables for Win7 Embedded
set "EsuCom=amd64_microsoft-windows-s..edsecurityupdatesai_31bf3856ad364e35_6.3.9603.30600_none_6022b34506a8b67a"
set "EsuIdn=4D6963726F736F66742D57696E646F77732D534C432D436F6D706F6E656E742D457874656E64656453656375726974795570646174657341492C2043756C747572653D6E65757472616C2C2056657273696F6E3D362E332E393630332E33303630302C205075626C69634B6579546F6B656E3D333162663338353661643336346533352C2050726F636573736F724172636869746563747572653D616D6436342C2076657273696F6E53636F70653D4E6F6E537853"
set "EsuHsh=423FEE4BEB5BCA64D89C7BCF0A69F494288B9A2D947C76A99C369A378B79D411"
set "EsuFnd=windowsfoundation_31bf3856ad364e35_6.1.7601.17514_615fdfe2a739474c"
set "EsuKey=amd64_microsoft-windows-s..edsecurityupdatesai_31bf3856ad364e35_none_0e8b36cfce2fb332"
if "%ImageArchitecture%"=="x86" (
 set "EsuCom=x86_microsoft-windows-s..edsecurityupdatesai_31bf3856ad364e35_6.3.9603.30600_none_040417c14e4b4544"
 set "EsuIdn=4D6963726F736F66742D57696E646F77732D534C432D436F6D706F6E656E742D457874656E64656453656375726974795570646174657341492C2043756C747572653D6E65757472616C2C2056657273696F6E3D362E332E393630332E33303630302C205075626C69634B6579546F6B656E3D333162663338353661643336346533352C2050726F636573736F724172636869746563747572653D7838362C2076657273696F6E53636F70653D4E6F6E537853"
 set "EsuHsh=70FC6E62A198F5D98FDDE11A6E8D6C885E17C53FCFE1D927496351EADEB78E42"
 set "EsuFnd=windowsfoundation_31bf3856ad364e35_6.1.7601.17514_0541445eeedbd616"
 set "EsuKey=x86_microsoft-windows-s..edsecurityupdatesai_31bf3856ad364e35_none_b26c9b4c15d241fc"
)


setlocal EnableDelayedExpansion
ECHO.
ECHO.
ECHO ================================================================
ECHO Found the following images in ISO/DVD:
ECHO.
set ImageIndexes=
for /L %%i in (%ImageStart%, 1, %ImageCount%) do (
 set "ImageIndexes=!ImageIndexes!%%i"
 ECHO.
 ECHO Index: %%i
 "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /English /Get-WimInfo /WimFile:"%~dp0DVD\sources\install.wim" /Index:%%i | find /i "Name :"
 ECHO Architecture: %ImageArchitecture%
 ECHO Language: %ImageLanguage%
)
ECHO.
ECHO ================================================================
ECHO.
setlocal DisableDelayedExpansion


if "%ImageStart%"=="%ImageCount%" goto skipSelectImage

CHOICE /C %ImageIndexes% /M "Choose image index"
set ImageIndex=%ERRORLEVEL%

if not "%ImageStart%"=="%ImageCount%" (
 ECHO.
 ECHO.
 "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Export-Image /SourceImageFile:"%~dp0DVD\sources\install.wim" /SourceIndex:%ImageIndex% /DestinationImageFile:"%~dp0DVD\sources\install_index_%ImageIndex%.wim" /CheckIntegrity
 move /y "%~dp0DVD\sources\install_index_%ImageIndex%.wim" "%~dp0DVD\sources\install.wim" >nul 2>&1
 ECHO.
 SET ImageStart=1
 SET ImageCount=1
)


:skipSelectImage


if not "%Win10ISOName%"=="" (
 ECHO.
 ECHO.
 ECHO ================================================================
 ECHO Found Windows 10 ISO image!
 ECHO.
 ECHO Name: "%Win10ISOName%"
 ECHO ================================================================
 
 ECHO.
 ECHO Unpacking installer files to "Win10_Installer" directory....
 ECHO.

 rd /s /q "%~dp0Win10_Installer" >nul 2>&1
 mkdir "%~dp0Win10_Installer" >nul 2>&1
 mkdir "%~dp0Win10_Installer\DVD" >nul 2>&1
 mkdir "%~dp0Win10_Installer\EFI_Boot" >nul 2>&1
 mkdir "%~dp0Win10_Installer\mount" >nul 2>&1
 "%~dp0tools\%HostArchitecture%\7z.exe" x -y -o"%~dp0Win10_Installer\DVD" "%~dp0%Win10ISOName%"
 "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Mount-Wim /WimFile:"%~dp0Win10_Installer\DVD\sources\install.wim" /index:1 /MountDir:"%~dp0Win10_Installer\mount"
 xcopy "%~dp0Win10_Installer\mount\Windows\Boot\*" "%~dp0Win10_Installer\EFI_Boot\" /e /s /y >nul 2>&1
 "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Unmount-Wim /MountDir:"%~dp0Win10_Installer\mount" /discard
 del /q /f "%~dp0Win10_Installer\EFI_Boot\*.ini"  >nul 2>&1
 rd /s /q "%~dp0Win10_Installer\mount" >nul 2>&1
 del /q /f "%~dp0Win10_Installer\DVD\sources\install.wim" >nul 2>&1
 del /q /f "%~dp0Win10_Installer\DVD\sources\install*.swm" >nul 2>&1
 
 ECHO.
 ECHO.
 ECHO Done.
 ECHO.
)


if exist "%~dp0Win10_Installer\DVD\sources\boot.wim" (
 for /f "tokens=2 delims=: " %%a in ('start "" /b "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /English /Get-WimInfo /WimFile:"%~dp0Win10_Installer\DVD\sources\boot.wim" /Index:1 ^| findstr /l /i /c:"Architecture"') do (set Win10ImageArchitecture=%%a)
)

if "%Win10ImageArchitecture%"=="%ImageArchitecture%" (

 ECHO.
 ECHO Replacing Windows 7 installer with Windows 10 installer...
 ECHO.

 move /y "%~dp0DVD\sources\install.wim" "%~dp0Win10_Installer" >nul 2>&1
 rd /s /q "%~dp0DVD" >nul 2>&1
 xcopy "%~dp0Win10_Installer\DVD\*" "%~dp0DVD\" /e /s /y >nul 2>&1
 move /y "%~dp0Win10_Installer\install.wim" "%~dp0DVD\sources" >nul 2>&1
 ECHO.
 ECHO Done.
 ECHO.

)

del /q /f "%~dp0DVD\sources\ei.cfg" >nul 2>&1

xcopy "%~dp0ExtraScripts\*" "%~dp0DVD\ExtraScripts\" /e /s /y >nul 2>&1


if "%MountRequired%"=="0" goto skipMount

 
ECHO.
ECHO.
ECHO ================================================================
ECHO Mounting install.wim
ECHO Mount directory: %~dp0mount\1
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /English /Get-WimInfo /WimFile:"%~dp0DVD\sources\install.wim" /Index:1 | find /i "Name :"
ECHO ================================================================
ECHO.

rd /s/q "%~dp0mount\1" >NUL 2>&1
mkdir "%~dp0mount\1" >NUL 2>&1
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Mount-Wim /WimFile:"%~dp0DVD\sources\install.wim" /index:1 /MountDir:"%~dp0mount\1"


if "%InstallHotfixes%"=="0" goto skipHotfixes


ECHO.
ECHO.
ECHO ================================================================
ECHO Downloading missing Windows 7 Updates...
ECHO ================================================================
ECHO.


type "%~dp0hotfixes\hfixes_all.txt" | find /i "%ImageArchitecture%" > "%~dp0hotfixes\hfixes_%ImageArchitecture%.txt"
type "%~dp0hotfixes\ie11_all.txt" | find /i "%ImageArchitecture%" | find /i "%ImageLanguage%" > "%~dp0hotfixes\ie11_%ImageArchitecture%_%ImageLanguage%.txt"

if not "%IncludeNET4%"=="0" (
 REM NET 4 Main Installer
 type "%~dp0hotfixes\net4_all.txt" | findstr /l /i /c:"\-ENU." > "%~dp0hotfixes\net4_main.txt"
 REM NET 4 Language Pack
 type "%~dp0hotfixes\net4_all.txt" | findstr /l /i /c:"%ImageLanguage%" > "%~dp0hotfixes\net4_langpack_%ImageLanguage%.txt"
 REM NET 4 Updates
 type "%~dp0hotfixes\net4_all.txt" | findstr /l /i /c:"\-%ImageArchitecture%." > "%~dp0hotfixes\net4_hfixes_%ImageArchitecture%.txt"
)



cd /d "%~dp0hotfixes"

FOR /F "eol=; tokens=1,2*" %%i in (hfixes_%ImageArchitecture%.txt) do if not exist "%~dp0hotfixes\%%i" "%~dp0tools\%HostArchitecture%\wget.exe" -q --show-progress --no-hsts --no-check-certificate -O "%%i" "%%j"
FOR /F "eol=; tokens=1,2*" %%i in (ie11_%ImageArchitecture%_%ImageLanguage%.txt) do if not exist "%~dp0hotfixes\%%i" "%~dp0tools\%HostArchitecture%\wget.exe" -q --show-progress --no-hsts --no-check-certificate -O "%%i" "%%j"

if not "%IncludeNET4%"=="0" (
 REM NET 4 Main Installer
 FOR /F "eol=; tokens=1,2*" %%i in (net4_main.txt) do if not exist "%~dp0hotfixes\%%i" "%~dp0tools\%HostArchitecture%\wget.exe" -q --show-progress --no-hsts --no-check-certificate -O "%%i" "%%j"
 REM NET 4 Language Pack
 set Net4LangPackFile=
 FOR /F "eol=; tokens=1,2*" %%i in (net4_langpack_%ImageLanguage%.txt) do (
  if not exist "%~dp0hotfixes\%%i" "%~dp0tools\%HostArchitecture%\wget.exe" -q --show-progress --no-hsts --no-check-certificate -O "%%i" "%%j"
  set "Net4LangPackFile=%%i"
 )
 REM NET 4 Updates
 FOR /F "eol=; tokens=1,2*" %%i in (net4_hfixes_%ImageArchitecture%.txt) do if not exist "%~dp0hotfixes\%%i" "%~dp0tools\%HostArchitecture%\wget.exe" -q --show-progress --no-hsts --no-check-certificate -O "%%i" "%%j"
)

if not "%IncludeDX9%"=="0" FOR /F "eol=; tokens=1,2*" %%i in (dx9.txt) do if not exist "%~dp0hotfixes\%%i" "%~dp0tools\%HostArchitecture%\wget.exe" -q --show-progress --no-hsts --no-check-certificate -O "%%i" "%%j"


REM Restore Title Bar changed by wget
TITLE Windows 7 Integrator

cd /d "%~dp0"

del /q /f "%~dp0hotfixes\hfixes_%ImageArchitecture%.txt" >nul 2>&1
del /q /f "%~dp0hotfixes\ie11_%ImageArchitecture%_%ImageLanguage%.txt" >nul 2>&1

if not "%IncludeNET4%"=="0" (
 del /q /f "%~dp0hotfixes\net4_main.txt" >nul 2>&1
 del /q /f "%~dp0hotfixes\net4_langpack_%ImageLanguage%.txt" >nul 2>&1
 del /q /f "%~dp0hotfixes\net4_hfixes_%ImageArchitecture%.txt" >nul 2>&1
)


ECHO.
ECHO Done.
ECHO.



set SetupCompleteCMD=
if not "%IncludeNET4%"=="0" set SetupCompleteCMD=1
if not "%IncludeDX9%"=="0" set SetupCompleteCMD=1

mkdir "%~dp0DVD\sources\$oem$\$$\Setup\Scripts" >nul 2>&1
echo @ECHO OFF>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
REM Re-apply disable NTFS last access time update
echo fsutil behavior set disableLastAccess ^1 ^>nul 2^>^&^1>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
REM Unlimited max password age
echo net accounts /maxpwage:unlimited ^>nul 2^>^&^1>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
REM Re-apply disable hibernation
echo powercfg -h off ^>nul 2^>^&^1>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
REM Re-apply disable screen off timer
echo powercfg -SETACVALUEINDEX 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 7516b95f-f776-4464-8c53-06167f40cc99 3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e 0 ^>nul 2^>^&^1>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
echo powercfg -SETACVALUEINDEX 381b4222-f694-41f0-9685-ff5bb260df2e 7516b95f-f776-4464-8c53-06167f40cc99 3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e 0 ^>nul 2^>^&^1>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
REM Re-apply disable USB AutoSuspend
echo powercfg -SETDCVALUEINDEX 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 ^>nul 2^>^&^1>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
echo powercfg -SETACVALUEINDEX 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 ^>nul 2^>^&^1>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
echo powercfg -SETDCVALUEINDEX 381b4222-f694-41f0-9685-ff5bb260df2e 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 ^>nul 2^>^&^1>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
echo powercfg -SETACVALUEINDEX 381b4222-f694-41f0-9685-ff5bb260df2e 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 ^>nul 2^>^&^1>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
REM Re-apply disable idle Hard Disk auto power off
echo powercfg -SETDCVALUEINDEX 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 0012ee47-9041-4b5d-9b77-535fba8b1442 6738e2c4-e8a5-4a42-b16a-e040e769756e 0 ^>nul 2^>^&^1>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
echo powercfg -SETACVALUEINDEX 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 0012ee47-9041-4b5d-9b77-535fba8b1442 6738e2c4-e8a5-4a42-b16a-e040e769756e 0 ^>nul 2^>^&^1>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
echo powercfg -SETDCVALUEINDEX 381b4222-f694-41f0-9685-ff5bb260df2e 0012ee47-9041-4b5d-9b77-535fba8b1442 6738e2c4-e8a5-4a42-b16a-e040e769756e 0 ^>nul 2^>^&^1>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
echo powercfg -SETACVALUEINDEX 381b4222-f694-41f0-9685-ff5bb260df2e 0012ee47-9041-4b5d-9b77-535fba8b1442 6738e2c4-e8a5-4a42-b16a-e040e769756e 0 ^>nul 2^>^&^1>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
if exist "%~dp0hotfixes\AuthRoot.p7b" (
 copy /b /y "%~dp0hotfixes\AuthRoot.p7b" "%~dp0mount\1\Windows" >nul 2>&1
 echo certutil -addstore -f authroot "%%windir%%\AuthRoot.p7b" ^>nul 2^>^&^1>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 echo del /q /f "%%windir%%\AuthRoot.p7b" ^>nul 2^>^&^1>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
)
REM Workaround for Old Games Not Launching and Eating 100% CPU
echo reg add "HKCR\Local Settings\Software\Microsoft\Windows\GameUX\ServiceLocation" /v "Games" /t REG_SZ /d "0.0.0.0" /f ^>nul 2^>^&^1>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
echo start /w "" regsvr32 /u /s "%%windir%%\System32\gameux.dll">>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
if "%ImageArchitecture%"=="x64" echo start /w "" regsvr32 /u /s "%%windir%%\SysWOW64\gameux.dll">>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"

if not "%SetupCompleteCMD%"=="1" goto skipSetupCompleteCMD
 mkdir "%~dp0DVD\Updates" >nul 2>&1
 echo FOR %%%%I IN (C D E F G H I J K L M N O P Q R S T U V W X Y Z) DO IF EXIST "%%%%I:\Updates\ndp48-x86-x64-allos-enu.exe" SET CDROM=%%%%I:>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 echo if "%%CDROM%%"=="" goto end>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
:skipSetupCompleteCMD

if "%IncludeNET4%"=="0" goto skipNET4setup
 ECHO.
 ECHO.
 ECHO ================================================================
 ECHO Adding NET Framework 4.8 to ISO/DVD....
 ECHO ================================================================
 ECHO.
 ECHO.
 copy /b /y "%~dp0hotfixes\ndp48-x86-x64-allos-enu.exe" "%~dp0DVD\Updates" >nul 2>&1
 copy /b /y "%~dp0hotfixes\ndp48-kb5020879-%ImageArchitecture%.exe" "%~dp0DVD\Updates" >nul 2>&1
 copy /b /y "%~dp0hotfixes\ndp48-kb5028958-%ImageArchitecture%.exe" "%~dp0DVD\Updates" >nul 2>&1
 echo echo Installing NET Framework 4.8...>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 echo start /w "" "%%CDROM%%\Updates\ndp48-x86-x64-allos-enu.exe" /q /norestart>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 if not "%Net4LangPackFile%"=="" (
  copy /b /y "%~dp0hotfixes\%Net4LangPackFile%" "%~dp0DVD\Updates" >nul 2>&1
  echo echo Installing NET Framework Language Pack...>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
  echo start /w "" "%%CDROM%%\Updates\%Net4LangPackFile%" /q /norestart>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 )
 copy /b /y "%~dp0hotfixes\msiesu32.dll" "%~dp0DVD\Updates" >nul 2>&1
 if "%ImageArchitecture%"=="x64" copy /b /y "%~dp0hotfixes\msiesu64.dll" "%~dp0DVD\Updates" >nul 2>&1
 echo echo Installing NET Framework Rollup Update...>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 if "%ImageArchitecture%"=="x86" (
  echo copy /b /y "%%CDROM%%\Updates\msiesu32.dll" "%%SystemRoot%%\System32\msiesu.dll" ^>nul 2^>^&^1>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 )
 if "%ImageArchitecture%"=="x64" (
  echo copy /b /y "%%CDROM%%\Updates\msiesu32.dll" "%%SystemRoot%%\SysWOW64\msiesu.dll" ^>nul 2^>^&^1>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
  echo copy /b /y "%%CDROM%%\Updates\msiesu64.dll" "%%SystemRoot%%\System32\msiesu.dll" ^>nul 2^>^&^1>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 )
 echo reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\msiexec.exe" /f ^>nul 2^>^&^1>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 echo reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\msiexec.exe" /v VerifierDlls /t REG_SZ /d msiesu.dll /f ^>nul>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 echo reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\msiexec.exe" /v GlobalFlag /t REG_DWORD /d 256 /f ^>nul>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 echo net stop msiserver ^>nul 2^>^&^1>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 echo start /w "" "%%CDROM%%\Updates\ndp48-kb5020879-%ImageArchitecture%.exe" /q /norestart>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 echo start /w "" "%%CDROM%%\Updates\ndp48-kb5028958-%ImageArchitecture%.exe" /q /norestart>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 echo reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\msiexec.exe" /f ^>nul 2^>^&^1>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 if "%ImageArchitecture%"=="x86" (
  echo del /q /f "%%SystemRoot%%\System32\msiesu.dll" ^>nul 2^>^&^1>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 )
 if "%ImageArchitecture%"=="x64" (
  echo del /q /f "%%SystemRoot%%\SysWOW64\msiesu.dll" ^>nul 2^>^&^1>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
  echo del /q /f "%%SystemRoot%%\System32\msiesu.dll" ^>nul 2^>^&^1>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 )
 echo net stop msiserver ^>nul 2^>^&^1>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"

if "%ExecuteNGEN%"=="0" goto skipNGEN
 echo echo Executing Queued NET Compilations...>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 echo if not exist "%%windir%%\Microsoft.NET\Framework\v2.0.50727\ngen.exe" goto noNET20x86>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 echo "%%windir%%\Microsoft.NET\Framework\v2.0.50727\ngen.exe" executeQueuedItems ^>NUL 2^>NUL>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 echo :noNET20x86>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 echo if not exist "%%windir%%\Microsoft.NET\Framework64\v2.0.50727\ngen.exe" goto noNET20x64>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 echo "%%windir%%\Microsoft.NET\Framework64\v2.0.50727\ngen.exe" executeQueuedItems ^>NUL 2^>NUL>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 echo :noNET20x64>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 echo if not exist "%%windir%%\Microsoft.NET\Framework\v4.0.30319\ngen.exe" goto noNET40x86>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 echo "%%windir%%\Microsoft.NET\Framework\v4.0.30319\ngen.exe" executeQueuedItems ^>NUL 2^>NUL>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 echo :noNET40x86>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 echo if not exist "%%windir%%\Microsoft.NET\Framework64\v4.0.30319\ngen.exe" goto noNET40x64>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 echo "%%windir%%\Microsoft.NET\Framework64\v4.0.30319\ngen.exe" executeQueuedItems ^>NUL 2^>NUL>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 echo :noNET40x64>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
:skipNGEN

 ECHO.
 ECHO Done.
 ECHO.
:skipNET4setup

if "%IncludeDX9%"=="0" goto skipDX9setup
 ECHO.
 ECHO.
 ECHO ================================================================
 ECHO Adding DirectX 9 June 2010 to ISO/DVD....
 ECHO ================================================================
 ECHO.
 ECHO.
 start /w "" "%~dp0hotfixes\directx_Jun2010_redist.exe" /t:"%~dp0DVD\Updates\DX9" /c /q
 echo echo Installing DirectX 9 June 2010...>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 echo start /w "" "%%CDROM%%\Updates\DX9\DXSETUP.exe" /silent>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
 ECHO.
 ECHO Done.
 ECHO.
:skipDX9setup


echo :end>>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"
echo rd /S /Q "%%WINDIR%%\Setup\Scripts">>"%~dp0DVD\sources\$oem$\$$\Setup\Scripts\SetupComplete.cmd"


ECHO.
ECHO.
ECHO ================================================================
ECHO Unpacking hotfixes...
ECHO ================================================================
ECHO.

rd /s/q "%~dp0hotfixes\unpacked" >NUL 2>&1
mkdir "%~dp0hotfixes\unpacked" >NUL 2>&1

mkdir "%~dp0hotfixes\unpacked\IE11-Windows6.1-%ImageArchitecture%-%ImageLanguage%" >NUL 2>&1
start /w "" "%~dp0hotfixes\IE11-Windows6.1-%ImageArchitecture%-%ImageLanguage%.exe" /x:"%~dp0hotfixes\unpacked\IE11-Windows6.1-%ImageArchitecture%-%ImageLanguage%"

REM KB2533552 old servicing stack
mkdir "%~dp0hotfixes\unpacked\Windows6.1-KB2533552-%ImageArchitecture%" >NUL 2>&1
expand "%~dp0hotfixes\Windows6.1-KB2533552-%ImageArchitecture%.msu" -F:* "%~dp0hotfixes\unpacked\Windows6.1-KB2533552-%ImageArchitecture%" >NUL
mkdir "%~dp0hotfixes\unpacked\Windows6.1-KB2533552-%ImageArchitecture%\cab" >NUL 2>&1
expand "%~dp0hotfixes\unpacked\Windows6.1-KB2533552-%ImageArchitecture%\Windows6.1-KB2533552-%ImageArchitecture%.cab" -F:* "%~dp0hotfixes\unpacked\Windows6.1-KB2533552-%ImageArchitecture%\cab" >NUL
copy /b/y "%~dp0hotfixes\unpacked\Windows6.1-KB2533552-%ImageArchitecture%\cab\update.mum" "%~dp0hotfixes\unpacked\Windows6.1-KB2533552-%ImageArchitecture%\cab\update.mum.bak" >NUL 2>&1
findstr /l /i /v /c:"exclusive" "%~dp0hotfixes\unpacked\Windows6.1-KB2533552-%ImageArchitecture%\cab\update.mum.bak" > "%~dp0hotfixes\unpacked\Windows6.1-KB2533552-%ImageArchitecture%\cab\update.mum"

ECHO.
ECHO Done.
ECHO.


ECHO.
ECHO.
ECHO ================================================================
ECHO Addding packages
ECHO ================================================================
ECHO.

ECHO.
ECHO.
ECHO ================================================================
ECHO Adding package KB2533552 - old update for Servicing Stack...
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\unpacked\Windows6.1-KB2533552-%ImageArchitecture%\cab"
REM Restore original update.mum for KB2533552....
"%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "copy /b/y "%~dp0hotfixes\unpacked\Windows6.1-KB2533552-%ImageArchitecture%\cab\update.mum.bak" "%~dp0mount\1\Windows\servicing\Packages\Package_for_KB2533552~31bf3856ad364e35~%PackagesArchitecture%~~6.1.1.1.mum"" >nul

ECHO.
ECHO.
ECHO ================================================================
ECHO Adding package KB4490628 - Servicing Stack 03/2019...
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB4490628-%ImageArchitecture%.msu"

ECHO.
ECHO.
ECHO ================================================================
ECHO Adding package KB4474419 - SHA-2 code signing support...
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\windows6.1-kb4474419-v3-%ImageArchitecture%.msu"

ECHO.
ECHO.
ECHO ================================================================
ECHO Adding package KB5017397 - Servicing Stack 09/2022...
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\windows6.1-kb5017397-%ImageArchitecture%.msu"

ECHO.
ECHO.
ECHO ================================================================
ECHO Applying ESU Updates eligibility...
ECHO ================================================================
ECHO.

"%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "copy /b /y "%~dp0hotfixes\%EsuCom%.manifest" "%~dp0mount\1\Windows\WinSxS\Manifests"" >nul
reg load HKLM\TK_COMPONENTS "%~dp0mount\1\Windows\System32\config\COMPONENTS" >nul
reg load HKLM\TK_SOFTWARE "%~dp0mount\1\Windows\System32\config\SOFTWARE" >nul
for /f "tokens=* delims=" %%# in ('reg query HKLM\TK_COMPONENTS\DerivedData\VersionedIndex 2^>nul ^| findstr /l /i /c:"VersionedIndex"') do reg delete "%%#" /f
reg delete "HKLM\TK_COMPONENTS\DerivedData\Components\%EsuCom%" /f >nul 2>&1
reg add "HKLM\TK_COMPONENTS\DerivedData\Components\%EsuCom%" /v "c!%EsuFnd%" /t REG_BINARY /d "" /f >nul
reg add "HKLM\TK_COMPONENTS\DerivedData\Components\%EsuCom%" /v "identity" /t REG_BINARY /d "%EsuIdn%" /f >nul
reg add "HKLM\TK_COMPONENTS\DerivedData\Components\%EsuCom%" /v "S256H" /t REG_BINARY /d "%EsuHsh%" /f >nul
reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\SideBySide\Winners\%EsuKey%" /ve /d 6.3 /f >nul
reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\SideBySide\Winners\%EsuKey%\6.3" /ve /d 6.3.9603.30600 /f >nul
reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\SideBySide\Winners\%EsuKey%\6.3" /v 6.3.9603.30600 /t REG_BINARY /d 01 /f >nul
reg unload HKLM\TK_SOFTWARE >nul
reg unload HKLM\TK_COMPONENTS >nul

ECHO.
ECHO.
ECHO ================================================================
ECHO Adding package KB5028264 - Servicing Stack 07/2023...
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\windows6.1-kb5028264-%ImageArchitecture%.msu"

ECHO.
ECHO.
ECHO ================================================================
ECHO Adding CPU Microcode Updates
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB2818604-%ImageArchitecture%.msu"
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB3064209-%ImageArchitecture%.msu"

ECHO.
ECHO.
ECHO ================================================================
ECHO Adding package KB3172605 - Quality Update Rollup 07/2016
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB3172605-%ImageArchitecture%.msu"

ECHO.
ECHO.
ECHO ================================================================
ECHO Adding package KB3179573 - Quality Update Rollup 08/2016
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB3179573-%ImageArchitecture%.msu"


ECHO.
ECHO.
ECHO ================================================================
ECHO Adding package KB3125574 - Convenience Rollup Update 05/2016...
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\windows6.1-kb3125574-v4-%ImageArchitecture%.msu"

ECHO.
ECHO ================================================================
ECHO Adding Internet Explorer 11 pre-requisites...
ECHO ================================================================
ECHO.


ECHO.
ECHO.
ECHO ================================================================
ECHO Adding package KB2729094 - Segoe UI symbol font...
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB2729094-v2-%ImageArchitecture%.msu"

ECHO.
ECHO.
ECHO ================================================================
ECHO Adding package KB2533623 - API update...
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB2533623-%ImageArchitecture%.msu"

ECHO.
ECHO.
ECHO ================================================================
ECHO Adding package KB2670838 - Platform Update...
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB2670838-%ImageArchitecture%.msu"

ECHO.
ECHO.
ECHO ================================================================
ECHO Adding Internet Explorer 11...
ECHO ================================================================
ECHO.
ECHO.
ECHO ================================================================
ECHO Adding IE11 - main package...
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\unpacked\IE11-Windows6.1-%ImageArchitecture%-%ImageLanguage%\IE-Win7.CAB"
ECHO.
ECHO ================================================================
ECHO Adding IE11 - english spellcheck...
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\unpacked\IE11-Windows6.1-%ImageArchitecture%-%ImageLanguage%\IE-Spelling-en.MSU"
ECHO.
ECHO.
ECHO ================================================================
ECHO Adding IE11 - english hyphenation...
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\unpacked\IE11-Windows6.1-%ImageArchitecture%-%ImageLanguage%\IE-Hyphenation-en.MSU"
ECHO.
ECHO.

if exist "%~dp0hotfixes\unpacked\IE11-Windows6.1-%ImageArchitecture%-%ImageLanguage%\ielangpack-%ImageLanguage%.CAB" (
 ECHO.
 ECHO.
 ECHO ================================================================
 ECHO Adding IE11 - additional language pack: %ImageLanguage%...
 ECHO ================================================================
 ECHO.
 "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\unpacked\IE11-Windows6.1-%ImageArchitecture%-%ImageLanguage%\ielangpack-%ImageLanguage%.CAB"
)

if exist "%~dp0hotfixes\unpacked\IE11-Windows6.1-%ImageArchitecture%-%ImageLanguage%\IE-Spelling-%ImageLanguage%.MSU" (
 ECHO.
 ECHO.
 ECHO ================================================================
 ECHO Adding IE11 - additional spellcheck: %ImageLanguage%...
 ECHO ================================================================
 ECHO.
 "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\unpacked\IE11-Windows6.1-%ImageArchitecture%-%ImageLanguage%\IE-Spelling-%ImageLanguage%.MSU"
)

if exist "%~dp0hotfixes\unpacked\IE11-Windows6.1-%ImageArchitecture%-%ImageLanguage%\IE-Hyphenation-%ImageLanguage%.MSU" (
 ECHO.
 ECHO.
 ECHO ================================================================
 ECHO Adding IE11 - additional hyphenetion: %ImageLanguage%...
 ECHO ================================================================
 ECHO.
 "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\unpacked\IE11-Windows6.1-%ImageArchitecture%-%ImageLanguage%\IE-Hyphenation-%ImageLanguage%.MSU"
)


ECHO.
ECHO.
ECHO ================================================================
ECHO Adding Recommended Updates...
ECHO ================================================================
ECHO.
ECHO.
ECHO ================================================================
ECHO Adding KB917607 - Windows Help program
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB917607-%ImageArchitecture%.msu"
ECHO.
ECHO ================================================================
ECHO Adding KB2685813 - Kernel Mode Driver Framework Update
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\windows6.1-kb2685811-%ImageArchitecture%.msu"
ECHO.
ECHO ================================================================
ECHO Adding KB2685813 - User Mode Driver Framework Update...
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Umdf-1.11-Win-6.1-%ImageArchitecture%.msu"
ECHO.
ECHO.
ECHO ================================================================
ECHO Adding package KB2547666 - IE11 long URL parsing fix...
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB2547666-%ImageArchitecture%.msu"
ECHO.
ECHO.
ECHO ================================================================
ECHO Adding package KB2545698 - Blured text in IE fix...
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB2545698-%ImageArchitecture%.msu"

if "%ImageArchitecture%"=="x64" (
 ECHO.
 ECHO.
 ECHO ================================================================
 ECHO Adding package KB2603229 - registry mismatch fix for x64 systems...
 ECHO ================================================================
 ECHO.
 "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB2603229-x64.msu"
)

ECHO.
ECHO.
ECHO ================================================================
ECHO Adding package KB2732059 - OXPS to XPS converter
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB2732059-v5-%ImageArchitecture%.msu"

ECHO.
ECHO.
ECHO ================================================================
ECHO Adding package KB2750841 - IPv6 readiness update
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB2750841-%ImageArchitecture%.msu"

ECHO.
ECHO ================================================================
ECHO Adding package KB2761217 - Calibri Light font
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB2761217-%ImageArchitecture%.msu"

ECHO.
ECHO.
ECHO ================================================================
ECHO Adding package KB2773072 - Games Clasification Update
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB2773072-%ImageArchitecture%.msu"

ECHO.
ECHO.
ECHO ================================================================
ECHO Adding package KB2834140 - Fix for Platform Update KB2670838 patch...
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB2834140-v2-%ImageArchitecture%.msu"

ECHO.
ECHO.
ECHO ================================================================
ECHO Adding RDP 8.0 server and 8.1 client
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB2574819-v2-%ImageArchitecture%.msu"
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB2592687-%ImageArchitecture%.msu"
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB2830477-%ImageArchitecture%.msu"
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB2857650-%ImageArchitecture%.msu"
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB2913751-%ImageArchitecture%.msu"

ECHO.
ECHO.
ECHO ================================================================
ECHO Adding package KB2919469 - Canada Country Code Fix
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB2919469-%ImageArchitecture%.msu"

ECHO.
ECHO.
ECHO ================================================================
ECHO Adding packages with updated Currencies Symbols
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB2970228-%ImageArchitecture%.msu"
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB3006137-%ImageArchitecture%.msu"
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB3102429-v2-%ImageArchitecture%.msu"

ECHO.
ECHO.
ECHO ================================================================
ECHO Removing Windows Journal Application - potential security hole
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB3161102-%ImageArchitecture%.msu"



ECHO.
ECHO.
ECHO ================================================================
ECHO Adding security hotfixes that are missing in cumulative updates...
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB2667402-v2-%ImageArchitecture%.msu"
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB2813347-%ImageArchitecture%.msu"
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB2984972-%ImageArchitecture%.msu"
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB2698365-%ImageArchitecture%.msu"
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB2862330-v2-%ImageArchitecture%.msu"
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB2900986-%ImageArchitecture%.msu"
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB2912390-%ImageArchitecture%.msu"
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB3046269-%ImageArchitecture%.msu"
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB3035126-%ImageArchitecture%.msu"
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB3031432-%ImageArchitecture%.msu"
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB3004375-v3-%ImageArchitecture%.msu"
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB3110329-%ImageArchitecture%.msu"
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB3161949-%ImageArchitecture%.msu"
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB3159398-%ImageArchitecture%.msu"
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB3156016-%ImageArchitecture%.msu"
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB3150220-%ImageArchitecture%.msu"
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB3059317-%ImageArchitecture%.msu"

ECHO.
ECHO.
ECHO ================================================================
ECHO Adding RDP 8.1 hotfixes
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB2923545-%ImageArchitecture%.msu"
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB2984976-%ImageArchitecture%.msu"
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB3020388-%ImageArchitecture%.msu"
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB3075226-%ImageArchitecture%.msu"


ECHO.
ECHO.
ECHO ================================================================
ECHO Adding package KB3138612 - Windows Update Client...
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB3138612-%ImageArchitecture%.msu"

ECHO.
ECHO.
ECHO ================================================================
ECHO Adding Internet Explorer 11 Cumulative Updates...
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\ie11-windows6.1-kb3185319-%ImageArchitecture%.msu"
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\ie11-windows6.1-kb4483187-%ImageArchitecture%.msu"

ECHO.
ECHO.
ECHO ================================================================
ECHO Adding package KB2894844 - .NET 3.5.1 Security Update...
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB2894844-%ImageArchitecture%.msu"

ECHO.
ECHO.
ECHO ================================================================
ECHO Adding package KB4019990 - .NET 4.7 Pre-requsite...
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\windows6.1-kb4019990-%ImageArchitecture%.msu"

ECHO.
ECHO.
ECHO ================================================================
ECHO Adding .NET 3.5.1 January 2020 Cumulative Updates...
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\windows6.1-kb4040980-%ImageArchitecture%.msu"
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\windows6.1-kb4532945-%ImageArchitecture%.msu"

ECHO.
ECHO.
ECHO ================================================================
ECHO Adding package KB5013637 - .NET 3.5.1 Cumulative...
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\windows6.1-kb5013637-%ImageArchitecture%.msu"

ECHO.
ECHO.
ECHO ================================================================
ECHO Adding package KB5020861 - .NET 3.5.1 December 2022 Cumulative...
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\windows6.1-kb5020861-%ImageArchitecture%.msu"

ECHO.
ECHO.
ECHO ================================================================
ECHO Adding package KB5028969 - .NET 3.5.1 August 2023 Cumulative...
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\windows6.1-kb5028969-%ImageArchitecture%.msu"

ECHO.
ECHO.
ECHO ================================================================
ECHO Adding package KB5022338 - January 2023 Cumulative...
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\windows6.1-kb5022338-%ImageArchitecture%.msu"

ECHO.
ECHO.
ECHO ================================================================
ECHO Adding package KB5029296 - August 2023 Cumulative...
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\windows6.1-kb5029296-%ImageArchitecture%.msu"

ECHO.
ECHO.
ECHO ================================================================
ECHO Adding package KB5010798 - Out-of-band update...
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\windows6.1-kb5010798-%ImageArchitecture%.msu"

ECHO.
ECHO.
ECHO ================================================================
ECHO Adding package Universal C Runtime...
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-KB3118401-%ImageArchitecture%.msu"



REM Clean temporary unpacked
rd /s/q "%~dp0hotfixes\unpacked" >NUL 2>&1

:skipHotfixes

if not "%ApplyCustPatches%"=="1" goto skipCustPatches

 echo.
 echo.
 ECHO ================================================================
 echo Mounting registry
 ECHO ================================================================
 echo.

 reg load HKLM\TK_DEFAULT "%~dp0mount\1\Windows\System32\config\default" >nul
 reg load HKLM\TK_NTUSER "%~dp0mount\1\Users\Default\ntuser.dat" >nul
 reg load HKLM\TK_SOFTWARE "%~dp0mount\1\Windows\System32\config\SOFTWARE" >nul
 reg load HKLM\TK_SYSTEM "%~dp0mount\1\Windows\System32\config\SYSTEM" >nul

 ECHO.
 ECHO.
 ECHO ================================================================
 echo Applying custom fixes
 ECHO ================================================================
 ECHO.

REM User Setup for each new user, re-apply some  settings which otherwise aren't honored when set in default user registry node
echo @ECHO OFF>"%~dp0mount\1\Windows\UserSetup.cmd"
echo TITLE User settings setup>>"%~dp0mount\1\Windows\UserSetup.cmd"
REM Re-apply disable NTFS last access time update
echo fsutil behavior set disableLastAccess ^1 ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
REM Disable IE11 proxy autodetection
echo reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections" /v "DefaultConnectionSettings" /t REG_BINARY /d "3c0000000f0000000100000000000000090000003132372e302e302e3100000000010000000000000010d75bde6f11c50101000000c23f806f0000000000000000" /f ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections" /v "SavedLegacySettings" /t REG_BINARY /d "3c000000040000000100000000000000090000003132372e302e302e3100000000010000000000000010d75bde6f11c50101000000c23f806f0000000000000000" /f ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
REM Disable checking of certificate server and issuer revocation
echo reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v "CertificateRevocation" /t REG_DWORD /d 0 /f ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\WinTrust\Trust Providers\Software Publishing" /v "State" /t REG_DWORD /d 0x23e00 /f ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
REM re-disable animations and sounds
echo reg add "HKCU\Control Panel\Desktop" /v "UserPreferencesMask" /t REG_BINARY /d 9012078010000000 /f ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo reg add "HKCU\Control Panel\Desktop\WindowMetrics" /v "MinAnimate" /t REG_SZ /d "0" /f ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarAnimations" /t REG_DWORD /d 0 /f ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo reg add "HKCU\AppEvents\Schemes" /ve /t REG_SZ /d ".None" /f ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo for /f "tokens=1 delims=" %%%%a in ('reg query "HKCU\AppEvents\Schemes\Apps" 2^^^>nul ^^^| find /i "\Schemes\"') do (>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo  for /f "tokens=1 delims=" %%%%b in ('reg query "%%%%a" 2^^^>nul ^^^| find /i "%%%%a\"') do (>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo   for /f "tokens=1 delims=" %%%%c in ('reg query "%%%%b" /e /k /f ".Current" 2^^^>nul ^^^| find /i "%%%%b\.Current"') do (>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo    reg add "%%%%c" /ve /t REG_SZ /d "" /f ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo   )>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo  )>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo )>>"%~dp0mount\1\Windows\UserSetup.cmd"
REM Disable keyboard switching key combination
echo reg add "HKCU\Keyboard Layout\Toggle" /v "Language Hotkey" /t REG_SZ /d "3" /f ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo reg add "HKCU\Keyboard Layout\Toggle" /v "Hotkey" /t REG_SZ /d "3" /f ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo reg add "HKCU\Keyboard Layout\Toggle" /v "Layout Hotkey" /t REG_SZ /d "3" /f ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo for /l %%%%i in (2,1,5) do reg delete "HKCU\Keyboard Layout\Preload" /v %%%%i /f ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
REM Hide language bar
echo reg add "HKCU\Software\Microsoft\CTF\LangBar" /v "ShowStatus" /t REG_DWORD /d 3 /f ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo reg add "HKCU\Software\Microsoft\CTF\LangBar" /v "ExtraIconsOnMinimized" /t REG_DWORD /d 0 /f ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo reg add "HKCU\Software\Microsoft\CTF\LangBar" /v "Label" /t REG_DWORD /d 1 /f ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo reg load HKLM\TK_NTUSER "%%SystemDrive%%\Users\Default\ntuser.dat" ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo reg delete "HKLM\TK_NTUSER\Software\Microsoft\Windows\CurrentVersion\Run" /v "UserSetup" /f ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo reg unload HKLM\TK_NTUSER ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo schtasks /Delete /TN "Microsoft\Windows\Media Center\ActivateWindowsSearch" /F ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo schtasks /Delete /TN "Microsoft\Windows\Media Center\ConfigureInternetTimeService" /F ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo schtasks /Delete /TN "Microsoft\Windows\Media Center\DispatchRecoveryTasks" /F ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo schtasks /Delete /TN "Microsoft\Windows\Media Center\ehDRMInit" /F ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo schtasks /Delete /TN "Microsoft\Windows\Media Center\InstallPlayReady" /F ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo schtasks /Delete /TN "Microsoft\Windows\Media Center\mcupdate" /F ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo schtasks /Delete /TN "Microsoft\Windows\Media Center\MediaCenterRecoveryTask" /F ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo schtasks /Delete /TN "Microsoft\Windows\Media Center\ObjectStoreRecoveryTask" /F ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo schtasks /Delete /TN "Microsoft\Windows\Media Center\OCURActivate" /F ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo schtasks /Delete /TN "Microsoft\Windows\Media Center\OCURDiscovery" /F ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo schtasks /Delete /TN "Microsoft\Windows\Media Center\PBDADiscovery" /F ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo schtasks /Delete /TN "Microsoft\Windows\Media Center\PBDADiscoveryW1" /F ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo schtasks /Delete /TN "Microsoft\Windows\Media Center\PBDADiscoveryW2" /F ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo schtasks /Delete /TN "Microsoft\Windows\Media Center\PeriodicScanRetry" /F ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo schtasks /Delete /TN "Microsoft\Windows\Media Center\PvrRecoveryTask" /F ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo schtasks /Delete /TN "Microsoft\Windows\Media Center\PvrScheduleTask" /F ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo schtasks /Delete /TN "Microsoft\Windows\Media Center\RecordingRestart" /F ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo schtasks /Delete /TN "Microsoft\Windows\Media Center\RegisterSearch" /F ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo schtasks /Delete /TN "Microsoft\Windows\Media Center\ReindexSearchRoot" /F ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo schtasks /Delete /TN "Microsoft\Windows\Media Center\SqlLiteRecoveryTask" /F ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo schtasks /Delete /TN "Microsoft\Windows\Media Center\UpdateRecordPath" /F ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "UserSetup" /f ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
echo del /q /f "%%windir%%\UserSetup.cmd" ^>nul 2^>^&^1>>"%~dp0mount\1\Windows\UserSetup.cmd"
reg add "HKLM\TK_NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "UserSetup" /t REG_EXPAND_SZ /d "%%SystemRoot%%\UserSetup.cmd" /f >nul


 REM Workaround for Old Games Not Launching and Eating 100% CPU
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\GameUX" /v "DownloadGameInfo" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\GameUX" /v "GameUpdateOptions" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\GameUX" /v "ListRecentlyPlayed" /t REG_DWORD /d 0 /f >nul

 REM Remove legacy VGA video driver
 if not "%RemoveLegacyVGA%"=="0" (

  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f /s "%~dp0mount\1\Windows\System32\DriverStore\display.inf_loc"" >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f "%~dp0mount\1\Windows\System32\vga.dll"" >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f "%~dp0mount\1\Windows\System32\framebuf.dll"" >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f "%~dp0mount\1\Windows\System32\drivers\vga.sys"" >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f "%~dp0mount\1\Windows\System32\drivers\vgapnp.sys"" >nul 2>&1

  if "%ImageArchitecture%"=="x86" (
   "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "rd /s /q "%~dp0mount\1\Windows\System32\DriverStore\FileRepository\display.inf_x86_neutral_36353e26d7770ebb"" >nul 2>&1
  )

  if "%ImageArchitecture%"=="x64" (
   "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "rd /s /q "%~dp0mount\1\Windows\System32\DriverStore\FileRepository\display.inf_amd64_neutral_ea1c8215e52777a6"" >nul 2>&1
  )

  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SYSTEM\ControlSet001\Services\VgaSave" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SYSTEM\ControlSet002\Services\VgaSave" /f >nul 2>&1
  del /q /f "%~dp0mount\1\Windows\inf\display.inf" >nul 2>&1
  del /q /f "%~dp0mount\1\Windows\inf\display.PNF" >nul 2>&1
  Reg delete "HKLM\TK_SYSTEM\ControlSet001\Services\Vga" /f >nul 2>&1
  Reg delete "HKLM\TK_SYSTEM\ControlSet002\Services\Vga" /f >nul 2>&1

 )

 REM Set default NTP time server
 reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\DateTime\Servers" /ve /t REG_SZ /d "0" /f >nul
 reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\DateTime\Servers" /v "0" /t REG_SZ /d "%NTPserver%" /f >nul
 Reg add "HKLM\TK_SYSTEM\ControlSet001\Services\W32Time" /v "Start" /t REG_DWORD /d "2" /f >nul
 Reg add "HKLM\TK_SYSTEM\ControlSet001\Services\W32Time\Parameters" /v "NtpServer" /t REG_SZ /d "%NTPserver%,0x9" /f >nul
 Reg add "HKLM\TK_SYSTEM\ControlSet001\Services\W32Time\Parameters" /v "Type" /t REG_SZ /d "NTP" /f >nul
 Reg add "HKLM\TK_SYSTEM\ControlSet002\Services\W32Time" /v "Start" /t REG_DWORD /d "2" /f >nul
 Reg add "HKLM\TK_SYSTEM\ControlSet002\Services\W32Time\Parameters" /v "NtpServer" /t REG_SZ /d "%NTPserver%,0x9" /f >nul
 Reg add "HKLM\TK_SYSTEM\ControlSet002\Services\W32Time\Parameters" /v "Type" /t REG_SZ /d "NTP" /f >nul
 Reg add "HKLM\TK_SYSTEM\ControlSet001\Services\W32Time\TimeProviders\NtpClient" /v "Enabled" /t REG_DWORD /d 1 /f >nul
 Reg add "HKLM\TK_SYSTEM\ControlSet001\Services\W32Time\TimeProviders\NtpClient" /v "SpecialPollInterval" /t REG_DWORD /d 86400 /f >nul
 reg delete "HKLM\TK_SYSTEM\ControlSet001\Services\W32Time\TimeProviders\NtpClient" /v "SpecialPollTimeRemaining" /f >nul 2>&1
 Reg add "HKLM\TK_SYSTEM\ControlSet002\Services\W32Time\TimeProviders\NtpClient" /v "Enabled" /t REG_DWORD /d 1 /f >nul
 Reg add "HKLM\TK_SYSTEM\ControlSet002\Services\W32Time\TimeProviders\NtpClient" /v "SpecialPollInterval" /t REG_DWORD /d 86400 /f >nul
 reg delete "HKLM\TK_SYSTEM\ControlSet002\Services\W32Time\TimeProviders\NtpClient" /v "SpecialPollTimeRemaining" /f >nul 2>&1

 REM Disable Time Sync NTP server
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\W32time\TimeProviders\NtpServer" /v "Enabled" /t REG_DWORD /d "0" /f >nul

 REM Disable Time Sync entirely
 if not "%DisableTimeSync%"=="0" (
  reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\W32time\TimeProviders\NtpClient" /v "Enabled" /t REG_DWORD /d "0" /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet001\Services\W32Time\Parameters" /v "Type " /t REG_SZ /d "NoSync" /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Services\W32Time\Parameters" /v "Type " /t REG_SZ /d "NoSync" /f >nul
  Reg add "HKLM\TK_SYSTEM\ControlSet001\Services\W32Time" /v "Start" /t REG_DWORD /d "4" /f >nul
  Reg add "HKLM\TK_SYSTEM\ControlSet002\Services\W32Time" /v "Start" /t REG_DWORD /d "4" /f >nul
 )

 REM Disable Internet Connection Checking
 if not "%DisableInternetConnectionChecking%"=="0" (
  reg add "HKLM\TK_SYSTEM\ControlSet001\Services\NlaSvc\Parameters\Internet" /v "EnableActiveProbing" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Services\NlaSvc\Parameters\Internet" /v "EnableActiveProbing" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\NetworkConnectivityStatusIndicator" /v "NoActiveProbe" /t REG_DWORD /d 1 /f >nul
  reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\Network Connections" /v "NC_DoNotShowLocalOnlyIcon" /t REG_DWORD /d 1 /f >nul
 )

 REM Disable Recent Docs History
 Reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoRecentDocsHistory" /t REG_DWORD /d 1 /f >nul
 Reg add "HKLM\TK_NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoRecentDocsHistory" /t REG_DWORD /d 1 /f >nul
 Reg add "HKLM\TK_NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "ClearRecentDocsOnExit" /t REG_DWORD /d 1 /f >nul

 REM Hide Map network drive from context menu on This PC
 Reg add "HKLM\TK_NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoNetConnectDisconnect" /t REG_DWORD /d 1 /f >nul

 REM Hide Manage verb from context menu on This PC
 Reg add "HKLM\TK_NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoManageMyComputerVerb" /t REG_DWORD /d 1 /f >nul

 REM No low disk space warning
 Reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoLowDiskSpaceChecks" /t REG_DWORD /d 1 /f >nul

 REM Other Explorer Tweaks
 Reg add "HKLM\TK_NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoResolveTrack" /t REG_DWORD /d 1 /f >nul
 Reg add "HKLM\TK_NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoResolveSearch" /t REG_DWORD /d 1 /f >nul
 Reg add "HKLM\TK_NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoSMHelp" /t REG_DWORD /d 1 /f >nul

 REM Disable "Shortcut" word when creating shortcuts
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Windows\CurrentVersion\Explorer" /v "Link" /t REG_BINARY /d 00000000 /f >nul

 REM Show All TaskBar Icons
 Reg add "HKLM\TK_NTUSER\Software\Microsoft\Windows\CurrentVersion\Explorer" /v "EnableAutoTray" /t REG_DWORD /d 0 /f >nul

 REM Disable Special Keys Combination
 reg add "HKLM\TK_NTUSER\Control Panel\Accessibility\HighContrast" /v "Flags" /t REG_SZ /d "122" /f >nul
 reg add "HKLM\TK_NTUSER\Control Panel\Accessibility\MouseKeys" /v "Flags" /t REG_SZ /d "58" /f >nul
 reg add "HKLM\TK_NTUSER\Control Panel\Accessibility\StickyKeys" /v "Flags" /t REG_SZ /d "506" /f >nul
 reg add "HKLM\TK_NTUSER\Control Panel\Accessibility\ToggleKeys" /v "Flags" /t REG_SZ /d "58" /f >nul
 reg add "HKLM\TK_NTUSER\Control Panel\Accessibility\Keyboard Response" /v "Flags" /t REG_SZ /d "122" /f >nul

 REM Disable keyboard switching key combination
 reg add "HKLM\TK_NTUSER\Keyboard Layout\Toggle" /v "Language Hotkey" /t REG_SZ /d "3" /f >nul
 reg add "HKLM\TK_NTUSER\Keyboard Layout\Toggle" /v "Hotkey" /t REG_SZ /d "3" /f >nul
 reg add "HKLM\TK_NTUSER\Keyboard Layout\Toggle" /v "Layout Hotkey" /t REG_SZ /d "3" /f >nul

 REM Hide language bar
 reg add "HKLM\TK_NTUSER\Software\Microsoft\CTF\LangBar" /v "ShowStatus" /t REG_DWORD /d 3 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\CTF\LangBar" /v "ExtraIconsOnMinimized" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\CTF\LangBar" /v "Label" /t REG_DWORD /d 1 /f >nul

 REM Disable UPnP
 reg add "HKLM\TK_SYSTEM\ControlSet001\Services\upnphost" /v "Start" /t REG_DWORD /d 4 /f >nul
 reg add "HKLM\TK_SYSTEM\ControlSet001\Services\SSDPSRV" /v "Start" /t REG_DWORD /d 4 /f >nul
 reg add "HKLM\TK_SYSTEM\ControlSet002\Services\upnphost" /v "Start" /t REG_DWORD /d 4 /f >nul
 reg add "HKLM\TK_SYSTEM\ControlSet002\Services\SSDPSRV" /v "Start" /t REG_DWORD /d 4 /f >nul
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\UPnP\UPnPHostConfig" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Plain\{D622195C-D680-4FEA-9C56-59660C7C9E94}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{D622195C-D680-4FEA-9C56-59660C7C9E94}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Plain\{5A40E926-9E86-4B89-9CFD-B12311724371}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{5A40E926-9E86-4B89-9CFD-B12311724371}" /f >nul 2>&1
 del /q/f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\UPnP\*" >nul 2>&1

 REM Disable Remote Assistance
 reg add "HKLM\TK_SYSTEM\ControlSet001\Control\Remote Assistance" /v "fAllowToGetHelp" /t REG_DWORD /d "0" /f >nul
 reg add "HKLM\TK_SYSTEM\ControlSet002\Control\Remote Assistance" /v "fAllowToGetHelp" /t REG_DWORD /d "0" /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "fAllowToGetHelp" /t REG_DWORD /d "0" /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "fAllowUnsolicited" /t REG_DWORD /d "0" /f >nul
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\RemoteAssistance\RemoteAssistanceTask" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Plain\{731E9C62-95B5-4C8C-AB64-4CC591C9FF5B}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{731E9C62-95B5-4C8C-AB64-4CC591C9FF5B}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Plain\{CB3D64BF-C0C9-45FF-BFB0-FF1A8F680186}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{CB3D64BF-C0C9-45FF-BFB0-FF1A8F680186}" /f >nul 2>&1
 del /q/f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\RemoteAssistance\*" >nul 2>&1

 REM Disable IPv4 Autoconfig
 Reg add "HKLM\TK_SYSTEM\ControlSet001\Services\Tcpip\Parameters" /v "IPAutoconfigurationEnabled" /t REG_DWORD /d "0" /f >nul
 Reg add "HKLM\TK_SYSTEM\ControlSet002\Services\Tcpip\Parameters" /v "IPAutoconfigurationEnabled" /t REG_DWORD /d "0" /f >nul

 REM Disable IP source routing for security
 Reg add "HKLM\TK_SYSTEM\ControlSet001\Services\Tcpip\Parameters" /v "DisableIPSourceRouting" /t REG_DWORD /d "2" /f >nul
 Reg add "HKLM\TK_SYSTEM\ControlSet002\Services\Tcpip\Parameters" /v "DisableIPSourceRouting" /t REG_DWORD /d "2" /f >nul
 Reg add "HKLM\TK_SYSTEM\ControlSet001\Services\Tcpip6\Parameters" /v "DisableIPSourceRouting" /t REG_DWORD /d "2" /f >nul
 Reg add "HKLM\TK_SYSTEM\ControlSet002\Services\Tcpip6\Parameters" /v "DisableIPSourceRouting" /t REG_DWORD /d "2" /f >nul

 REM Disable End Of Support Notification
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Windows\CurrentVersion\EOSNotify" /v "DiscontinueEOS" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Windows\CurrentVersion\SipNotify" /v "DontRemindMe" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\Gwx" /v "DisableGwx" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v "DisableOSUpgrade" /t REG_DWORD /d 1 /f >nul

 REM Disable Action Center
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "HideSCAHealth" /t REG_DWORD /d 1 /f >nul
 Reg add "HKLM\TK_SYSTEM\ControlSet001\Services\wscsvc" /v "Start" /t REG_DWORD /d "4" /f >nul
 Reg add "HKLM\TK_SYSTEM\ControlSet002\Services\wscsvc" /v "Start" /t REG_DWORD /d "4" /f >nul

 REM Disable Windows Anytime Upgrade
 reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel\NameSpace\{BE122A0E-4503-11DA-8BDE-F66BAD1E3F3A}" /f >nul 2>&1
 reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\WAU" /v "Disabled" /t REG_DWORD /d 1 /f >nul
 del /q /f "%~dp0mount\1\ProgramData\Microsoft\Windows\Start Menu\Programs\Windows Anytime Upgrade.lnk" >nul 2>&1

 REM Disable User Account Control
 reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA  /t REG_DWORD /d 0 /f >nul

 REM Remove Windows Defender and MRT
if "%RemoveDefender%"=="0" goto skipRemoveDefender
  Reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows Defender" /v DisableAntiSpyware /t REG_DWORD /d 1 /f >nul
  Reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows Defender\Real-time Protection" /v DisableRealtimeMonitoring /t REG_DWORD /d 1 /f >nul
  Reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\MRT" /v DontOfferThroughWUAU /t REG_DWORD /d 1 /f >nul

  Reg delete "HKLM\TK_SYSTEM\ControlSet001\Services\WinDefend" /f >nul 2>&1
  Reg delete "HKLM\TK_SYSTEM\ControlSet002\Services\WinDefend" /f >nul 2>&1
  reg delete "HKLM\TK_SYSTEM\ControlSet001\Control\SafeBoot\Minimal\WinDefend" /f >nul 2>&1
  reg delete "HKLM\TK_SYSTEM\ControlSet001\Control\SafeBoot\Network\WinDefend" /f >nul 2>&1
  reg delete "HKLM\TK_SYSTEM\ControlSet002\Control\SafeBoot\Minimal\WinDefend" /f >nul 2>&1
  reg delete "HKLM\TK_SYSTEM\ControlSet002\Control\SafeBoot\Network\WinDefend" /f >nul 2>&1

  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows Defender\MP Scheduled Scan" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows Defender\MpIdleTask" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Plain\{A1D60D55-A6B8-401B-BC05-2938E02DF2F2}" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{A1D60D55-A6B8-401B-BC05-2938E02DF2F2}" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Plain\{C4E8B14A-4159-4C58-BDAD-281DBBFC97E8}" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{C4E8B14A-4159-4C58-BDAD-281DBBFC97E8}" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows Defender" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Microsoft\Windows Defender" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel\NameSpace\{D8559EB9-20C0-410E-BEDA-7ED416AECC2A}" /f >nul 2>&1
  del /q/f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows Defender\*" >nul 2>&1
  rd /s/q "%~dp0mount\1\ProgramData\Microsoft\Windows Defender" >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "rd /s/q "%~dp0mount\1\Program Files\Windows Defender"" >nul 2>&1
  if exist "%~dp0mount\1\Program Files (x86)\Windows Defender\*" "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "rd /s/q "%~dp0mount\1\Program Files (x86)\Windows Defender"" >nul 2>&1

  reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments" /v ScanWithAntiVirus /t REG_DWORD /d 1 /f >nul

  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\APPID\{A79DB36D-6218-48e6-9EC9-DCBA9A39BF0F}" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\APPID\{A79DB36D-6218-48e6-9EC9-DCBA9A39BF0F}" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\APPID\{A79DB36D-6218-48e6-9EC9-DCBA9A39BF0F}" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\CLSID\{2781761E-28E0-4109-99FE-B9D127C57AFE}" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\CLSID\{2781761E-28E0-4109-99FE-B9D127C57AFE}" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\CLSID\{2781761E-28E0-4109-99FE-B9D127C57AFE}" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\CLSID\{A2D75874-6750-4931-94C1-C99D3BC9D0C7}" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\CLSID\{D8559EB9-20C0-410E-BEDA-7ED416AECC2A}" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Interface\{AC30C2BA-0109-403D-9D8E-140BB470379C}" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Interface\{CDFED399-7999-4309-B064-1EDE04BC580D}" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Interface\{E2D74550-8E41-460E-BB51-52E1F9522134}" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\TypeLib\{8C389764-F036-48F2-9AE2-88C260DCF43B}" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\TypeLib\{8C389764-F036-48F2-9AE2-88C260DCF43B}" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\TypeLib\{8C389764-F036-48F2-9AE2-88C260DCF43B}" /f >nul 2>&1

  reg delete "HKLM\TK_SYSTEM\ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy\RestrictedServices\Static\System" /v "WindowsDefender-In" /f >nul 2>&1
  reg delete "HKLM\TK_SYSTEM\ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy\RestrictedServices\Static\System" /v "WindowsDefender-Out" /f >nul 2>&1
  reg delete "HKLM\TK_SYSTEM\ControlSet002\Services\SharedAccess\Parameters\FirewallPolicy\RestrictedServices\Static\System" /v "WindowsDefender-In" /f >nul 2>&1
  reg delete "HKLM\TK_SYSTEM\ControlSet002\Services\SharedAccess\Parameters\FirewallPolicy\RestrictedServices\Static\System" /v "WindowsDefender-Out" /f >nul 2>&1

  reg delete "HKEY_LOCAL_MACHINE\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-Windows Defender/Operational" /f >nul 2>&1
  reg delete "HKEY_LOCAL_MACHINE\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-Windows Defender/WHC" /f >nul 2>&1
  reg delete "HKEY_LOCAL_MACHINE\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Publishers\{11cd958a-c507-4ef3-b3f2-5fd9dfbd2c78}" /f >nul 2>&1
  reg delete "HKEY_LOCAL_MACHINE\TK_SYSTEM\ControlSet001\services\eventlog\System\WinDefend" /f >nul 2>&1
  reg delete "HKEY_LOCAL_MACHINE\TK_SYSTEM\ControlSet002\services\eventlog\System\WinDefend" /f >nul 2>&1
  reg delete "HKLM\TK_SYSTEM\ControlSet001\Control\WMI\Autologger\EventLog-System\{11cd958a-c507-4ef3-b3f2-5fd9dfbd2c78}" /f >nul 2>&1
  reg delete "HKLM\TK_SYSTEM\ControlSet002\Control\WMI\Autologger\EventLog-System\{11cd958a-c507-4ef3-b3f2-5fd9dfbd2c78}" /f >nul 2>&1

  type "%~dp0mount\1\Windows\winsxs\pending.xml" | find /i /v "-Malware" > "%~dp0hotfixes\pending.tmp"
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "copy /b /y "%~dp0hotfixes\pending.tmp" "%~dp0mount\1\Windows\winsxs\pending.xml"" >nul
:skipRemoveDefender

 REM Disable App Compatinility Assistant
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\AppCompat" /v "AITEnable" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\AppCompat" /v "DisablePCA" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\AppCompat" /v "DisableInventory" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\AppCompat" /v "DisableUAR" /t REG_DWORD /d 1 /f >nul
 Reg add "HKLM\TK_SYSTEM\ControlSet001\Services\PcaSvc" /v "Start" /t REG_DWORD /d "4" /f >nul
 Reg add "HKLM\TK_SYSTEM\ControlSet002\Services\PcaSvc" /v "Start" /t REG_DWORD /d "4" /f >nul
 Reg add "HKLM\TK_SYSTEM\ControlSet001\Services\AeLookupSvc" /v "Start" /t REG_DWORD /d "4" /f >nul
 Reg add "HKLM\TK_SYSTEM\ControlSet002\Services\AeLookupSvc" /v "Start" /t REG_DWORD /d "4" /f >nul

 REM Disable Troubleshooting and Diagnostics
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\WDI" /v "ScenarioExecutionEnabled" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\WDI" /v "DataRetentionBySizeEnabled" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\WDI" /v "DirSizeLimit" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\WDI\{081D3213-48AA-4533-9284-D98F01BDC8E6}" /v "ScenarioExecutionEnabled" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\WDI\{186f47ef-626c-4670-800a-4a30756babad}" /v "ScenarioExecutionEnabled" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\WDI\{2698178D-FDAD-40AE-9D3C-1371703ADC5B}" /v "ScenarioExecutionEnabled" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\WDI\{29689E29-2CE9-4751-B4FC-8EFF5066E3FD}" /v "ScenarioExecutionEnabled" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\WDI\{29689E29-2CE9-4751-B4FC-8EFF5066E3FD}" /v "EnabledScenarioExecutionLevel" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\WDI\{3af8b24a-c441-4fa4-8c5c-bed591bfa867}" /v "ScenarioExecutionEnabled" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\WDI\{54077489-683b-4762-86c8-02cf87a33423}" /v "ScenarioExecutionEnabled" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\WDI\{659F08FB-2FAB-42a7-BD4F-566CFA528769}" /v "ScenarioExecutionEnabled" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\WDI\{67144949-5132-4859-8036-a737b43825d8}" /v "ScenarioExecutionEnabled" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\WDI\{8519d925-541e-4a2b-8b1e-8059d16082f2}" /v "ScenarioExecutionEnabled" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\WDI\{86432a0b-3c7d-4ddf-a89c-172faa90485d}" /v "ScenarioExecutionEnabled" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\WDI\{88D69CE1-577A-4dd9-87AE-AD36D3CD9643}" /v "ScenarioExecutionEnabled" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\WDI\{9c5a40da-b965-4fc3-8781-88dd50a6299d}" /v "ScenarioExecutionEnabled" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\WDI\{a7a5847a-7511-4e4e-90b1-45ad2a002f51}" /v "ScenarioExecutionEnabled" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\WDI\{acfd1ca6-18b6-4ccf-9c07-580cdb6eded4}" /v "ScenarioExecutionEnabled" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\WDI\{acfd1ca6-18b6-4ccf-9c07-580cdb6eded4}" /v "EnabledScenarioExecutionLevel" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\WDI\{C295FBBA-FD47-46ac-8BEE-B1715EC634E5}" /v "ScenarioExecutionEnabled" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\WDI\{C295FBBA-FD47-46ac-8BEE-B1715EC634E5}" /v "DownloadToolsEnabled" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\WDI\{D113E4AA-2D07-41b1-8D9B-C065194A791D}" /v "ScenarioExecutionEnabled" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\WDI\{dc42ff48-e40d-4a60-8675-e71f7e64aa9a}" /v "ScenarioExecutionEnabled" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\WDI\{dc42ff48-e40d-4a60-8675-e71f7e64aa9a}" /v "EnabledScenarioExecutionLevel" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\WDI\{eb73b633-3f4e-4ba0-8f60-8f3c6f53168f}" /v "ScenarioExecutionEnabled" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\WDI\{eb73b633-3f4e-4ba0-8f60-8f3c6f53168f}" /v "EnabledScenarioExecutionLevel" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\WDI\{ecfb03d1-58ee-4cc7-a1b5-9bc6febcb915}" /v "ScenarioExecutionEnabled" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\WDI\{ffc42108-4920-4acf-a4fc-8abdcc68ada4}" /v "ScenarioExecutionEnabled" /t REG_DWORD /d 0 /f >nul
 
 REM Privacy settings
 Reg add "HKLM\TK_NTUSER\SOFTWARE\Microsoft\InputPersonalization" /v "RestrictImplicitInkCollection" /t REG_DWORD /d 1 /f >nul
 Reg add "HKLM\TK_NTUSER\SOFTWARE\Microsoft\InputPersonalization" /v "RestrictImplicitTextCollection" /t REG_DWORD /d 1 /f >nul
 Reg add "HKLM\TK_NTUSER\SOFTWARE\Policies\Microsoft\Control Panel\International" /v "TurnOffAutocorrectMisspelledWords" /t REG_DWORD /d 1 /f >nul
 Reg add "HKLM\TK_NTUSER\SOFTWARE\Policies\Microsoft\Control Panel\International" /v "TurnOffHighlightMisspelledWords" /t REG_DWORD /d 1 /f >nul
 Reg add "HKLM\TK_NTUSER\SOFTWARE\Policies\Microsoft\Control Panel\International" /v "TurnOffInsertSpace" /t REG_DWORD /d 1 /f >nul
 Reg add "HKLM\TK_NTUSER\SOFTWARE\Policies\Microsoft\Control Panel\International" /v "TurnOffOfferTextPredictions" /t REG_DWORD /d 1 /f >nul

 Reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\TabletPC" /v "PreventHandwritingDataSharing" /t REG_DWORD /d 1 /f >nul
 Reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\HandwritingErrorReports" /v "PreventHandwritingErrorReports" /t REG_DWORD /d 1 /f >nul
 Reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\PCHealth\HelpSvc" /v "Headlines" /t REG_DWORD /d 0 /f >nul

 Reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoPublishingWizard" /t REG_DWORD /d 1 /f >nul
 Reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoWebServices" /t REG_DWORD /d 1 /f >nul
 Reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoOnlinePrintsWizard" /t REG_DWORD /d 1 /f >nul
 Reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\PCHealth\HelpSvc" /v "MicrosoftKBSearch" /t REG_DWORD /d 0 /f >nul
 Reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\Internet Connection Wizard" /v "ExitOnMSICW" /t REG_DWORD /d 1 /f >nul
 Reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\Registration Wizard Control" /v "NoRegistration" /t REG_DWORD /d 1 /f >nul
 Reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\SearchCompanion" /v "DisableContentFileUpdates" /t REG_DWORD /d 1 /f >nul
 Reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows NT\Printers" /v "DisableHTTPPrinting" /t REG_DWORD /d 1 /f >nul
 Reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows NT\Printers" /v "DisableWebPnPDownload" /t REG_DWORD /d 1 /f >nul
 
 REM Disable and Remove Telemetry and Spying
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\SQMClient\Windows" /v "CEIPEnable" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Internet Explorer\SQM" /v "DisableCustomerImprovementProgram" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" /v "Disabled" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" /v "LoggingDisabled" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" /v "DontSendAdditionalData" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\MRT" /v "DontReportInfectionInformation" /t REG_DWORD /d 1 /f >nul

 Reg delete "HKLM\TK_SYSTEM\ControlSet001\Services\DiagTrack" /f >nul 2>&1
 Reg delete "HKLM\TK_SYSTEM\ControlSet002\Services\DiagTrack" /f >nul 2>&1
 Reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack" /f >nul 2>&1
 Reg delete "HKLM\TK_SYSTEM\ControlSet001\Services\IEEtwCollectorService" /f >nul 2>&1
 Reg delete "HKLM\TK_SYSTEM\ControlSet002\Services\IEEtwCollectorService" /f >nul 2>&1

 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet001\Control\Diagnostics\Performance" /v "DisableDiagnosticTracing" /t REG_DWORD /d "1" /f >nul
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet001\Control\Diagnostics\Performance\BootCKCLSettings" /v "Start" /t REG_DWORD /d "0" /f >nul
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet001\Control\Diagnostics\Performance\ShutdownCKCLSettings" /v "Start" /t REG_DWORD /d "0" /f >nul
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet002\Control\Diagnostics\Performance" /v "DisableDiagnosticTracing" /t REG_DWORD /d "1" /f >nul
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet002\Control\Diagnostics\Performance\BootCKCLSettings" /v "Start" /t REG_DWORD /d "0" /f >nul
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet002\Control\Diagnostics\Performance\ShutdownCKCLSettings" /v "Start" /t REG_DWORD /d "0" /f >nul
 
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet001\Services\WdiServiceHost" /v "Start" /t REG_DWORD /d "4" /f >nul
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet001\Services\WdiSystemHost" /v "Start" /t REG_DWORD /d "4" /f >nul
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet001\Services\DPS" /v "Start" /t REG_DWORD /d "4" /f >nul
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet002\Services\WdiServiceHost" /v "Start" /t REG_DWORD /d "4" /f >nul
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet002\Services\WdiSystemHost" /v "Start" /t REG_DWORD /d "4" /f >nul
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet002\Services\DPS" /v "Start" /t REG_DWORD /d "4" /f >nul

 Reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-Compat-Appraiser/Analytic" /f >nul 2>&1
 Reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-Compat-Appraiser/Operational" /f >nul 2>&1
 Reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Publishers\{442c11c5-304b-45a4-ae73-dc2194c4e876}" /f >nul 2>&1
 Reg delete "HKLM\TK_SYSTEM\ControlSet001\Control\WMI\Autologger\EventLog-Application\{442c11c5-304b-45a4-ae73-dc2194c4e876}" /f >nul 2>&1
 Reg delete "HKLM\TK_SYSTEM\ControlSet002\Control\WMI\Autologger\EventLog-Application\{442c11c5-304b-45a4-ae73-dc2194c4e876}" /f >nul 2>&1

 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\ClientTelemetry" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Appraiser" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\UpgradeExperienceIndicators" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\OneSettings" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\TelemetryController" /f >nul 2>&1

 del /q /f "%~dp0mount\1\Windows\Migration\WTR\CompatTelemetry.inf" >nul 2>&1
 rd /s /q "%~dp0mount\1\Windows\AppCompat" >nul 2>&1

 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f "%~dp0mount\1\Windows\System32\CompatTelRunner.exe"" >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f "%~dp0mount\1\Windows\System32\aitstatic.exe"" >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f "%~dp0mount\1\Windows\System32\appraiser.dll"" >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f "%~dp0mount\1\Windows\System32\devinv.dll"" >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f "%~dp0mount\1\Windows\System32\diagtrack.dll"" >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f "%~dp0mount\1\Windows\System32\acmigration.dll"" >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f "%~dp0mount\1\Windows\System32\invagent.dll"" >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f "%~dp0mount\1\Windows\System32\generaltel.dll"" >nul 2>&1

 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "rd /s /q "%~dp0mount\1\Windows\System32\CompatTel"" >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "rd /s /q "%~dp0mount\1\Windows\System32\appraiser"" >nul 2>&1
 
 type "%~dp0mount\1\Windows\winsxs\pending.xml" | find /i /v "-Telemetry" | find /i /v "-Inventory" | find /i /v "-Appraiser" > "%~dp0hotfixes\pending.tmp"
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "copy /b /y "%~dp0hotfixes\pending.tmp" "%~dp0mount\1\Windows\winsxs\pending.xml"" >nul

 Reg add "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\ClientTelemetry" /v DontRetryOnError /t REG_DWORD /d 1 /f >nul
 Reg add "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\ClientTelemetry" /v IsCensusDisabled /t REG_DWORD /d 1 /f >nul
 Reg add "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\ClientTelemetry" /v TaskEnableRun /t REG_DWORD /d 1 /f >nul

 reg add "HKLM\TK_SOFTWARE\Microsoft\DataCollection" /v "AllowTelemetry" /t REG_DWORD /d 0 /f > NUL
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v "AllowTelemetry" /t REG_DWORD /d 0 /f > NUL
 reg add "HKLM\TK_NTUSER\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v "AllowTelemetry" /t REG_DWORD /d 0 /f > NUL
 reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v "AllowTelemetry" /t REG_DWORD /d 0 /f > NUL

 REM Remove End of Support Notification
 type "%~dp0mount\1\Windows\winsxs\pending.xml" | find /i /v "-EOSNotify" > "%~dp0hotfixes\pending.tmp"
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "copy /b /y "%~dp0hotfixes\pending.tmp" "%~dp0mount\1\Windows\winsxs\pending.xml"" >nul
 
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f "%~dp0mount\1\Windows\Migration\WTR\EOSNotifyMig.inf"" >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f "%~dp0mount\1\Windows\System32\EOSNotify.exe"" >nul 2>&1

 REM Remove telemetry Tasks
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Application Experience\AitAgent" >nul 2>&1
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Application Experience\ProgramDataUpdater" >nul 2>&1
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask" >nul 2>&1
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip" >nul 2>&1
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Customer Experience Improvement Program\Consolidator" >nul 2>&1
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Customer Experience Improvement Program\OptinNotification" >nul 2>&1
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Maintenance\WinSAT" >nul 2>&1
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Diagnosis\Scheduled" >nul 2>&1
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\PerfTrack\BackgroundConfigSurveyor" >nul 2>&1

 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\Application Experience\AitAgent" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\Application Experience\ProgramDataUpdater" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\Customer Experience Improvement Program\Consolidator" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\Customer Experience Improvement Program\OptinNotification" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\Maintenance\WinSAT" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\Diagnosis\Scheduled" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\PerfTrack\BackgroundConfigSurveyor" /f >nul 2>&1

 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Plain\{A7C73732-9F11-4281-8D19-764D4EC9D94D}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{A7C73732-9F11-4281-8D19-764D4EC9D94D}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Plain\{AC4E5ACF-89F7-4220-BA21-81EE183975E2}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{AC4E5ACF-89F7-4220-BA21-81EE183975E2}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Plain\{47536D45-EEEC-4BDC-8183-A4DC1F8DA9E4}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{47536D45-EEEC-4BDC-8183-A4DC1F8DA9E4}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Plain\{FDD56C73-F0D5-41B6-B767-6EFFD7966428}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{FDD56C73-F0D5-41B6-B767-6EFFD7966428}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Plain\{C016366B-7126-46CA-B36B-592A3D95A60B}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{C016366B-7126-46CA-B36B-592A3D95A60B}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Plain\{DA41DE71-8431-42FB-9DB0-EB64A961DEAD}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{DA41DE71-8431-42FB-9DB0-EB64A961DEAD}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Plain\{BE669C13-8165-4536-96D0-6D6C39292AAE}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{BE669C13-8165-4536-96D0-6D6C39292AAE}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Plain\{B0CBAB43-44FC-469B-A4CE-87426761FDCE}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{B0CBAB43-44FC-469B-A4CE-87426761FDCE}" /f >nul 2>&1

 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Windows Error Reporting\QueueReporting" >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Logon\{D0250F3F-6480-484F-B719-42F659AC64D5}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{D0250F3F-6480-484F-B719-42F659AC64D5}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\Windows Error Reporting\QueueReporting" /f >nul 2>&1

 REM Disable Search Indexing
 if not "%DisableSearchIndexing%"=="0" (
  Reg delete "HKLM\TK_SYSTEM\ControlSet001\Services\WSearch" /f >nul 2>&1
  Reg delete "HKLM\TK_SYSTEM\ControlSet002\Services\WSearch" /f >nul 2>&1
  Reg delete "HKLM\TK_SYSTEM\ControlSet001\Services\WSearchIdxPi" /f >nul 2>&1
  Reg delete "HKLM\TK_SYSTEM\ControlSet002\Services\WSearchIdxPi" /f >nul 2>&1
  reg add "HKLM\TK_NTUSER\Software\Policies\Microsoft\Windows\Explorer" /v "DisableSearchBoxSuggestions" /t REG_DWORD /d 1 /f >nul
  reg add "HKLM\TK_NTUSER\Software\Microsoft\Windows\CurrentVersion\Explorer\InfoBarsDisabled" /v "ServerMSSNotInstalled" /t REG_DWORD /d 1 /f >nul
  reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v "PreventIndexingLowDiskSpaceMB" /t REG_DWORD /d 0x7fffffff /f >nul
  reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v "PreventIndexOnBattery" /t REG_DWORD /d 1 /f >nul
  reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v "PreventIndexingEmailAttachments" /t REG_DWORD /d 1 /f >nul
  reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v "PreventIndexingOfflineFiles" /t REG_DWORD /d 1 /f >nul
  reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v "PreventIndexingOutlook" /t REG_DWORD /d 1 /f >nul
  reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v "PreventIndexingPublicFolders" /t REG_DWORD /d 1 /f >nul
 )

 REM Disable WBEM logs
 reg add "HKLM\TK_SOFTWARE\Microsoft\WBEM\CIMOM" /v "Logging" /t REG_DWORD /d 0 /f >nul

 REM Disable CBS logging
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing" /v "EnableLog" /t REG_DWORD /d "0" /f >nul

 REM Disable prefetcher
 if not "%DisablePrefetcher%"=="0" (
  reg add "HKLM\TK_SYSTEM\ControlSet001\Control\Session Manager\Memory Management\PrefetchParameters" /f /v EnableSuperfetch /t REG_DWORD /d 0 >nul
  reg add "HKLM\TK_SYSTEM\ControlSet001\Control\Session Manager\Memory Management\PrefetchParameters" /f /v EnablePrefetcher /t REG_DWORD /d 0 >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Control\Session Manager\Memory Management\PrefetchParameters" /f /v EnableSuperfetch /t REG_DWORD /d 0 >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Control\Session Manager\Memory Management\PrefetchParameters" /f /v EnablePrefetcher /t REG_DWORD /d 0 >nul
  reg add "HKLM\TK_SYSTEM\ControlSet001\Services\SysMain" /v Start /t REG_DWORD /d 4 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Services\SysMain" /v Start /t REG_DWORD /d 4 /f >nul
 )

 REM Remove System Restore
 if not "%RemoveSR%"=="0" (
  reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore" /v "DisableSR" /t REG_DWORD /d 1 /f >nul
  reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore" /v "DisableConfig" /t REG_DWORD /d 1 /f >nul

  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\CLSID\{0D41EBA2-17EA-4B0D-9172-DBD2AE0CC97A}" /f  >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\CLSID\{0D41EBA2-17EA-4B0D-9172-DBD2AE0CC97A}" /f  >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\CLSID\{0D41EBA2-17EA-4B0D-9172-DBD2AE0CC97A}" /f  >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\CLSID\{883FF1FC-09E1-48e5-8E54-E2469ACB0CFD}" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\CLSID\{883FF1FC-09E1-48e5-8E54-E2469ACB0CFD}" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\CLSID\{883FF1FC-09E1-48e5-8E54-E2469ACB0CFD}" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\CLSID\{a47401f6-a8a6-40ea-9c29-b8f6026c98b8}" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\SrControl.SrControl" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\SrControl.SrControl.1" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\SrDrvWuHelper.SrDrvWuHelper" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\SrDrvWuHelper.SrDrvWuHelper.1" /f >nul 2>&1

  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f "%~dp0mount\1\Windows\PolicyDefinitions\SystemRestore.admx"" >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f /s "%~dp0mount\1\Windows\System32\rstrui.exe.mui"" >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f /s "%~dp0mount\1\Windows\System32\srcore.dll.mui"" >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f /s "%~dp0mount\1\Windows\System32\srrstr.dll.mui"" >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f "%~dp0mount\1\Windows\System32\rstrui.exe"" >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f "%~dp0mount\1\Windows\System32\srclient.dll"" >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f "%~dp0mount\1\Windows\System32\srcore.dll"" >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f "%~dp0mount\1\Windows\System32\srdelayed.exe"" >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f "%~dp0mount\1\Windows\System32\srhelper.dll"" >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f "%~dp0mount\1\Windows\System32\srrstr.dll"" >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f "%~dp0mount\1\Windows\System32\srwmi.dll"" >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f "%~dp0mount\1\Windows\System32\wbem\sr.mof"" >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f /s "%~dp0mount\1\Windows\sysWOW64\rstrui.exe.mui"" >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f /s "%~dp0mount\1\Windows\sysWOW64\srcore.dll.mui"" >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f "%~dp0mount\1\Windows\sysWOW64\srclient.dll"" >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f "%~dp0mount\1\Windows\sysWOW64\srdelayed.exe"" >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "del /q /f "%~dp0mount\1\Windows\sysWOW64\srhelper.dll"" >nul 2>&1

  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\App Management\WindowsFeatureCategories" /v "COMMONSTART/Programs/Accessories/System Tools/System Restore.lnk" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\App Management\WindowsFeatureCategories" /v "COMMONSTART/Programs/Accessories/System Tools/System Restore.lnk" /f >nul 2>&1

  del /q /f "%~dp0mount\1\ProgramData\Microsoft\Windows\Start Menu\Programs\Accessories\System Tools\System Restore.lnk" >nul 2>&1
  del /q /f /s "%~dp0mount\1\Windows\System32\wbem\sr.mfl" >nul 2>&1
  del /q /f /s "%~dp0mount\1\Windows\PolicyDefinitions\SystemRestore.adml" >nul 2>&1

  del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\SystemRestore\SR" >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Boot\{994C86AD-A929-4B2C-88A0-4E25A107A029}" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{994C86AD-A929-4B2C-88A0-4E25A107A029}" /f >nul 2>&1
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\SystemRestore\SR" /f >nul 2>&1
 
  type "%~dp0mount\1\Windows\winsxs\pending.xml" | find /i /v "-SystemRestore" > "%~dp0hotfixes\pending.tmp"
  "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "copy /b /y "%~dp0hotfixes\pending.tmp" "%~dp0mount\1\Windows\winsxs\pending.xml"" >nul
 )


 REM Remove unnecessary tasks

 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Autochk\Proxy" >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Boot\{D7B6E81D-3CF4-432C-84D2-24213F4316E6}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{D7B6E81D-3CF4-432C-84D2-24213F4316E6}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\Autochk" /f >nul 2>&1

 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Defrag\ScheduledDefrag" >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Plain\{5C0AEEEA-C154-45BE-8499-BEA5F11BAFF6}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{5C0AEEEA-C154-45BE-8499-BEA5F11BAFF6}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\Defrag\ScheduledDefrag" /f >nul 2>&1

 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector" >nul 2>&1
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticResolver" >nul 2>&1

 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Media Center\ActivateWindowsSearch" >nul 2>&1
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Media Center\ConfigureInternetTimeService" >nul 2>&1
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Media Center\DispatchRecoveryTasks" >nul 2>&1
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Media Center\ehDRMInit" >nul 2>&1
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Media Center\InstallPlayReady" >nul 2>&1
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Media Center\mcupdate" >nul 2>&1
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Media Center\MediaCenterRecoveryTask" >nul 2>&1
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Media Center\ObjectStoreRecoveryTask" >nul 2>&1
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Media Center\OCURActivate" >nul 2>&1
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Media Center\OCURDiscovery" >nul 2>&1
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Media Center\PBDADiscovery" >nul 2>&1
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Media Center\PBDADiscoveryW1" >nul 2>&1
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Media Center\PBDADiscoveryW2" >nul 2>&1
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Media Center\PeriodicScanRetry" >nul 2>&1
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Media Center\PvrRecoveryTask" >nul 2>&1
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Media Center\PvrScheduleTask" >nul 2>&1
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Media Center\RecordingRestart" >nul 2>&1
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Media Center\RegisterSearch" >nul 2>&1
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Media Center\ReindexSearchRoot" >nul 2>&1
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Media Center\SqlLiteRecoveryTask" >nul 2>&1
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Media Center\UpdateRecordPath" >nul 2>&1

 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\MemoryDiagnostic\CorruptionDetector" >nul 2>&1
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\MemoryDiagnostic\DecompressionFailureDetector" >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Plain\{CEE64558-E1A7-4D9D-80A7-2001912BE5B5}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{CEE64558-E1A7-4D9D-80A7-2001912BE5B5}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Plain\{FA2BC0A6-8D4B-458A-85C8-2B8C72487513}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{FA2BC0A6-8D4B-458A-85C8-2B8C72487513}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\MemoryDiagnostic\CorruptionDetector" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\MemoryDiagnostic\DecompressionFailureDetector" /f >nul 2>&1

 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\NetTrace\GatherNetworkInfo" >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Plain\{81540B9F-B5BF-47EB-9C95-BE195BF2C664}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{81540B9F-B5BF-47EB-9C95-BE195BF2C664}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\NetTrace\GatherNetworkInfo" /f >nul 2>&1

 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem" >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Plain\{FB3C354D-297A-4EB2-9B58-090F6361906B}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{FB3C354D-297A-4EB2-9B58-090F6361906B}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem" /f >nul 2>&1

 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\RAC\RacTask" >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Plain\{EACA24FF-236C-401D-A1E7-B3D5267B8A50}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{EACA24FF-236C-401D-A1E7-B3D5267B8A50}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\RAC\RacTask" /f >nul 2>&1

 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Registry\RegIdleBackup" >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Plain\{CA4B8FF2-A4D2-4D88-A52E-3A5BDAF7F56E}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{CA4B8FF2-A4D2-4D88-A52E-3A5BDAF7F56E}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\Registry\RegIdleBackup" /f >nul 2>&1

 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\SoftwareProtectionPlatform\SvcRestartTask" >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Plain\{DD9F510C-95F4-499A-90C8-BAC5BC372FF4}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{DD9F510C-95F4-499A-90C8-BAC5BC372FF4}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\SoftwareProtectionPlatform\SvcRestartTask" /f >nul 2>&1

 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\Windows Media Sharing\UpdateLibrary" >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Plain\{753C47AE-EC5E-44B3-95A9-2C8E553F0E39}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{753C47AE-EC5E-44B3-95A9-2C8E553F0E39}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\Windows Media Sharing" /f >nul 2>&1

 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\WindowsBackup\ConfigNotification" >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Plain\{2F57269B-1E09-4E2D-AB1E-B0FDAC7D279C}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{2F57269B-1E09-4E2D-AB1E-B0FDAC7D279C}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\WindowsBackup\ConfigNotification" /f >nul 2>&1
 
 del /q /f "%~dp0mount\1\Windows\System32\Tasks\Microsoft\Windows\WDI\ResolutionHost" >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Plain\{9435F817-FED2-454E-88CD-7F78FDA62C48}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{9435F817-FED2-454E-88CD-7F78FDA62C48}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\WDI\ResolutionHost" /f >nul 2>&1


 REM Remove telemetry Logs
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SYSTEM\ControlSet001\Control\WMI\AutoLogger\SQMLogger" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SYSTEM\ControlSet002\Control\WMI\AutoLogger\SQMLogger" /f >nul 2>&1
 reg delete "HKLM\TK_SYSTEM\ControlSet001\Control\WMI\AutoLogger\AutoLogger-Diagtrack-Listener" /f >nul 2>&1
 reg delete "HKLM\TK_SYSTEM\ControlSet002\Control\WMI\AutoLogger\AutoLogger-Diagtrack-Listener" /f >nul 2>&1


 REM Disable Event Logs
 if not "%DisableEventLogs%"=="0" (
  reg add "HKLM\TK_SYSTEM\ControlSet001\Control\WMI\AutoLogger\EventLog-Application" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet001\Control\WMI\AutoLogger\EventLog-System" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet001\Control\WMI\AutoLogger\EventLog-Security" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Control\WMI\AutoLogger\EventLog-Application" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Control\WMI\AutoLogger\EventLog-System" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Control\WMI\AutoLogger\EventLog-Security" /v "Start" /t REG_DWORD /d 0 /f >nul
 )


 REM Disable other Logs
  reg add "HKLM\TK_SYSTEM\ControlSet001\Control\WMI\AutoLogger\AITEventLog" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet001\Control\WMI\AutoLogger\Audio" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet001\Control\WMI\AutoLogger\Circular Kernel Context Logger" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet001\Control\WMI\AutoLogger\DiagLog" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet001\Control\WMI\AutoLogger\Microsoft-Windows-Setup" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet001\Control\WMI\AutoLogger\NBSMBLOGGER" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet001\Control\WMI\AutoLogger\NtfsLog" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet001\Control\WMI\AutoLogger\PEAuthLog" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet001\Control\WMI\AutoLogger\RAC_PS" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet001\Control\WMI\AutoLogger\RdrLog" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet001\Control\WMI\AutoLogger\ReadyBoot" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet001\Control\WMI\AutoLogger\TCPIPLOGGER" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet001\Control\WMI\AutoLogger\Tpm" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet001\Control\WMI\AutoLogger\UBPM" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet001\Control\WMI\AutoLogger\WdiContextLog" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet001\Control\WMI\AutoLogger\WFP-IPsec Trace" /v "Start" /t REG_DWORD /d 0 /f >nul

  reg add "HKLM\TK_SYSTEM\ControlSet002\Control\WMI\AutoLogger\AITEventLog" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Control\WMI\AutoLogger\Audio" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Control\WMI\AutoLogger\Circular Kernel Context Logger" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Control\WMI\AutoLogger\DiagLog" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Control\WMI\AutoLogger\Microsoft-Windows-Setup" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Control\WMI\AutoLogger\NBSMBLOGGER" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Control\WMI\AutoLogger\NtfsLog" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Control\WMI\AutoLogger\PEAuthLog" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Control\WMI\AutoLogger\RAC_PS" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Control\WMI\AutoLogger\RdrLog" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Control\WMI\AutoLogger\ReadyBoot" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Control\WMI\AutoLogger\TCPIPLOGGER" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Control\WMI\AutoLogger\Tpm" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Control\WMI\AutoLogger\UBPM" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Control\WMI\AutoLogger\WdiContextLog" /v "Start" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Control\WMI\AutoLogger\WFP-IPsec Trace" /v "Start" /t REG_DWORD /d 0 /f >nul

 
 REM Completely remove Action Center and Windows Security Center
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\AppID\{E9495B87-D950-4ab5-87A5-FF6D70BF3E90}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\CLSID\{E9495B87-D950-4ab5-87A5-FF6D70BF3E90}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\AppID\{E9495B87-D950-4ab5-87A5-FF6D70BF3E90}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\CLSID\{E9495B87-D950-4ab5-87A5-FF6D70BF3E90}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\AppID\{E9495B87-D950-4ab5-87A5-FF6D70BF3E90}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\CLSID\{E9495B87-D950-4ab5-87A5-FF6D70BF3E90}" /f >nul 2>&1

 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\CLSID\{49ACAA99-F009-4524-9D2A-D751C9A38F60}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Interface\{49ACAA99-F009-4524-9D2A-D751C9A38F60}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\CLSID\{49ACAA99-F009-4524-9D2A-D751C9A38F60}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\Interface\{49ACAA99-F009-4524-9D2A-D751C9A38F60}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\CLSID\{49ACAA99-F009-4524-9D2A-D751C9A38F60}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\Interface\{49ACAA99-F009-4524-9D2A-D751C9A38F60}" /f >nul 2>&1


 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\TypeLib\{C2A2B169-4052-4037-88D9-E274AF31C6F7}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\TypeLib\{C2A2B169-4052-4037-88D9-E274AF31C6F7}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\TypeLib\{C2A2B169-4052-4037-88D9-E274AF31C6F7}" /f >nul 2>&1


 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\CLSID\{BB64F8A7-BEE7-4E1A-AB8D-7D8273F7FDB6}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\CLSID\{BB64F8A7-BEE7-4E1A-AB8D-7D8273F7FDB6}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\explorer\ControlPanel\NameSpace\{BB64F8A7-BEE7-4E1A-AB8D-7D8273F7FDB6}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\explorer\ControlPanel\NameSpace\{BB64F8A7-BEE7-4E1A-AB8D-7D8273F7FDB6}" /f >nul 2>&1


 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\AppID\{8D26D9AA-5DA8-4b95-949A-B74954A229A6}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\CLSID\{8D26D9AA-5DA8-4b95-949A-B74954A229A6}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\AppID\{8D26D9AA-5DA8-4b95-949A-B74954A229A6}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\CLSID\{8D26D9AA-5DA8-4b95-949A-B74954A229A6}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\CLSID\{8D26D9AA-5DA8-4b95-949A-B74954A229A6}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\AppID\{8D26D9AA-5DA8-4b95-949A-B74954A229A6}" /f >nul 2>&1

 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\CLSID\{01afc156-f2eb-4c1c-a722-8550417d396f}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Interface\{01afc156-f2eb-4c1c-a722-8550417d396f}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\CLSID\{01afc156-f2eb-4c1c-a722-8550417d396f}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\Interface\{01afc156-f2eb-4c1c-a722-8550417d396f}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\CLSID\{01afc156-f2eb-4c1c-a722-8550417d396f}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\Interface\{01afc156-f2eb-4c1c-a722-8550417d396f}" /f >nul 2>&1

 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Interface\{014a1425-828b-482a-a386-5763b23531c3}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Interface\{0acabbb8-8f37-4605-9d41-eec1c33eeb95}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Interface\{0cc6fe25-a88b-480d-956a-a9a20bd2c65a}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Interface\{1cf5e433-3cf8-498e-8b5a-f47e23200e07}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Interface\{3d2eafc0-96d0-4925-9f7d-ff80b168f243}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Interface\{418ee892-56f0-4c3b-9238-696ba0cef799}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Interface\{58d879fe-5b40-46aa-ab68-d146ff6a68a0}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Interface\{7cbc33db-7a53-45c3-a0cc-610292bd7b9e}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Interface\{8025d477-47d3-449c-9350-c676140ee829}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Interface\{824f0d64-069c-4383-9107-f18fc40c3ca6}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Interface\{8db6ae56-7ea1-421c-9c22-d3247c12c6c4}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Interface\{B066DDE3-445D-45dc-BF2A-BC7BAA74C5C5}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Interface\{b387c51b-7fe4-4252-8cd4-585592b4dc7e}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Interface\{db62c52c-dbae-476c-aeac-fa9966e85326}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Interface\{e90aad8b-7f0c-480d-b33e-16779c4cf59d}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Interface\{FAE9CE59-7621-4208-8BC3-2ACECD58FED2}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\Interface\{014a1425-828b-482a-a386-5763b23531c3}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\Interface\{0acabbb8-8f37-4605-9d41-eec1c33eeb95}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\Interface\{0cc6fe25-a88b-480d-956a-a9a20bd2c65a}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\Interface\{1cf5e433-3cf8-498e-8b5a-f47e23200e07}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\Interface\{3d2eafc0-96d0-4925-9f7d-ff80b168f243}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\Interface\{418ee892-56f0-4c3b-9238-696ba0cef799}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\Interface\{58d879fe-5b40-46aa-ab68-d146ff6a68a0}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\Interface\{7cbc33db-7a53-45c3-a0cc-610292bd7b9e}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\Interface\{8025d477-47d3-449c-9350-c676140ee829}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\Interface\{824f0d64-069c-4383-9107-f18fc40c3ca6}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\Interface\{8db6ae56-7ea1-421c-9c22-d3247c12c6c4}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\Interface\{B066DDE3-445D-45dc-BF2A-BC7BAA74C5C5}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\Interface\{b387c51b-7fe4-4252-8cd4-585592b4dc7e}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\Interface\{db62c52c-dbae-476c-aeac-fa9966e85326}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\Interface\{e90aad8b-7f0c-480d-b33e-16779c4cf59d}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\Interface\{FAE9CE59-7621-4208-8BC3-2ACECD58FED2}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\Interface\{014a1425-828b-482a-a386-5763b23531c3}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\Interface\{0acabbb8-8f37-4605-9d41-eec1c33eeb95}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\Interface\{0cc6fe25-a88b-480d-956a-a9a20bd2c65a}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\Interface\{1cf5e433-3cf8-498e-8b5a-f47e23200e07}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\Interface\{3d2eafc0-96d0-4925-9f7d-ff80b168f243}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\Interface\{418ee892-56f0-4c3b-9238-696ba0cef799}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\Interface\{58d879fe-5b40-46aa-ab68-d146ff6a68a0}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\Interface\{7cbc33db-7a53-45c3-a0cc-610292bd7b9e}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\Interface\{8025d477-47d3-449c-9350-c676140ee829}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\Interface\{824f0d64-069c-4383-9107-f18fc40c3ca6}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\Interface\{8db6ae56-7ea1-421c-9c22-d3247c12c6c4}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\Interface\{B066DDE3-445D-45dc-BF2A-BC7BAA74C5C5}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\Interface\{b387c51b-7fe4-4252-8cd4-585592b4dc7e}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\Interface\{db62c52c-dbae-476c-aeac-fa9966e85326}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\Interface\{e90aad8b-7f0c-480d-b33e-16779c4cf59d}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\Interface\{FAE9CE59-7621-4208-8BC3-2ACECD58FED2}" /f >nul 2>&1

 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\CLSID\{a3b3c46c-05d8-429b-bf66-87068b4ce563}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\CLSID\{a3b3c46c-05d8-429b-bf66-87068b4ce563}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\CLSID\{a3b3c46c-05d8-429b-bf66-87068b4ce563}" /f >nul 2>&1


 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\CLSID\{F56F6FDD-AA9D-4618-A949-C1B91AF43B1A}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\CLSID\{F56F6FDD-AA9D-4618-A949-C1B91AF43B1A}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\CLSID\{F56F6FDD-AA9D-4618-A949-C1B91AF43B1A}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ShellServiceObjects\{F56F6FDD-AA9D-4618-A949-C1B91AF43B1A}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\explorer\ShellServiceObjects\{F56F6FDD-AA9D-4618-A949-C1B91AF43B1A}" /f >nul 2>&1

 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\CLSID\{05F3561D-0358-4687-8ACD-A34D24C488DF}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\CLSID\{05F3561D-0358-4687-8ACD-A34D24C488DF}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\CLSID\{05F3561D-0358-4687-8ACD-A34D24C488DF}" /f >nul 2>&1

 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\CLSID\{2C673043-FC2E-4d67-8920-517D24DEBD2C}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Classes\Wow6432Node\CLSID\{2C673043-FC2E-4d67-8920-517D24DEBD2C}" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Classes\CLSID\{2C673043-FC2E-4d67-8920-517D24DEBD2C}" /f >nul 2>&1


 reg delete "HKLM\TK_SYSTEM\ControlSet001\services\wscsvc" /f >nul 2>&1
 reg delete "HKLM\TK_SYSTEM\ControlSet002\services\wscsvc" /f >nul 2>&1

 reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Publishers\{5857d6ca-9732-4454-809b-2a87b70881f8}" /f >nul 2>&1
 reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-WSC-SRV/Diagnostic" /f >nul 2>&1

 reg delete "HKLM\TK_SYSTEM\ControlSet001\Control\WMI\Autologger\EventLog-System\{01979c6a-42fa-414c-b8aa-eee2c8202018}" /f >nul 2>&1
 reg delete "HKLM\TK_SYSTEM\ControlSet002\Control\WMI\Autologger\EventLog-System\{01979c6a-42fa-414c-b8aa-eee2c8202018}" /f >nul 2>&1
 reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Publishers\{01979c6a-42fa-414c-b8aa-eee2c8202018}" /f >nul 2>&1
 reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-WindowsBackup/ActionCenter" /f >nul 2>&1

 reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Publishers\{588c5c5a-ffc5-44a2-9a7f-d5e8dbe6efd7}" /f >nul 2>&1
 reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-HealthCenter/Debug" /f >nul 2>&1
 reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-HealthCenter/Performance" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SYSTEM\ControlSet001\Control\WDI\Scenarios\{fd5aa730-b53f-4b39-84e5-cb4303621d74}\Instrumentation\{588c5c5a-ffc5-44a2-9a7f-d5e8dbe6efd7};*" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SYSTEM\ControlSet002\Control\WDI\Scenarios\{fd5aa730-b53f-4b39-84e5-cb4303621d74}\Instrumentation\{588c5c5a-ffc5-44a2-9a7f-d5e8dbe6efd7};*" /f >nul 2>&1

 reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Publishers\{959f1fac-7ca8-4ed1-89dc-cdfa7e093cb0}" /f >nul 2>&1
 reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-HealthCenterCPL/Performance" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SYSTEM\ControlSet001\Control\WDI\Scenarios\{fd5aa730-b53f-4b39-84e5-cb4303621d74}\Instrumentation\{959f1fac-7ca8-4ed1-89dc-cdfa7e093cb0};*" /f >nul 2>&1
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg delete "HKLM\TK_SYSTEM\ControlSet002\Control\WDI\Scenarios\{fd5aa730-b53f-4b39-84e5-cb4303621d74}\Instrumentation\{959f1fac-7ca8-4ed1-89dc-cdfa7e093cb0};*" /f >nul 2>&1

 type "%~dp0mount\1\Windows\winsxs\pending.xml" | find /i /v "-Securitycenter" > "%~dp0hotfixes\pending.tmp"
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "copy /b /y "%~dp0hotfixes\pending.tmp" "%~dp0mount\1\Windows\winsxs\pending.xml"" >nul


 REM Disable IPv6 Depricated Tunneling Services
 Reg add "HKLM\TK_SYSTEM\ControlSet001\Services\TCPIP6\Parameters" /v "DisabledComponents" /t REG_DWORD /d "1" /f >nul
 Reg add "HKLM\TK_SYSTEM\ControlSet002\Services\TCPIP6\Parameters" /v "DisabledComponents" /t REG_DWORD /d "1" /f >nul
 Reg add "HKLM\TK_SYSTEM\ControlSet001\Services\iphlpsvc" /v "Start" /t REG_DWORD /d "4" /f >nul
 Reg add "HKLM\TK_SYSTEM\ControlSet002\Services\iphlpsvc" /v "Start" /t REG_DWORD /d "4" /f >nul

 REM Disable Meltdown and Spectre fixes
 reg add "HKLM\TK_SYSTEM\ControlSet001\Control\Session Manager\Memory Management" /v FeatureSettingsOverride /t REG_DWORD /d 3 /f >nul
 reg add "HKLM\TK_SYSTEM\ControlSet001\Control\Session Manager\Memory Management" /v FeatureSettingsOverrideMask /t REG_DWORD /d 3 /f >nul
 reg add "HKLM\TK_SYSTEM\ControlSet002\Control\Session Manager\Memory Management" /v FeatureSettingsOverride /t REG_DWORD /d 3 /f >nul
 reg add "HKLM\TK_SYSTEM\ControlSet002\Control\Session Manager\Memory Management" /v FeatureSettingsOverrideMask /t REG_DWORD /d 3 /f >nul
 
 REM Disable AutoPlay for other drives than CD/DVD - for security
 reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "HonorAutoRunSetting" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "HonorAutoRunSetting" /t REG_DWORD /d 1 /f >nul
 if "%DisableCDAutoPlay%"=="0" (
  reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoDriveTypeAutoRun" /t REG_DWORD /d 223 /f >nul
  reg add "HKLM\TK_NTUSER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoDriveTypeAutoRun" /t REG_DWORD /d 223 /f >nul
 )
 if not "%DisableCDAutoPlay%"=="0" (
  reg add "HKLM\TK_SYSTEM\ControlSet001\Services\Cdrom" /v "AutoRun" /t REG_DWORD /d "0" /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Services\Cdrom" /v "AutoRun" /t REG_DWORD /d "0" /f >nul
  reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoDriveTypeAutoRun" /t REG_DWORD /d 255 /f >nul
  reg add "HKLM\TK_NTUSER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoDriveTypeAutoRun" /t REG_DWORD /d 255 /f >nul
 )


 REM Show "My Computer" on Desktop
 reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu" /v "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" /v "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\explorer\HideDesktopIcons\ClassicStartMenu" /v "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\explorer\HideDesktopIcons\NewStartPanel" /v "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu" /v "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" /v "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" /t REG_DWORD /d 0 /f >nul

 REM Disable Animations
 reg add "HKLM\TK_DEFAULT\Control Panel\Desktop" /v "UserPreferencesMask" /t REG_BINARY /d 9012078010000000 /f >nul
 reg add "HKLM\TK_DEFAULT\Control Panel\Desktop\WindowMetrics" /v "MinAnimate" /t REG_SZ /d "0" /f >nul
 reg add "HKLM\TK_NTUSER\Control Panel\Desktop" /v "UserPreferencesMask" /t REG_BINARY /d 9012078010000000 /f >nul
 reg add "HKLM\TK_NTUSER\Control Panel\Desktop\WindowMetrics" /v "MinAnimate" /t REG_SZ /d "0" /f >nul
 reg add "HKLM\TK_NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarAnimations" /t REG_DWORD /d 0 /f >nul


 REM Disable legacy PC speaker sound service which is as old as 1980 era
 reg add "HKLM\TK_SYSTEM\ControlSet001\Services\Beep" /v Start /t REG_DWORD /d 4 /f >nul
 reg add "HKLM\TK_SYSTEM\ControlSet002\Services\Beep" /v Start /t REG_DWORD /d 4 /f >nul

 REM Disable Sounds and Beeps
 reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\BootAnimation" /v DisableStartupSound /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Control Panel\Sound" /v "Beep" /t REG_SZ /d "no" /f >nul
 reg add "HKLM\TK_NTUSER\Control Panel\Sound" /v "ExtendedSounds" /t REG_SZ /d "no" /f >nul
 reg add "HKLM\TK_NTUSER\AppEvents\Schemes" /ve /t REG_SZ /d ".None" /f >nul
 for /f "tokens=1 delims=" %%a in ('reg query "HKLM\TK_NTUSER\AppEvents\Schemes\Apps" 2^>nul ^| find /i "\Schemes\"') do (
  for /f "tokens=1 delims=" %%b in ('reg query "%%a" 2^>nul ^| find /i "%%a\"') do (
   for /f "tokens=1 delims=" %%c in ('reg query "%%b" /e /k /f ".Current" 2^>nul ^| find /i "%%b\.Current"') do (
    reg add "%%c" /ve /t REG_SZ /d "" /f >nul
   )
  ) 
 )

 REM Various system tweaks
 reg add "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\AeDebug" /v "Auto" /t REG_SZ /d "0" /f >nul
 if "%ImageArchitecture%"=="x64" reg add "HKLM\TK_SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\AeDebug" /v "Auto" /t REG_SZ /d "0" /f >nul

 reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\OptimalLayout" /v "EnableAutoLayout" /t REG_DWORD /d 0 /f >nul

 reg add "HKLM\TK_SYSTEM\ControlSet001\Control\FileSystem" /v NtfsDisableLastAccessUpdate /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_SYSTEM\ControlSet002\Control\FileSystem" /v NtfsDisableLastAccessUpdate /t REG_DWORD /d 1 /f >nul

 reg add "HKLM\TK_SYSTEM\ControlSet001\Control\Print\Providers" /v EventLog /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SYSTEM\ControlSet002\Control\Print\Providers" /v EventLog /t REG_DWORD /d 0 /f >nul

 reg add "HKLM\TK_SYSTEM\ControlSet001\Control\CrashControl" /v CrashDumpEnabled /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SYSTEM\ControlSet001\Control\CrashControl" /v LogEvent /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SYSTEM\ControlSet001\Control\CrashControl" /v SendAlert /t REG_DWORD /d 0 /f >nul

 reg add "HKLM\TK_SYSTEM\ControlSet002\Control\CrashControl" /v CrashDumpEnabled /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SYSTEM\ControlSet002\Control\CrashControl" /v LogEvent /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SYSTEM\ControlSet002\Control\CrashControl" /v SendAlert /t REG_DWORD /d 0 /f >nul

 reg add "HKLM\TK_SYSTEM\ControlSet001\Control\Session Manager" /v AutoChkTimeOut /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_SYSTEM\ControlSet002\Control\Session Manager" /v AutoChkTimeOut /t REG_DWORD /d 1 /f >nul
 
 reg add "HKLM\TK_SYSTEM\ControlSet001\Control\Session Manager\Environment" /v DEVMGR_SHOW_DETAILS /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_SYSTEM\ControlSet001\Control\Session Manager\Environment" /v DEVMGR_SHOW_NONPRESENT_DEVICES /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_SYSTEM\ControlSet002\Control\Session Manager\Environment" /v DEVMGR_SHOW_DETAILS /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_SYSTEM\ControlSet002\Control\Session Manager\Environment" /v DEVMGR_SHOW_NONPRESENT_DEVICES /t REG_DWORD /d 1 /f >nul

 REM Disable hibernation
 reg add "HKLM\TK_SYSTEM\ControlSet001\Control\Power" /v HibernateEnabled /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SYSTEM\ControlSet002\Control\Power" /v HibernateEnabled /t REG_DWORD /d 0 /f >nul

 REM Disable Screen Off timer for Balanced and High Performance power schemes, when PC is connected to power source
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet001\Control\Power\User\PowerSchemes\381b4222-f694-41f0-9685-ff5bb260df2e\7516b95f-f776-4464-8c53-06167f40cc99\3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e" /v ACSettingIndex /t REG_DWORD /d 0 /f >nul
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet001\Control\Power\User\PowerSchemes\8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c\7516b95f-f776-4464-8c53-06167f40cc99\3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e" /v ACSettingIndex /t REG_DWORD /d 0 /f >nul
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet002\Control\Power\User\PowerSchemes\381b4222-f694-41f0-9685-ff5bb260df2e\7516b95f-f776-4464-8c53-06167f40cc99\3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e" /v ACSettingIndex /t REG_DWORD /d 0 /f >nul
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet002\Control\Power\User\PowerSchemes\8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c\7516b95f-f776-4464-8c53-06167f40cc99\3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e" /v ACSettingIndex /t REG_DWORD /d 0 /f >nul

 REM Disable USB AutoSuspend for Balanced and High Performance power schemes
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet001\Control\Power\User\PowerSchemes\381b4222-f694-41f0-9685-ff5bb260df2e\2a737441-1930-4402-8d77-b2bebba308a3\48e6b7a6-50f5-4782-a5d4-53bb8f07e226" /v ACSettingIndex /t REG_DWORD /d 0 /f >nul
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet001\Control\Power\User\PowerSchemes\381b4222-f694-41f0-9685-ff5bb260df2e\2a737441-1930-4402-8d77-b2bebba308a3\48e6b7a6-50f5-4782-a5d4-53bb8f07e226" /v DCSettingIndex /t REG_DWORD /d 0 /f >nul
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet001\Control\Power\User\PowerSchemes\8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c\2a737441-1930-4402-8d77-b2bebba308a3\48e6b7a6-50f5-4782-a5d4-53bb8f07e226" /v ACSettingIndex /t REG_DWORD /d 0 /f >nul
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet001\Control\Power\User\PowerSchemes\8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c\2a737441-1930-4402-8d77-b2bebba308a3\48e6b7a6-50f5-4782-a5d4-53bb8f07e226" /v DCSettingIndex /t REG_DWORD /d 0 /f >nul
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet002\Control\Power\User\PowerSchemes\381b4222-f694-41f0-9685-ff5bb260df2e\2a737441-1930-4402-8d77-b2bebba308a3\48e6b7a6-50f5-4782-a5d4-53bb8f07e226" /v ACSettingIndex /t REG_DWORD /d 0 /f >nul
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet002\Control\Power\User\PowerSchemes\381b4222-f694-41f0-9685-ff5bb260df2e\2a737441-1930-4402-8d77-b2bebba308a3\48e6b7a6-50f5-4782-a5d4-53bb8f07e226" /v DCSettingIndex /t REG_DWORD /d 0 /f >nul
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet002\Control\Power\User\PowerSchemes\8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c\2a737441-1930-4402-8d77-b2bebba308a3\48e6b7a6-50f5-4782-a5d4-53bb8f07e226" /v ACSettingIndex /t REG_DWORD /d 0 /f >nul
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet002\Control\Power\User\PowerSchemes\8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c\2a737441-1930-4402-8d77-b2bebba308a3\48e6b7a6-50f5-4782-a5d4-53bb8f07e226" /v DCSettingIndex /t REG_DWORD /d 0 /f >nul

 REM Disable idle Hard Disk auto power off for Balanced and High Performance power schemes
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet001\Control\Power\User\PowerSchemes\381b4222-f694-41f0-9685-ff5bb260df2e\0012ee47-9041-4b5d-9b77-535fba8b1442\6738e2c4-e8a5-4a42-b16a-e040e769756e" /v ACSettingIndex /t REG_DWORD /d 0 /f >nul
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet001\Control\Power\User\PowerSchemes\381b4222-f694-41f0-9685-ff5bb260df2e\0012ee47-9041-4b5d-9b77-535fba8b1442\6738e2c4-e8a5-4a42-b16a-e040e769756e" /v DCSettingIndex /t REG_DWORD /d 0 /f >nul
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet001\Control\Power\User\PowerSchemes\8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c\0012ee47-9041-4b5d-9b77-535fba8b1442\6738e2c4-e8a5-4a42-b16a-e040e769756e" /v ACSettingIndex /t REG_DWORD /d 0 /f >nul
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet001\Control\Power\User\PowerSchemes\8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c\0012ee47-9041-4b5d-9b77-535fba8b1442\6738e2c4-e8a5-4a42-b16a-e040e769756e" /v DCSettingIndex /t REG_DWORD /d 0 /f >nul
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet002\Control\Power\User\PowerSchemes\381b4222-f694-41f0-9685-ff5bb260df2e\0012ee47-9041-4b5d-9b77-535fba8b1442\6738e2c4-e8a5-4a42-b16a-e040e769756e" /v ACSettingIndex /t REG_DWORD /d 0 /f >nul
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet002\Control\Power\User\PowerSchemes\381b4222-f694-41f0-9685-ff5bb260df2e\0012ee47-9041-4b5d-9b77-535fba8b1442\6738e2c4-e8a5-4a42-b16a-e040e769756e" /v DCSettingIndex /t REG_DWORD /d 0 /f >nul
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet002\Control\Power\User\PowerSchemes\8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c\0012ee47-9041-4b5d-9b77-535fba8b1442\6738e2c4-e8a5-4a42-b16a-e040e769756e" /v ACSettingIndex /t REG_DWORD /d 0 /f >nul
 "%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait reg add "HKLM\TK_SYSTEM\ControlSet002\Control\Power\User\PowerSchemes\8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c\0012ee47-9041-4b5d-9b77-535fba8b1442\6738e2c4-e8a5-4a42-b16a-e040e769756e" /v DCSettingIndex /t REG_DWORD /d 0 /f >nul

 REM Tweaks to disable SMBv1
 if not "%DisableSMBv1%"=="0" (
  reg add "HKLM\TK_SYSTEM\ControlSet001\services\LanmanWorkstation" /v DependOnService /t REG_MULTI_SZ /d Bowser\0MRxSmb20\0NSI /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\services\LanmanWorkstation" /v DependOnService /t REG_MULTI_SZ /d Bowser\0MRxSmb20\0NSI /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet001\Services\mrxsmb10" /v Start /t REG_DWORD /d 4 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Services\mrxsmb10" /v Start /t REG_DWORD /d 4 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet001\Services\lanmanserver\parameters" /v SMB1 /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Services\lanmanserver\parameters" /v SMB1 /t REG_DWORD /d 0 /f >nul
 )
 
 REM Tweaks to disable Autoshare Disks
 reg add "HKLM\TK_SYSTEM\ControlSet001\Services\lanmanserver\parameters" /v AutoShareWks /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SYSTEM\ControlSet002\Services\lanmanserver\parameters" /v AutoShareWks /t REG_DWORD /d 0 /f >nul

 REM Disable Net Crawling
 reg add "HKLM\TK_NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "NoNetCrawling" /t REG_DWORD /d 1 /f >nul

 REM Disable UAC on Shared Foldes which sometimes causes problems
 reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 1 /f >nul

 REM IE11 Tweaks
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Internet Explorer\Main" /v "Start Page" /t REG_SZ /d "about:blank" /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Internet Explorer\Main" /v "Search Page" /t REG_SZ /d "https://www.google.com/" /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Internet Explorer\Main" /v "SmoothScroll" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Internet Explorer\Main" /v "Check_Associations" /t REG_SZ /d "no" /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Internet Explorer\TabbedBrowsing" /v "WarnOnClose" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Internet Explorer\TabbedBrowsing" /v "OpenAllHomePages" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Internet Explorer\TabbedBrowsing" /v "Groups" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Internet Explorer\TabbedBrowsing" /v "NewTabPageShow" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Internet Explorer\TabbedBrowsing" /v "PopupsUseNewWindow" /t REG_DWORD /d 0 /f >nul

 reg add "HKLM\TK_NTUSER\Software\Microsoft\Internet Explorer\Main" /v "Disable Script Debugger" /t REG_SZ /d "yes" /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Internet Explorer\Main" /v "Show image placeholders" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Internet Explorer\Main" /v "Enable AutoImageResize" /t REG_SZ /d "no" /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Internet Explorer\Main" /v "NotifyDownloadComplete" /t REG_SZ /d "no" /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Internet Explorer\Download" /v "CheckExeSignatures" /t REG_SZ /d "no" /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Internet Explorer\Download" /v "RunInvalidSignatures" /t REG_DWORD /d 1 /f >nul

 reg add "HKLM\TK_NTUSER\Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_LOCALMACHINE_LOCKDOWN" /v "iexplore.exe" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_LOCALMACHINE_LOCKDOWN\Settings" /v "LOCALMACHINE_CD_UNLOCK" /t REG_DWORD /d 1 /f >nul

 reg add "HKLM\TK_NTUSER\Software\Microsoft\Internet Explorer\Main" /v "Use FormSuggest" /t REG_SZ /d "no" /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Internet Explorer\Main" /v "FormSuggest Passwords" /t REG_SZ /d "no" /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Internet Explorer\Main" /v "FormSuggest PW Ask" /t REG_SZ /d "no" /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Internet Explorer\DomainSuggestion" /v "Enabled" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Internet Explorer\IntelliForms" /v "AskUser" /t REG_DWORD /d 0 /f >nul

 reg add "HKLM\TK_NTUSER\Software\Microsoft\Internet Explorer\New Windows" /v "PlaySound" /t REG_DWORD /d 0 /f >nul

 reg add "HKLM\TK_NTUSER\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v "EnableNegotiate" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v "EmailName" /t REG_SZ /d "anonymous@qjz9zk.org" /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v "MigrateProxy" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v "ProxyEnable" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v "PrivDiscUiShown" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v "WarnOnPost" /t REG_BINARY /d 00000000 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v "WarnOnZoneCrossing" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v "CertificateRevocation" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Windows\CurrentVersion\WinTrust\Trust Providers\Software Publishing" /v "State" /t REG_DWORD /d 0x23e00 /f >nul
 
 REM Disable AutoSuggest in Explorer address bar
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoComplete" /v "AutoSuggest " /t REG_SZ /d "no" /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoComplete" /v "Append Completion" /t REG_SZ /d "no" /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Internet Explorer\AutoComplete" /v "Append Completion" /t REG_SZ /d "no" /f >nul

 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Internet Explorer\Main" /v "DisableFirstRunCustomize" /t REG_DWORD /d 1 /f >nul

 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Internet Explorer" /v "AllowServicePoweredQSA" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Internet Explorer\Geolocation" /v "PolicyDisableGeolocation" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Internet Explorer\Feeds" /v "DisableFeedPane" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Internet Explorer\Feeds" /v "BackgroundSyncStatus" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Internet Explorer\Feed Discovery" /v "Enabled" /t REG_DWORD /d 0 /f >nul

 reg add "HKLM\TK_NTUSER\Software\Microsoft\Internet Explorer\Main\WindowsSearch" /v "EnabledScopes" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Explorer\AutoComplete" /v "AutoSuggest" /t REG_SZ /d "no" /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Internet Explorer\VersionManager" /v "DownloadVersionList" /t REG_DWORD /d 0 /f >nul

 reg add "HKLM\TK_SOFTWARE\Microsoft\Internet Explorer\Main" /v "Start Page" /t REG_SZ /d "about:blank" /f >nul
 reg add "HKLM\TK_SOFTWARE\Microsoft\Internet Explorer\Main" /v "Search Page" /t REG_SZ /d "https://www.google.com/" /f >nul
 reg add "HKLM\TK_SOFTWARE\Microsoft\Internet Explorer\Main" /v "Default_Page_URL" /t REG_SZ /d "about:blank" /f >nul
 reg add "HKLM\TK_SOFTWARE\Microsoft\Internet Explorer\Main" /v "Default_Search_URL" /t REG_SZ /d "https://www.google.com/" /f >nul
 reg add "HKLM\TK_SOFTWARE\Microsoft\Internet Explorer\Main" /v "EnableAutoUpgrade" /t REG_DWORD /d 0 /f >nul


 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Internet Explorer\PhishingFilter" /v "EnabledV9" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Internet Explorer\PhishingFilter" /v "PreventOverride" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\0" /v "2301" /t REG_DWORD /d "3" /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\1" /v "2301" /t REG_DWORD /d "3" /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\2" /v "2301" /t REG_DWORD /d "3" /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" /v "2301" /t REG_DWORD /d "3" /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\4" /v "2301" /t REG_DWORD /d "3" /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Internet Explorer\Suggested Sites" /v "Enabled" /t REG_DWORD /d 0 /f >nul
 
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments" /v "SaveZoneInformation" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments" /v "HideZoneInfoOnProperties" /t REG_DWORD /d 1 /f >nul

 REM Replace Bing with Google
 reg delete "HKLM\TK_SOFTWARE\Microsoft\Internet Explorer\SearchScopes\{0633EE93-D776-472f-A0FF-E1416B8B2E3A}" /f >nul 2>&1

 reg add "HKLM\TK_SOFTWARE\Microsoft\Internet Explorer\SearchScopes" /v "DefaultScope" /t REG_SZ /d "{0BBF48E6-FF9D-4FAA-AA4D-BDBB423B2BE1}" /f >nul
 reg add "HKLM\TK_SOFTWARE\Microsoft\Internet Explorer\SearchScopes" /v "DownloadUpdates" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Microsoft\Internet Explorer\SearchScopes" /v "Version" /t REG_DWORD /d 4 /f >nul
 reg add "HKLM\TK_SOFTWARE\Microsoft\Internet Explorer\SearchScopes" /v "ShowSearchSuggestionsInAddressGlobal" /t REG_DWORD /d 0 /f >nul

 reg add "HKLM\TK_SOFTWARE\Microsoft\Internet Explorer\SearchScopes\{0BBF48E6-FF9D-4FAA-AA4D-BDBB423B2BE1}" /v "DisplayName" /t REG_SZ /d "Google" /f >nul
 reg add "HKLM\TK_SOFTWARE\Microsoft\Internet Explorer\SearchScopes\{0BBF48E6-FF9D-4FAA-AA4D-BDBB423B2BE1}" /v "URL" /t REG_SZ /d "https://www.google.com/search?q={searchTerms}" /f >nul
 reg add "HKLM\TK_SOFTWARE\Microsoft\Internet Explorer\SearchScopes\{0BBF48E6-FF9D-4FAA-AA4D-BDBB423B2BE1}" /v "ShowSearchSuggestions" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_SOFTWARE\Microsoft\Internet Explorer\SearchScopes\{0BBF48E6-FF9D-4FAA-AA4D-BDBB423B2BE1}" /v "SuggestionsURL_JSON" /t REG_SZ /d "https://suggestqueries.google.com/complete/search?output=firefox&client=firefox&qu={searchTerms}" /f >nul
 reg delete "HKLM\TK_SOFTWARE\Microsoft\Internet Explorer\SearchScopes\{0BBF48E6-FF9D-4FAA-AA4D-BDBB423B2BE1}" /v "FaviconURL" /f >nul 2>&1

 REM Media Player Tweaks
 reg add "HKLM\TK_NTUSER\Software\Microsoft\MediaPlayer\Preferences" /v "AcceptedPrivacyStatement" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\MediaPlayer\Preferences" /v "UpgradeCheckFrequency" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\MediaPlayer\Preferences" /v "MediaLibraryCreateNewDatabase" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\MediaPlayer\Preferences" /v "MetadataRetrieval" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\MediaPlayer\Preferences" /v "SilentAcquisition" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\MediaPlayer\Preferences" /v "UsageTracking" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\MediaPlayer\Preferences" /v "DisableMRUMusic" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\MediaPlayer\Preferences" /v "DisableMRUPictures" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\MediaPlayer\Preferences" /v "DisableMRUVideo" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\MediaPlayer\Preferences" /v "DisableMRUPlaylists" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\MediaPlayer\Preferences" /v "FirstRun" /t REG_DWORD /d 0 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Microsoft\MediaPlayer\Preferences" /v "LaunchIndex" /t REG_DWORD /d 1 /f >nul

 REM Windows Media Player Privacy
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\WindowsMediaPlayer" /v "DisableAutoUpdate" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\WindowsMediaPlayer" /v "PreventLibrarySharing" /t REG_DWORD /d 1 /f >nul


 REM Re-enable SafeDisk Service for compatibility with old Games
 Reg add "HKLM\TK_SYSTEM\ControlSet001\Services\secdrv" /v Start /t REG_DWORD /d 2 /f >nul


 REM Enable Fraunhofer IIS MP3 Professional Codec

 if "%ImageArchitecture%"=="x64" (
  reg delete "HKLM\TK_SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\drivers.desc" /v "D:\Windows\SysWOW64\l3codeca.acm" /f >nul 2>&1
  reg add "HKLM\TK_SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\drivers.desc" /v "D:\Windows\SysWOW64\l3codecp.acm" /t REG_SZ /d "Fraunhofer IIS MPEG Audio Layer-3 Codec (professional)" /f >nul
  reg add "HKLM\TK_SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\Drivers32" /v "msacm.l3acm" /t REG_SZ /d "D:\Windows\SysWOW64\l3codecp.acm" /f >nul
 )

 reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\drivers.desc" /v "D:\Windows\System32\l3codeca.acm" /f >nul 2>&1
 reg add "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\drivers.desc" /v "D:\Windows\System32\l3codecp.acm" /t REG_SZ /d "Fraunhofer IIS MPEG Audio Layer-3 Codec (professional)" /f >nul
 reg add "HKLM\TK_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Drivers32" /v "msacm.l3acm" /t REG_SZ /d "D:\Windows\System32\l3codecp.acm" /f >nul


 REM Disable obsolete LLNR protocol
 if not "%DisableLLNR%"=="0" (
  reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" /v "EnableMulticast" /t REG_DWORD /d 0 /f >nul
 )

 REM Disable obsolete SSL and TLS protocols
 if not "%DisableObsoleteSSL%"=="0" (
  reg add "HKLM\TK_SYSTEM\ControlSet001\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client" /v "DisabledByDefault" /t REG_DWORD /d 1 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet001\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client" /v "Enabled" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client" /v "DisabledByDefault" /t REG_DWORD /d 1 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client" /v "Enabled" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet001\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client" /v "DisabledByDefault" /t REG_DWORD /d 1 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet001\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client" /v "Enabled" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client" /v "DisabledByDefault" /t REG_DWORD /d 1 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client" /v "Enabled" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet001\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client" /v "DisabledByDefault" /t REG_DWORD /d 1 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet001\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client" /v "Enabled" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client" /v "DisabledByDefault" /t REG_DWORD /d 1 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client" /v "Enabled" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet001\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client" /v "DisabledByDefault" /t REG_DWORD /d 1 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet001\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client" /v "Enabled" /t REG_DWORD /d 0 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client" /v "DisabledByDefault" /t REG_DWORD /d 1 /f >nul
  reg add "HKLM\TK_SYSTEM\ControlSet002\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client" /v "Enabled" /t REG_DWORD /d 0 /f >nul
  if "%ImageArchitecture%"=="x64" (
   reg add "HKLM\TK_SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" /v "DefaultSecureProtocols" /t REG_DWORD /d "2048" /f >nul
   reg add "HKLM\TK_SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Internet Settings" /v "SecureProtocols" /t REG_DWORD /d "2048" /f >nul
  )
  reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" /v "DefaultSecureProtocols" /t REG_DWORD /d "2048" /f >nul
  reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings" /v "SecureProtocols" /t REG_DWORD /d "2048" /f >nul
  reg add "HKLM\TK_NTUSER\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v "SecureProtocols" /t REG_DWORD /d "2048" /f >nul
 )

 REM Disable Automatic Update of root certificates during installation
 if not "%DisableRootCertUpdate%"=="0" reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\SystemCertificates\AuthRoot" /v "DisableRootAutoUpdate" /t REG_DWORD /d 1 /f >nul

 REM Switch Windows Updates installation to Manual
 reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" /v "AUOptions" /t REG_DWORD /d 1 /f >nul
 
 REM Switch Windows Update to Microsoft Update
 reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Services\Pending\7971f918-a847-4430-9279-4a52d1efe18d" /v "ClientApplicationID" /t REG_SZ /d "My App" /f >nul
 reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Services\Pending\7971f918-a847-4430-9279-4a52d1efe18d" /v "RegisterWithAU" /t REG_DWORD /d 1 /f >nul

 REM Disable Unsupported OS Warning for Chromium, Chrome, Brave, Edge and Vivaldi
 reg add "HKLM\TK_SOFTWARE\Policies\Chromium" /v "SuppressUnsupportedOSWarning" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Google\Chrome" /v "SuppressUnsupportedOSWarning" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\BraveSoftware\Brave" /v "SuppressUnsupportedOSWarning" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Microsoft\Edge" /v "SuppressUnsupportedOSWarning" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_SOFTWARE\Policies\Vivaldi" /v "SuppressUnsupportedOSWarning" /t REG_DWORD /d 1 /f >nul
 
 
 REM SysInternals Tools EULA Accepted

 reg add "HKLM\TK_NTUSER\Software\Sysinternals\AutoRuns" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\ClockRes" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\Coreinfo" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\Desktops" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\Disk2Vhd" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\DiskExt" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\DiskView" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\Du" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\FindLinks" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\Handle" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\Hex2Dec" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\Junction" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\ListDLLs" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\Movefile" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\NTFSInfo" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\PendMove" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\Process Explorer" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\Process Monitor" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\PsExec" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\PsFile" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\PsGetSid" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\PsInfo" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\PsKill" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\PsList" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\PsLoggedon" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\PsLoglist" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\PsPasswd" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\PsPing" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\PsService" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\PsShutdown" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\PsSuspend" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\SDelete" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\Share Enum" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\sigcheck" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\Streams" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\Strings" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\Sync" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\TCPView" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\VolumeID" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul
 reg add "HKLM\TK_NTUSER\Software\Sysinternals\Whois" /v "EulaAccepted" /t REG_DWORD /d 1 /f >nul

 del /q /f "%~dp0hotfixes\pending.tmp" >nul 2>&1

 ECHO.
 ECHO Done
 ECHO.

 ECHO.
 ECHO.
 ECHO ================================================================
 echo Unmounting registry
 ECHO ================================================================
 ECHO.

 reg unload HKLM\TK_DEFAULT >nul
 reg unload HKLM\TK_NTUSER >nul
 reg unload HKLM\TK_SOFTWARE >nul
 reg unload HKLM\TK_SYSTEM >nul

 ECHO.
 ECHO.
 ECHO ================================================================
 ECHO Copying files from add_these_files_to_Windows to Install.wim
 ECHO ================================================================
 ECHO.


 xcopy "%~dp0add_these_files_to_Windows\%ImageArchitecture%\*" "%~dp0mount\1\" /e/s/y >nul 2>&1

 ECHO.
 ECHO Done
 ECHO.

:skipCustPatches


if not "%Win10ImageArchitecture%"=="%ImageArchitecture%" goto skipWin10InstallerEFI

"%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "rd /s /q "%~dp0mount\1\Windows\Boot"" >nul 2>&1
"%~dp0tools\%HostArchitecture%\NSudo.exe" -U:T -P:E -UseCurrentConsole -Wait cmd /c "xcopy "%~dp0Win10_Installer\EFI_Boot\*" "%~dp0mount\1\Windows\Boot\" /e /s /y" >nul

:skipWin10InstallerEFI


if not "%AddDrivers%"=="1" goto skipDrivers


cd /d "%~dp0hotfixes"
if "%ImageArchitecture%"=="x86" (
 if not exist "%~dp0hotfixes\windows6.1-kb2864202-x86.msu" "%~dp0tools\%HostArchitecture%\wget.exe" -q --show-progress --no-hsts --no-check-certificate -O "windows6.1-kb2864202-x86.msu" "http://download.windowsupdate.com/d/msdownload/update/software/secu/2013/07/windows6.1-kb2864202-x86_9e556e48e72ae30ec89c5f1c713acde26da2556a.msu"
)
if "%ImageArchitecture%"=="x64" (
 if not exist "%~dp0hotfixes\windows6.1-kb2864202-x64.msu" "%~dp0tools\%HostArchitecture%\wget.exe" -q --show-progress --no-hsts --no-check-certificate -O "windows6.1-kb2864202-x64.msu" "http://download.windowsupdate.com/d/msdownload/update/software/secu/2013/07/windows6.1-kb2864202-x64_92617ad813adf4795cd694d828558271086f4f70.msu"
)
cd /d "%~dp0"


set BootDrivers=1
if "%Win10ImageArchitecture%"=="%ImageArchitecture%" set BootDrivers=0

set WinREDrivers=1

set InstallDrivers=1
dir /a/s/b "%~dp0add_these_drivers_to_Windows\%ImageArchitecture%\*.inf" >nul 2>&1
if errorlevel 1 set InstallDrivers=0


if not "%BootDrivers%"=="1" goto skipBootDrivers

 ECHO.
 ECHO.
 ECHO ================================================================
 ECHO Addding drivers to Installer (Boot.wim)
 ECHO ================================================================
 ECHO.


 mkdir "%~dp0mount\Boot" >nul 2>&1
 set BootCount=1
 for /f "tokens=2 delims=: " %%i in ('start "" /b "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /English /Get-WimInfo /WimFile:"%~dp0DVD\sources\boot.wim" ^| findstr /l /i /c:"Index"') do (set BootCount=%%i)
 
 for /L %%i in (1, 1, %BootCount%) do (
  "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Mount-Wim /WimFile:"%~dp0DVD\sources\boot.wim" /index:%%i /MountDir:"%~dp0mount\Boot"
  REM Pre-requsite for USB3
  "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\Boot" /PackagePath:"%~dp0hotfixes\Windows6.1-kb2864202-%ImageArchitecture%.msu"
  REM Other drivers
  "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Image:"%~dp0mount\Boot" /Add-Driver /Driver:"%~dp0add_these_drivers_to_Installer\%ImageArchitecture%" /Recurse /ForceUnsigned
  REM Apply UEFI updates to boot.wim by getting bootmgr from mounted point
  if exist "%~dp0mount\1\Windows\Boot\EFI\bootmgfw.efi" (
   copy /b /y "%~dp0mount\1\Windows\Boot\EFI\bootmgfw.efi" "%~dp0mount\Boot\Windows\Boot\EFI\bootmgfw.efi" >nul 2>&1
   copy /b /y "%~dp0mount\1\Windows\Boot\EFI\bootmgr.efi" "%~dp0mount\Boot\Windows\Boot\EFI\bootmgr.efi" >nul 2>&1
   copy /b /y "%~dp0mount\1\Windows\Boot\EFI\memtest.efi" "%~dp0mount\Boot\Windows\Boot\EFI\memtest.efi" >nul 2>&1
  )
   copy /b /y "%~dp0mount\1\Windows\Boot\PCAT\bootmgr" "%~dp0mount\Boot\Windows\Boot\PCAT\bootmgr" >nul 2>&1
   copy /b /y "%~dp0mount\1\Windows\Boot\PCAT\memtest.exe" "%~dp0mount\Boot\Windows\Boot\PCAT\memtest.exe" >nul 2>&1
  "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Unmount-Wim /MountDir:"%~dp0mount\Boot" /commit
 )
 rd /s/q "%~dp0mount\Boot" >nul 2>&1


:skipBootDrivers


if not "%InstallDrivers%"=="1" goto skipDrivers

  ECHO.
  ECHO.
  ECHO ================================================================
  ECHO Addding drivers to install.wim
  ECHO ================================================================
  ECHO.
  REM Generic NVMe drivers
  if "%UseBackportedNVMe%"=="0" (
   if exist "%~dp0hotfixes\NVMe\windows6.1-KB2990941-v3-%ImageArchitecture%.msu" (
    "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\NVMe\windows6.1-KB2990941-v3-%ImageArchitecture%.msu"
   )
  )
  REM If rollup updates are not integrated, these pre-requisites are needed
  if "%InstallHotfixes%"=="0" (
   REM NVMe pre-requisite
   if exist "%~dp0hotfixes\NVMe\windows6.1-KB3087873-v2-%ImageArchitecture%.msu" (
    "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\NVMe\windows6.1-KB3087873-v2-%ImageArchitecture%.msu"
   )
   REM Pre-requisite for USB3
   "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\1" /PackagePath:"%~dp0hotfixes\Windows6.1-kb2864202-%ImageArchitecture%.msu"
  )
  REM Generic backported NVMe drivers
  if not "%UseBackportedNVMe%"=="0" (
   if exist "%~dp0add_these_drivers_to_Installer\%ImageArchitecture%\NVMe\msnvme.inf" (
    "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Image:"%~dp0mount\1" /Add-Driver /Driver:"%~dp0add_these_drivers_to_Installer\%ImageArchitecture%\NVMe\msnvme.inf" /ForceUnsigned
   )
  )
  REM Other drivers
  "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Image:"%~dp0mount\1" /Add-Driver /Driver:"%~dp0add_these_drivers_to_Windows\%ImageArchitecture%" /Recurse /ForceUnsigned

  if "%WinREDrivers%"=="1" (
   ECHO.
   ECHO.
   ECHO ================================================================
   ECHO Addding drivers to recovery inside install.wim
   ECHO ================================================================
   ECHO.
   mkdir "%~dp0mount\WinRE" >nul 2>&1
   "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Mount-Wim /WimFile:"%~dp0mount\1\Windows\System32\Recovery\winRE.wim" /index:1 /MountDir:"%~dp0mount\WinRE"
   REM Pre-requisite for USB3
   "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\WinRE" /PackagePath:"%~dp0hotfixes\Windows6.1-kb2864202-%ImageArchitecture%.msu"
   REM Generic NVMe drivers
   if "%UseBackportedNVMe%"=="0" (
    if exist "%~dp0hotfixes\NVMe\windows6.1-KB2990941-v3-%ImageArchitecture%.msu" (
     "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\WinRE" /PackagePath:"%~dp0hotfixes\NVMe\windows6.1-KB2990941-v3-%ImageArchitecture%.msu"
    )
   )
   if exist "%~dp0hotfixes\NVMe\windows6.1-KB3087873-v2-%ImageArchitecture%.msu" (
    "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Add-Package /Image:"%~dp0mount\WinRE" /PackagePath:"%~dp0hotfixes\NVMe\windows6.1-KB3087873-v2-%ImageArchitecture%.msu"
   )
   REM Generic backported NVMe drivers
   if not "%UseBackportedNVMe%"=="0" (
    if exist "%~dp0add_these_drivers_to_Installer\%ImageArchitecture%\NVMe\msnvme.inf" (
     "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Image:"%~dp0mount\WinRE" /Add-Driver /Driver:"%~dp0add_these_drivers_to_Installer\%ImageArchitecture%\NVMe\msnvme.inf" /ForceUnsigned
    )
   )
   REM Other drivers
   "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Image:"%~dp0mount\WinRE" /Add-Driver /Driver:"%~dp0add_these_drivers_to_Recovery\%ImageArchitecture%" /Recurse /ForceUnsigned

   REM Apply UEFI updates to winRE.wim by getting bootmgr from mounted point
   if exist "%~dp0mount\1\Windows\Boot\EFI\bootmgfw.efi" (
    copy /b /y "%~dp0mount\1\Windows\Boot\EFI\bootmgfw.efi" "%~dp0mount\WinRE\Windows\Boot\EFI\bootmgfw.efi" >nul 2>&1
    copy /b /y "%~dp0mount\1\Windows\Boot\EFI\bootmgr.efi" "%~dp0mount\WinRE\Windows\Boot\EFI\bootmgr.efi" >nul 2>&1
    copy /b /y "%~dp0mount\1\Windows\Boot\EFI\memtest.efi" "%~dp0mount\WinRE\Windows\Boot\EFI\memtest.efi" >nul 2>&1
   )
    copy /b /y "%~dp0mount\1\Windows\Boot\PCAT\bootmgr" "%~dp0mount\WinRE\Windows\Boot\PCAT\bootmgr" >nul 2>&1
    copy /b /y "%~dp0mount\1\Windows\Boot\PCAT\memtest.exe" "%~dp0mount\WinRE\Windows\Boot\PCAT\memtest.exe" >nul 2>&1
   "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Unmount-Wim /MountDir:"%~dp0mount\WinRE" /commit
  )

 rd /s/q "%~dp0mount\WinRE" >nul 2>&1


:skipDrivers


if not "%CleanupImages%"=="1" goto skipCleanUp


 ECHO.
 ECHO.
 ECHO ================================================================
 echo Cleaning install.wim
 ECHO ================================================================
 ECHO.

 rem Commented out, because below line does not work on Windows 7
 rem "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Image:"%~dp0mount\1" /Cleanup-Image /StartComponentCleanup /ResetBase

 rem Below line is usefull only if you have manualy integrated Service Pack
 "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Image:"%~dp0mount\1" /Cleanup-Image /SPSuperseded /HideSP

:skipCleanUp

REM Apply UEFI updates to DVD by getting bootmgr from mounted point
if not "%Win10ImageArchitecture%"=="%ImageArchitecture%" (
 if exist "%~dp0mount\1\Windows\Boot\EFI\bootmgfw.efi" (
  mkdir "%~dp0DVD\efi\boot" >nul 2>&1
  copy /b /y "%~dp0mount\1\Windows\Boot\EFI\bootmgfw.efi" "%~dp0DVD\efi\boot\bootx64.efi" >nul 2>&1
  copy /b /y "%~dp0mount\1\Windows\Boot\EFI\bootmgr.efi" "%~dp0DVD\bootmgr.efi" >nul 2>&1
  copy /b /y "%~dp0mount\1\Windows\Boot\EFI\memtest.efi" "%~dp0DVD\boot\memtest.efi" >nul 2>&1
 )
  copy /b /y "%~dp0mount\1\Windows\Boot\PCAT\bootmgr" "%~dp0DVD\bootmgr" >nul 2>&1
  copy /b /y "%~dp0mount\1\Windows\Boot\PCAT\memtest.exe" "%~dp0DVD\boot\memtest.exe" >nul 2>&1
)


 ECHO.
 ECHO.
 ECHO ================================================================
 ECHO Unounting install.wim
 ECHO ================================================================
 ECHO.
 "%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Unmount-Wim /MountDir:"%~dp0mount\1" /commit
 rd /s/q "%~dp0mount\1" >nul 2>&1



:skipMount


if not "%RepackImages%"=="1" goto skipRepack


if "%Win10ImageArchitecture%"=="%ImageArchitecture%" goto skipRepackBootWim
ECHO.
ECHO.
ECHO ================================================================
ECHO Repacking file boot.wim
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\imagex.exe" /export "%~dp0DVD\sources\boot.wim" "*" "%~dp0DVD\sources\boot_temp.wim" /CHECK /COMPRESS maximum
move /y "%~dp0DVD\sources\boot_temp.wim" "%~dp0DVD\sources\boot.wim" >NUL
:skipRepackBootWim

ECHO.
ECHO.
ECHO ================================================================
ECHO Repacking file install.wim
ECHO ================================================================
ECHO.
"%~dp0tools\%HostArchitecture%\DISM\imagex.exe" /export "%~dp0DVD\sources\install.wim" "*" "%~dp0DVD\sources\install_temp.wim" /CHECK /COMPRESS maximum
move /y "%~dp0DVD\sources\install_temp.wim" "%~dp0DVD\sources\install.wim" >NUL

:skipRepack


if not "%SplitInstallWim%"=="1" goto SkipSplitInstallWim

FOR /F "usebackq" %%A IN ('%~dp0DVD\sources\install.wim') DO set "InstallWimSize=%%~zA"
if "%InstallWimSize%" LSS "4294967296" goto SkipSplitInstallWim

ECHO.
ECHO.
ECHO ================================================================
ECHO Splitting file install.wim
ECHO ================================================================
ECHO.

"%~dp0tools\%HostArchitecture%\DISM\dism.exe" /Split-Image /ImageFile:"%~dp0DVD\sources\install.wim" /SWMFile:"%~dp0DVD\sources\install.swm" /FileSize:3700
del /q /f "%~dp0DVD\sources\install.wim" >nul 2>&1

:SkipSplitInstallWim


if "%CreateISO%"=="0" goto dontCreateISO

ECHO.
ECHO.
ECHO ================================================================
ECHO Creating new DVD image
ECHO ================================================================
ECHO.

 if "%ImageArchitecture%"=="x86" "%~dp0tools\%HostArchitecture%\oscdimg.exe" -b"%~dp0DVD\boot\etfsboot.com" -h -m -u2 -udfver102 "%~dp0DVD" "%~dp0Windows7_x86_%ImageLanguage%.iso" -lWin7

 if "%ImageArchitecture%"=="x64" "%~dp0tools\%HostArchitecture%\oscdimg.exe" -bootdata:2#p0,e,b"%~dp0DVD\boot\etfsboot.com"#pEF,e,b"%~dp0DVD\efi\microsoft\boot\Efisys.bin" -h -m -u2 -udfver102 "%~dp0DVD" "%~dp0Windows7_x64_%ImageLanguage%.iso" -lWin7

 REM Clean DVD directory
 rd /s /q "%~dp0DVD" >nul 2>&1
 mkdir "%~dp0DVD" >nul 2>&1

:dontCreateISO


ECHO.
ECHO.
ECHO.
ECHO All finished.
ECHO.
ECHO Press any key to end the script.
ECHO.
PAUSE >NUL


:end
