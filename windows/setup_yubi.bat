@ECHO OFF
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

set LANG=EN
set me=%~n0
set root_folder=%~dp0\..
set "ifErr=set foundErr=1&(if errorlevel 0 if not errorlevel 1 set foundErr=)&if defined foundErr"
set pin_input=%root_folder%\pin.input
set pers_info_input=%root_folder%\pers_info.input
set keytocard_input=%root_folder%\keytocard.input
set "silentDel=del >nul 2>&1"

set user_name=%~1
set user_email=%~2
set key_id=%~3
set passphrase=%~4

call :splitAtLastSpace user_name given_name sur_name

echo.
set areyousure=
set /p areyousure="Should we first setup your Yubikey's PIN and Admin PIN (y/[n])? "
if /I "!areyousure!" NEQ "y" goto enterPersonalInfo
echo Remember: Default PIN is 123456 ^| Default Admin PIN is 12345678
type %pin_input% | gpg --command-fd=0 --status-fd=1 --card-edit --expert
%ifErr% echo %me%: Setting the PINs ran into an error. Exiting. && goto end

:enterPersonalInfo
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
set areyousure=
set /p areyousure="Going to setup personal information on your Yubikey (y/[n])? "
if /I "!areyousure!" NEQ "y" goto end
type %pers_info_input% | gpg --command-fd=0 --status-fd=1 --card-edit --expert
%ifErr% echo %me%: Setting up personal data ran into an error. Exiting. && goto end

echo.
set areyousure=
set /p areyousure="Going to move GPG keys to your Yubikey (y/[n])? "
if /I "!areyousure!" NEQ "y" goto end
type %keytocard_input% | gpg --command-fd=0 --status-fd=1 --pinentry-mode loopback --passphrase %passphrase% --edit-key --expert %key_id%
%ifErr% echo %me%: Moving GPG keys to Yubikey ran into an error. Exiting. && goto end

goto end

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

:end
timeout /T 2 /NOBREAK
%silentDel% %pers_info_input%
endlocal