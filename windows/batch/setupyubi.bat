@ECHO OFF
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

::
:: Arg 1: Full name
:: Arg 2: email address
:: Arg 3: PGP key ID
:: Arg 4: Passphrase
::

::
:: SETUP SECTION
::
set lib_dir=lib

call %lib_dir%/bootstrap.bat "%~n0" "%~dp0"
%ifErr% echo %error_prefix%: Bootstraping the script failed. Exiting. & call :cleanup & goto end_with_error

call %lib_dir%/pretty_print.bat "Yubikey setup and key to card script"
call %lib_dir%/pretty_print.bat "Version: %yubiset_version%"

set user_name=%~1
set user_email=%~2
set key_id=%~3
set passphrase=%~4

set pin_input=%input_dir%\pin.input
set pers_info_input=!yubiset_temp_dir!\pers_info.input
set keytocard_input=%input_dir%\keytocard.input

call :splitAtLastSpace user_name given_name sur_name

::
:: PIN SECTION
::
echo.
call %lib_dir%/are_you_sure.bat "Should we first setup your Yubikey's PIN and Admin PIN"
if defined answerisno goto enterPersonalInfo

echo.
echo Remember: Default PIN is 123456 ^| Default Admin PIN is 12345678
type %pin_input% | gpg --command-fd=0 --status-fd=1 --card-edit --expert 2>&1 >nul
%ifErr% echo %error_prefix%: Setting the PINs ran into an error. Exiting. & call :cleanup & goto end_with_error
echo PIN setup successfull!

::
:: PERSONAL INFO SECTION
::
:enterPersonalInfo
echo.
call %lib_dir%/are_you_sure.bat "Should personal info be modified"
if defined answerisno goto keytocard

echo.
echo First we must collect some personal info of yours..
set /p lang_pref=Enter your language pref (e.g. en): 
:sex
set /p sex=Enter your sex (m/w): 
if /I "!sex!" EQU "m" set ifresult=true
if /I "!sex!" EQU "w" set ifresult=true
if "!ifresult!" NEQ "true" goto sex

echo admin>> %pers_info_input%
echo name>> %pers_info_input%
echo !sur_name!>> %pers_info_input%
echo !given_name!>> %pers_info_input%
echo lang>> %pers_info_input%
echo %lang_pref%>> %pers_info_input%
echo sex>> %pers_info_input%
echo %sex%>> %pers_info_input%
echo login>> %pers_info_input%
echo %user_email%>> %pers_info_input%
echo url>> %pers_info_input%
echo https://sks-keyservers.net/pks/lookup?op=get^&search=0x%key_id%>> %pers_info_input%

echo.
call %lib_dir%/are_you_sure.bat "Write personal information to your Yubikey"
if defined answerisno goto keytocard
echo Now writing..
type %pers_info_input% | gpg --command-fd=0 --status-fd=1 --card-edit --expert 2>&1 >nul
%ifErr% echo %error_prefix%: Writing personal data to Yubikey ran into an error. Exiting. & call :cleanup & goto end_with_error
echo ..Success!

:keytocard
echo.
call %lib_dir%/are_you_sure.bat "Move your subkeys to your Yubikey"
if defined answerisno call :cleanup & goto end
echo Now moving keys..
type %keytocard_input% | gpg --command-fd=0 --status-fd=1 --pinentry-mode loopback --passphrase %passphrase% --edit-key --expert %key_id% 2>&1 >nul
%ifErr% echo %me%: Moving GPG keys to Yubikey ran into an error. Exiting. & call :cleanup & goto end_with_error
echo ..Success!

call :cleanup
goto end

:: Function start
:splitAtLastSpace
set pos=-1
set last_space=0
:splitLoop
set /a pos+=1
set current_char=!%~1:~%pos%,1!
if "%current_char%"==" " set last_space=%pos%
if "%current_char%" NEQ "" goto splitLoop
:afterSplitLoop
set %~2=!%~1:~0,%last_space%!
set /a last_space+=1
set /a pos-=1
set %~3=!%~1:~%last_space%,%pos%!
exit /b 0
:: Function end

:: Function start
:cleanup
if not defined YUBISET_MAIN_SCRIPT_RUNS rd >nul 2>&1 /S /Q !yubiset_temp_dir!
exit /b 0
:: Function end

:end_with_error
endlocal
exit /b 1

:end
endlocal