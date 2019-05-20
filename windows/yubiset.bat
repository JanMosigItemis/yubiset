@ECHO OFF
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

set me=%~n0
set root_folder=%~dp0\..
set "ifErr=set foundErr=1&(if errorlevel 0 if not errorlevel 1 set foundErr=)&if defined foundErr"
set "silentDel=del >nul 2>&1"

set keygen_input=%root_folder%\keygen.input
set keygen_input_copy=%root_folder%\keygen.input.copy
set subkeys_input=%root_folder%\subkeys.input
set revoke_input=%root_folder%\revoke.input

echo.
echo .....^| OpenPGP key generation and Yubikey setup script ^|.....
echo.

set LANG=EN

echo %me%: Making sure that the gpg-agent is running..
gpg-connect-agent reloadagent /bye
%ifErr% echo Seems like the gpg-agent could not be started. Exiting. && goto end

echo.
echo %me%: Generating your key pair..
set /p user_name=Enter your full name: 
set /p user_email=enter your full e-mail address: 

copy %keygen_input% %keygen_input_copy%
echo %user_name% (itemis AG) >> %keygen_input_copy%
echo %user_email% >> %keygen_input_copy%
echo Vocational OpenPGP key of itemis AG's %user_name% >> %keygen_input_copy%

echo %keygen_input_copy%
type %keygen_input_copy% | gpg --command-fd=0 --status-fd=1 --expert --full-gen-key
%ifErr% echo %me%: Generating the keypair raised an error. Exiting. && goto end

:: find print secret keys, find all lines beginning with "sec", extract 5th token and store into i. The last value stored into i will be the id of the key just created.
:: Line example: sec:u:4096:1:91E21FE19B31FF56:1558085668:1589621668::u:::cC:::+:::23::0:
for /f "tokens=5 delims=:" %%i in ('gpg -K --with-colons ^| findstr /C:"sec"') do set key_id=%%i
%ifErr% echo %me%: Could not figure out key id. Exiting. && goto end

for /f "tokens=2 delims=:" %%i in ('gpg -K --with-colons ^| findstr /C:"fpr"') do set key_fpr=%%i
%ifErr% echo %me%: Could not figure out key fingerprint. Exiting. && goto end

echo %me%: Now generating subkeys..
type %subkeys_input% | gpg --command-fd=0 --status-fd=1 --expert --edit-key %key_id%

set key_dir=%root_folder%\%key_id%
mkdir %key_dir%

echo.
echo %me%: Now creating backup of revocation certificate: %key_dir%\%key_id%.rev
type %revoke_input% | gpg --command-fd=0 --status-fd=1 --output %key_dir%\%key_id%.rev --gen-revoke %key_id%
%ifErr% echo %me%: Could not generate copy of revocation certificate. Exiting. && goto end

echo.
echo %me%: Now creating backup of pub key: %key_dir%\%key_id%.pub.asc
gpg --export --armor %key_id% > %key_dir%\%key_id%.pub.asc
%ifErr% echo %me%: Could not generate backup of pub key. Exiting. && goto end

echo.
echo %me%: Now creating backup of priv master key: %key_dir%\%key_id%.priv.asc
gpg --export-secret-keys --armor %key_id% > %key_dir%\%key_id%.priv.asc
%ifErr% echo %me%: Could not create backup of priv master key. Exiting. && goto end

echo.
echo %me%: Now creating backup of priv sub keys: %key_dir%\%key_id%.sub_priv.asc
gpg --export-secret-subkeys --armor %key_id% > %key_dir%\%key_id%.sub_priv.asc
%ifErr% echo %me%: Could not create backup of priv sub keys. Exiting. && goto end

echo.
echo To increase security, it is a good idea to delete the master key.
set areyousure=
set /p areyousure="Should the master key be deleted (y/[n])? "
if /I "%areyousure%" NEQ "y" goto keyserver
gpg --batch --yes --delete-secret-keys %key_fpr%
%ifErr% echo %me%: Could not delete private master key. Exiting. && goto end
gpg --import %key_dir%\%key_id%.sub_priv.asc

:keyserver
echo.
set areyousure=
set /p areyousure="Should this key be uploaded to your configured keyserver (y/[n])? "
if /I "%areyousure%" NEQ "y" goto result
echo %me%: Dryrun: gpg --send-keys %key_id%

:result
echo.
echo .....^| Your key id: %key_id% ^|.....
echo .....^| Your key fingerprint: %key_fpr% ^|.....
echo.

echo.
echo .....^| Done! ^|.....
echo.

:end
%silentDel% %keygen_input_copy%
endlocal


