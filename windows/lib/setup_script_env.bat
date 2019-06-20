@ECHO OFF
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

::
:: Arg 1: Full path to caller script
:: Arg 2: Full path to yubiset windows script folder
::

set yubiset_version=0.1.0
set me=%~1
set root_folder=%~2..
set error_prefix=ERROR
set LANG=EN
set "ifErr=set foundErr=1&(if errorlevel 0 if not errorlevel 1 set foundErr=)&if defined foundErr"
set "silentDel=del >nul 2>&1"
set "silentCopy=copy >nul 2>&1"
set "TAB=    "
set conf_dir=%root_folder%\conf_templates
set input_dir=%root_folder%\input_files
set key_backups_dir=%root_folder%\key_backups

if not defined TEMP (
	echo Could not identify temporary directory to use. Going to create one.
	set yubiset_temp_dir=%root_folder%\temp
) else (
	set yubiset_temp_dir=%TEMP%\yubiset
)

if not defined YUBISET_MAIN_SCRIPT_RUNS (
	rd /S /Q !yubiset_temp_dir!
	mkdir !yubiset_temp_dir!
	%ifErr% echo %error_prefix%: Could not create temp directory. Exiting. && goto end_with_error
)

for /f "tokens=2 delims= " %%i in ('gpg --version ^| findstr /C:"Home"') do set gpg_home=%%i
%ifErr% echo %error_prefix%: Could not figure out current user's gpg home dir. Exiting. && goto end_with_error

:: Replace forward slashes with backslashes
set gpg_home=!gpg_home:/=\!

goto end

:end_with_error
endlocal
exit /b 1

:end
:: What follows is a trick to get the variables into the context of the calling script (which should be a local context as well) without polluting the global env.
:: See https://stackoverflow.com/a/16167938
endlocal&set "yubiset_version=%yubiset_version%"&set "me=%me%"&set "root_folder=%root_folder%"&set "error_prefix=%error_prefix%"&set "LANG=%LANG%"&set "ifErr=%ifErr%"&set "silentDel=%silentDel%"&set "silentCopy=%silentCopy%"&set "TAB=%TAB%"&set "conf_dir=%conf_dir%"&set "input_dir=%input_dir%"&set "key_backups_dir=%key_backups_dir%"&set "yubiset_temp_dir=%yubiset_temp_dir%"&set "gpg_home=%gpg_home%"&set "temp_must_be_removed=%temp_must_be_removed%"
