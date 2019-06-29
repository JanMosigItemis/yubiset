@ECHO OFF
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

set "ifErr=set foundErr=1&(if errorlevel 0 if not errorlevel 1 set foundErr=)&if defined foundErr"

set powershell_version=Not available
powershell /? >nul 2>&1
%ifErr% ( set powershell_available= & goto end ) else ( set powershell_available=true )

REM https://www.computing.net/answers/programming/batch-get-powershell-version/30090.html
for /f "skip=3 tokens=2 delims=:" %%A in ('powershell -command "get-host"') do (
	set /a n=!n!+1
	set c=%%A
	if !n!==1 set powershell_version=!c!
)
set powershell_version=!powershell_version: =!

:end
REM What follows is a trick to get the variables into the context of the calling script (which should be a local context as well) without polluting the global env.
REM See https://stackoverflow.com/a/16167938
endlocal&set "powershell_version=%powershell_version%"&set "powershell_available=%powershell_available%"