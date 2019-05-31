@ECHO OFF
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

set me=%~n0
set root_folder=%~dp0\..
set "ifErr=set foundErr=1&(if errorlevel 0 if not errorlevel 1 set foundErr=)&if defined foundErr"

set areyousure=
echo.
set /p areyousure="About to reset your YubiKey's OpenPGP module. Continue?  (y/[n])? "
if /I "!areyousure!" NEQ "y" exit /b 1

gpg-connect-agent < reset_yubi.dat
%ifErr% echo %me%: Could not properly reset the YubiKey. Exiting. && goto end

:end