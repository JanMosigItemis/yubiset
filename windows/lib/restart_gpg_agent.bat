@ECHO OFF

::
:: SETUP SECTION
::
echo Now restarting gpg-agent..
gpg-connect-agent reloadagent /bye
%ifErr% exit /b 1
echo ..Success!