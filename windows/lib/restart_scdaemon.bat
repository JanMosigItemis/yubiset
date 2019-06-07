@ECHO OFF

::
:: SETUP SECTION
::
echo Now restarting scdaemon..
gpgconf --reload scdaemon
%ifErr% exit /b 1
echo ..Success!

:end
