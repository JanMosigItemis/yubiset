@ECHO OFF
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

set me=%~n0
set root_folder=%~dp0\..
set "ifErr=set foundErr=1&(if errorlevel 0 if not errorlevel 1 set foundErr=)&if defined foundErr"

set areyousure=
echo.
set /p areyousure="Ok, do you wish to reset your YubiKey first?  (y/[n])? "
if /I "!areyousure!" NEQ "y" goto end

gpg-connect-agent < reset_yubi.dat
%ifErr% echo %me%: Could not properly reset the YubiKey. Exiting. && goto end

:end