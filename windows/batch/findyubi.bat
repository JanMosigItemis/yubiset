@ECHO OFF
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

REM
REM SETUP SECTION
REM
set lib_dir=lib

call %lib_dir%/bootstrap.bat "%~n0" "%~dp0"
%ifErr% echo %error_prefix%: Bootstraping the script failed. Exiting. & call :cleanup & goto end_with_error

call %lib_dir%/pretty_print.bat "Yubikey smartcard slot find and configuration script"
call %lib_dir%/pretty_print.bat "Version: %yubiset_version%"

set conf_backup=scdaemon.conf.orig
set scdaemon_log=%yubiset_temp_dir%\scdaemon.log
set gpg_card_status_log=%yubiset_temp_dir%\gpg_card_status.log

REM
REM GPG AGENT RESTART
REM
echo.
call %lib_dir%/restart_gpg_agent.bat
%ifErr% echo %error_prefix%: Could not restart gpg-agent. Exiting. & call :cleanup & goto end_with_error

REM
REM SCDAEMON RESTART
REM
echo.
call %lib_dir%/restart_scdaemon.bat
%ifErr% echo %error_prefix%: Could not restart scdaemon. Exiting. & call :cleanup & goto end_with_error

REM
REM COMM CHECK
REM
call %lib_dir%/reinsert_yubi.bat

echo Now checking if we are able to communicate with your Yubikey..
gpg --card-status > nul 2>&1
%ifErr% (
	echo "..Failed :("
	call %lib_dir%/are_you_sure.bat "This is most likely because your GPG does not know which card reader to use. Should we try setting things up for you"
	if defined answerisno echo %error_prefix%: We cannot continue without a properly recognized Yubikey. Exiting. & call :cleanup & goto end_with_error
) else (
	echo ..Success!
	call :cleanup
	goto end
)

REM
REM ACTIVATE SCDAEMON DEBUG MODE
REM
echo.
echo In order to find the correct card slot, we need to switch scdaemon into debug mode. This is done via a change to the config file. We are going to reset the changes, when we are done. Promise :)
call %lib_dir%/are_you_sure.bat "Continue"
if defined answerisno call :cleanup & goto end_with_error

if exist %gpg_home%\scdaemon.conf (
	echo Now creating backup: %gpg_home%\%conf_backup%
	%silentCopy% %gpg_home%\scdaemon.conf %gpg_home%\%conf_backup%
	%ifErr% echo %error_prefix%: Could not create backup of scdaemon.conf. Exiting. & call :cleanup & goto end_with_error

	for /f "usebackq" %%a in ('%gpg_home%\scdaemon.conf') do set scdaemon_conf_file_size=%%~za
	REM A leading empty line is breaking scdaemon<->gpg connection. We do want to put a newline in there only if the file already has contents.
	REM GTR - Greater than
	echo !scdaemon_conf_file_size!
	if !scdaemon_conf_file_size! GTR 0 echo.>>%gpg_home%\scdaemon.conf
	
	echo ..Success!
) else (
	set scdaemon_conf_file_size=0
	REM Creates a new empty file
	%silentCopy% NUL %gpg_home%\%conf_backup%
)

echo ^#Start: Temporarily added by Yubiset>> %gpg_home%\scdaemon.conf
echo log-file %scdaemon_log%>> %gpg_home%\scdaemon.conf
echo debug-level guru>> %gpg_home%\scdaemon.conf
echo debug-all>> %gpg_home%\scdaemon.conf
echo card-timeout 30>>%gpg_home%\scdaemon.conf
echo ^#End: Temporarily added by Yubiset>> %gpg_home%\scdaemon.conf

echo.
echo Please remove your YubiKey.
pause

REM
REM GPG AGENT RESTART
REM
echo.
call %lib_dir%/restart_gpg_agent.bat
%ifErr% echo %error_prefix%: Could not restart gpg-agent. Exiting. & call :cleanup & goto end_with_error

REM
REM SCDAEMON RESTART
REM
echo.
call %lib_dir%/restart_scdaemon.bat
%ifErr% echo %error_prefix%: Could not restart scdaemon. Exiting. & call :cleanup & goto end_with_error

echo Please insert your YubiKey.
pause

echo Now generating debug log..
gpg --card-status >%gpg_card_status_log% 2>&1
echo ..Done!

REM
REM PROCESS DEBUG LOG
REM
echo Processing debug log..
set array_index=0
for /f "tokens=2 delims=^'" %%i in ('type %scdaemon_log% ^| findstr /C:"detected reader"') do (
	set reader_port_candidate=%%i
	call :removeLastSpaceAndTail reader_port_candidate
	set /a array_index+=1
	set reader_port_candidates[!array_index!]=!reader_port_candidate!
)

for /f "tokens=2 delims==" %%i in ('set reader_port_candidates[') do (
	for /f "tokens=*" %%v in ('echo %%i^| findstr /I /C:"yubi"') do (
		set reader_port_candidate=%%v
		call %lib_dir%/are_you_sure.bat "Found reader port '%reader_port_candidate%' - Is this the right one"
		if defined answerisyes goto addReaderToConf
	)
)

echo Could not find any viable readers.
call :cleanup
goto end_with_error

:addReaderToConf
REM
REM DEACTIVATE SCDAEMON DEBUG MODE
REM
echo.
echo Now switching off debug mode..
call :cleanup

echo Writing scdaemon.conf..

REM A leading empty line is breaking scdaemon<->gpg connection. We do want to put a newline in there only if the file already has contents.
REM GTR - Greater than
if %scdaemon_conf_file_size% GTR 0 echo.>> %gpg_home%\scdaemon.conf
echo ^#Added by yubiset:>> %gpg_home%\scdaemon.conf
echo reader-port "%reader_port_candidate%">> %gpg_home%\scdaemon.conf
call %lib_dir%/restart_scdaemon.bat
%ifErr% echo %error_prefix%: Could not restart scdaemon. Exiting. & call :cleanup & goto end_with_error
echo.
REM
REM COMM CHECK
REM
call %lib_dir%/reinsert_yubi.bat

echo Now checking if we are able to communicate with your Yubikey..
gpg --card-status > nul 2>&1
%ifErr% echo Sorry, setting up your Yubikey did not work. Exiting. & call :cleanup & goto end_with_error
echo ..Success!

call :cleanup
goto end

REM Function start
:removeLastSpaceAndTail
set pos=-1
set last_space=0
:removeLastSpaceAndTail_loop
set /a pos+=1
set current_char=!reader_port_candidate:~%pos%,1!
if "%current_char%"==" " set last_space=%pos%
if "%current_char%" NEQ "" goto removeLastSpaceAndTail_loop
set %~1=!%~1:~0,%last_space%!
exit /b 0
REM Function end

REM Function start
:cleanup
%silentCopy% %gpg_home%\%conf_backup% %gpg_home%\scdaemon.conf /Y
%silentDel% %gpg_home%\%conf_backup%
if not defined YUBISET_MAIN_SCRIPT_RUNS rd >nul 2>&1 /S /Q !yubiset_temp_dir!
call %lib_dir%/restart_scdaemon.bat
%ifErr% echo %error_prefix%: Could not restart scdaemon. Exiting. & goto end_with_error
exit /b 0
REM Function end

:end_with_error
endlocal
exit /b 1
:end
endlocal