@ECHO OFF

set yubiset_version=1.0.0
set me=%~1
set root_folder=%~2..
set "error_prefix=ERROR"
set LANG=EN
set "ifErr=set foundErr=1&(if errorlevel 0 if not errorlevel 1 set foundErr=)&if defined foundErr"
set "silentDel=del >nul 2>&1"
set "silentCopy=copy >nul 2>&1"
set "TAB=    "
set conf_dir=%root_folder%\conf_templates
set input_dir=%root_folder%\input_files

for /f "tokens=2 delims= " %%i in ('gpg --version ^| findstr /C:"Home"') do set gpg_home=%%i
%ifErr% echo %error_prefix%: Could not figure out current user's gpg home dir. Exiting. && exit /b 1

:: Replace forward slashes with backslashes
set gpg_home=!gpg_home:/=\!
:: echo %USERNAME%'s gpg home dir is: %gpg_home%
