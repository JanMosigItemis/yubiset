@ECHO OFF
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

echo Now restarting scdaemon..
gpgconf --reload scdaemon
%ifErr% goto end_with_error
echo ..Success!
goto end

:end_with_error
endlocal
exit /b 1

:end
endlocal