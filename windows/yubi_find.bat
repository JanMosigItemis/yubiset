@ECHO OFF
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

set LANG=EN
set me=%~n0
set root_folder=%~dp0\..
set "ifErr=set foundErr=1&(if errorlevel 0 if not errorlevel 1 set foundErr=)&if defined foundErr"
set "silentDel=del >nul 2>&1"
set "silentCopy=copy >nul 2>&1"

set conf_backup=scdaemon.conf.orig
set scdaemon_log=%root_folder%\scdaemon.log

echo In order to find the correct card slot, we need to switch scdaemon into debug mode. This is done via a change to the config file. We are going to reset the changes, when we are done.
set areyousure=
set /p areyousure="Activate scdaemon debug mode (y/[n])? "
if /I "!areyousure!" NEQ "y" goto cleanup

for /f "tokens=2 delims= " %%i in ('gpg --version ^| findstr /C:"Home"') do set gpg_home=%%i
%ifErr% echo %me%: Could not figure out current user's gpg home dir. Exiting. && goto cleanup
set gpg_home=!gpg_home:/=\!
echo %me%: %USERNAME%'s gpg home dir is: %gpg_home%

echo Creating backup: %gpg_home%\%conf_backup%
%silentCopy% %gpg_home%\scdaemon.conf %gpg_home%\%conf_backup% /Y
%ifErr% echo %me%: Could not create backup file. Exiting. && goto cleanup

echo ^#Start: Temporarily added by Yubiset >> %gpg_home%\scdaemon.conf
echo log-file %scdaemon_log% >> %gpg_home%\scdaemon.conf
echo debug-level guru >> %gpg_home%\scdaemon.conf
echo debug-all >> %gpg_home%\scdaemon.conf
echo ^#End: Temporarily added by Yubiset >> %gpg_home%\scdaemon.conf

echo.
echo Please remove your YubiKey.
pause

echo Ok, now restarting gpg-agent..
gpg-connect-agent reloadagent /bye
%ifErr% echo Seems like the gpg-agent could not be started. Exiting. && goto end

echo Ok, now restarting scdaemon..
gpgconf --reload scdaemon
%ifErr% echo %me%: Could not restart scdaemon. Exiting. && goto cleanup

echo Please insert your YubiKey.
pause

echo Ok, now running gpg --card-status
gpg --card-status

echo.
echo Ok, now switching off debug mode.
%silentCopy% %gpg_home%\%conf_backup% %gpg_home%\scdaemon.conf /Y
%silentDel% %gpg_home%\%conf_backup%
gpgconf --reload scdaemon

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
		set areyousure=
		set /p areyousure="Found reader port '%reader_port_candidate%' - Is this the right one (y/[n])? "
		if /I "!areyousure!" EQU "y" goto addReaderToConf
	)
)
echo Could not find any viable readers.
goto cleanup

:addReaderToConf
%silentCopy% %gpg_home%\%conf_backup% %gpg_home%\scdaemon.conf /Y
%silentDel% %gpg_home%\%conf_backup%
%silentDel% %scdaemon_log%
echo reader-port "%reader_port_candidate%">> %gpg_home%\scdaemon.conf
echo Ok, now restarting scdaemon..
gpgconf --reload scdaemon
%ifErr% echo %me%: Could not restart scdaemon. Exiting. && goto cleanup
echo Done.
goto end

:cleanup
%silentCopy% %gpg_home%\%conf_backup% %gpg_home%\scdaemon.conf /Y
%silentDel% %gpg_home%\%conf_backup%
%silentDel% %scdaemon_log%
goto end

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

:end