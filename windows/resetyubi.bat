@ECHO OFF
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

::
:: SETUP SECTION
::
set lib_dir=lib

call %lib_dir%/setup_script_env.bat "%~n0" "%~dp0"
%ifErr% echo %error_prefix%: Bootstraping the script failed. Exiting. & call :cleanup & goto end_with_error

call %lib_dir%/pretty_print.bat "Yubikey reset script"
call %lib_dir%/pretty_print.bat "Version: %yubiset_version%"

call %lib_dir%/are_you_sure.bat "About to reset your YubiKey's OpenPGP module. Continue"
if defined answerisno call :cleanup & goto end_with_error

echo Now resetting..
gpg-connect-agent < %input_dir%/resetyubi.input 2>&1 >nul
%ifErr% echo %error_prefix%: Could not properly reset your Yubikey. Exiting. & call :cleanup & goto end_with_error
echo ..Success!

echo.
call %lib_dir%/pretty_print "PIN: 123456"
call %lib_dir%/pretty_print "Admin PIN: 12345678"
call %lib_dir%/reinsert_yubi.bat

call :cleanup
goto end

:: Function start
:cleanup
if not defined YUBISET_MAIN_SCRIPT_RUNS rd /S /Q %yubiset_temp_dir%
exit /b 0
:: Function end

:end_with_error
endlocal
exit /b 1

:end
endlocal