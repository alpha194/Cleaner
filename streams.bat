:: --------------------------------------------------------------------------------------------------- ::
:: -----------------                               STREAMS                          ------------------ ::
:: --------------------------------------------------------------------------------------------------- ::
::Written by: Jordan Hill

@echo off && cls

:::::::::::::::
:: VARIABLES :: ----------------- These are the defaults. Change them if you want -------------------- ::
:::::::::::::::

set SKIP_WINDOWS_UPDATES=no
set TARGET_METRO=yes
set PRESERVE_METRO_APPS%=no
set DRY_RUN%=no
set SAFE_MODE%=no

:: Detect the version of Windows we're on. ::WORKING::
	set WIN_VER=undetected
	set WIN_VER_NUM=undetected
	for /f "tokens=3*" %%i IN ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v ProductName ^| FIND "ProductName"') DO set WIN_VER=%%i %%j
	for /f "tokens=3*" %%i IN ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentVersion ^| FIND "CurrentVersion"') DO set WIN_VER_NUM=%%i
echo %WIN_VER%

::::::::::::::::::::::::
:: ADMIN RIGHTS CHECK ::
::::::::::::::::::::::::
:: Skip this check if we're in Safe Mode because Safe Mode command prompt always starts with Admin rights
SETLOCAL ENABLEDELAYEDEXPANSION
if /i not "%SAFE_MODE%"=="yes" (
	fsutil dirty query %systemdrive% >NUL 2>&1
	if /i not !ERRORLEVEL!==0 (
		color cf
		cls
		echo.
		echo  ERROR
		echo.
		echo  you MUST be run with full Administrator rights to
		echo  function correctly.
		echo.
		echo  Close this window and re-run as an Administrator.
		echo  ^(right-click and choose "Run as Administrator"^)
		echo.
		pause
		exit /b 1
	)
)
SETLOCAL DISABLEDELAYEDEXPANSION

::::::::::::::::::::::::::::::::::
:: INSTALLATION OF MSI PACKAGES ::
::::::::::::::::::::::::::::::::::

:: Install Google Chrome
if "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe" goto chrome-end
msiexec /q /i GoogleChromeStandoloneEnterprise.msi
:chrome-end


::::::::::::::::::::::::
:: Create student User::
::::::::::::::::::::::::

::creates new user called student
if net user | find /i "student" = "" (
net user student cghs /add
)
REG ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /f /v EnableFirstLogonAnimation /t REG_DWORD /d 00000000

::::::::::::::::::::
:: Windows Update ::
::::::::::::::::::::

:: JOB: Check for updates
if /i %SKIP_WINDOWS_UPDATES%==no (
	sc config wuauserv start= demand
	net start wuauserv
	wuauclt /detectnow /updatenow
	ping 127.0.0.1 -n 15
)

::::::::::::::::::            MORE WORK HERE!!!! 
:: REMOVE METRO ::
::::::::::::::::::

:: JOB: Remove default Metro apps (Windows 8 and up)
:: This command will re-install ALL default Windows 10 apps:
:: Get-AppxPackage -AllUsers| Foreach {Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml"}

:: Version checks
if %WIN_VER_NUM% geq 6.2 set TARGET_METRO=yes
if /i %PRESERVE_METRO_APPS%==yes set TARGET_METRO=no
if /i %TARGET_METRO%==yes (
	echo Windows 8 or higher detected, removing OEM Metro apps...
	:: Force allowing us to start AppXSVC service in Safe Mode. AppXSVC is the MSI Installer equivalent for "apps" (vs. programs)
	if /i %DRY_RUN%==no (
		REM Enable starting AppXSVC in Safe Mode
		if /i "%SAFE_MODE%"=="yes" reg add "HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot\%SAFEBOOT_OPTION%\AppXSVC" /ve /t reg_sz /d Service /f >nul 2>&1
		net start AppXSVC >nul 2>&1
		REM Enable scripts in PowerShell
		powershell "Set-ExecutionPolicy Unrestricted -force 2>&1 | Out-Null"

		REM Windows 8/8.1 version
		if /i "%WIN_VER:~0,9%"=="Windows 8" (
			REM In Windows 8/8.1 we can blast ALL AppX/Metro/"Modern App" apps because unlike in Windows 10, the "core" apps (calculator, paint, etc) aren't in the "modern" format
			powershell "Get-AppXProvisionedPackage -online | Remove-AppxProvisionedPackage -online 2>&1 | Out-Null"
			powershell "Get-AppxPackage -AllUsers | Remove-AppxPackage 2>&1 | Out-Null"
		)
		REM Windows 10 version
		if /i "%WIN_VER:~0,9%"=="Windows 1" (
			REM Call the external PowerShell scripts to do removal of Microsoft and 3rd party OEM Modern Apps
			powershell -executionpolicy bypass -file ".\stage_2_de-bloat\metro\metro_3rd_party_modern_apps_to_target_by_name.ps1"
			powershell -executionpolicy bypass -file ".\stage_2_de-bloat\metro\metro_Microsoft_modern_apps_to_target_by_name.ps1"
		)
	)
)

::::::::::::::::::::::::::
:: COMPUTER NAME CHANGE ::
::::::::::::::::::::::::::

SET /P RENAME=Enter Computer Name:
wmic computersystem where name="%computername%" call rename name="%RENAME%"
