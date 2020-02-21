@ECHO OFF
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

REM
REM SETUP SECTION
REM
set lib_dir=lib

call %lib_dir%/bootstrap.bat "%~n0" "%~dp0"
%ifErr% echo %error_prefix%: Bootstraping the script failed. Exiting. & call :cleanup & goto end_with_error

call %lib_dir%/pretty_print.bat "Yubikey reset script"
call %lib_dir%/pretty_print.bat "Version: %yubiset_version%"

call %lib_dir%/are_you_sure.bat "About to reset your YubiKey's OpenPGP module. Continue"
if defined answerisno call :cleanup & goto end_with_error

echo Now resetting..
gpg-connect-agent < %input_dir%\resetyubi.input >nul 2>&1
%ifErr% echo %error_prefix%: Could not properly reset your Yubikey. Exiting. & call :cleanup & goto end_with_error
echo ..Success!

echo.
call %lib_dir%/pretty_print.bat "PIN: 123456"
call %lib_dir%/pretty_print.bat "Admin PIN: 12345678"

echo.
echo Please remove your Yubikey
pause
echo Please insert your Yubikey
pause

call :cleanup
goto end

REM Function start
:cleanup
if not defined YUBISET_MAIN_SCRIPT_RUNS rd >nul 2>&1 /S /Q !yubiset_temp_dir!
exit /b 0
REM Function end

:end_with_error
endlocal
exit /b 1

:end
endlocal