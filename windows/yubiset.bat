@ECHO OFF
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

::
:: SETUP SECTION
::
set lib_dir=lib
call %lib_dir%/setup_script_env.bat "%~n0" "%~dp0"
%ifErr% echo %error_prefix%: Bootstraping the script failed. Exiting. & call :cleanup & goto end_with_error
:: Make sure to always set this after bootstrapping, so that the setup script may create the temp dir correctly.
set YUBISET_MAIN_SCRIPT_RUNS=y

call %lib_dir%/pretty_print.bat "OpenPGP key generation and Yubikey setup script"
call %lib_dir%/pretty_print.bat "Version: %yubiset_version%"

set keygen_input=%input_dir%\keygen.input
set keygen_input_copy=%yubiset_temp_dir%\keygen.input.copy
set subkeys_input=%input_dir%\subkeys.input
set revoke_input=%input_dir%\revoke.input
set subkey_length=4096

if "%~1" == "4" (
	set subkeys_input=%input_dir%\subkeys_2048.input
	set subkey_length=2048
)
call %lib_dir%/pretty_print.bat "Subkeys will have keylength: %subkey_length% bit."
call %lib_dir%/pretty_print.bat "Using %yubiset_temp_dir% as temporary directory."

echo.
pause
::
:: GPG CONF SECTION
::
echo Should your gpg.conf and gpg-agent.conf files be replaced by the ones provided by Yubiset? If you don't know what this is about, it is safe to say 'y' here. Backup copies of the originals will be created first.
call %lib_dir%/are_you_sure.bat "Replace files"

if defined answerisno goto gpgagent

echo.
call %lib_dir%/pretty_print.bat "%USERNAME%'s gpg home dir is: %gpg_home%"
echo.
echo Now making backup copies..

if exist %gpg_home%\gpg.conf (
	echo %gpg_home%\gpg.conf.backup.by.yubiset
	copy %gpg_home%\gpg.conf %gpg_home%\gpg.conf.backup.by.yubiset /Y
	%ifErr% echo %error_prefix%: Creating backup of gpg.conf failed. Exiting. & call :cleanup & goto end_with_error
)

if exist %gpg_home%\gpg-agent.conf (
	echo %gpg_home%\gpg-agent.conf.backup.by.yubiset
	copy %gpg_home%\gpg-agent.conf %gpg_home%\gpg-agent.conf.backup.by.yubiset /Y
	%ifErr% echo %error_prefix%: Creating backup of gpg-agent.conf failed. Exiting. & call :cleanup & goto end_with_error
)

%silentCopy% %conf_dir%\gpg.conf %gpg_home%\gpg.conf /Y
%ifErr% echo %error_prefix%: Replacing gpg.conf failed. Exiting. & call :cleanup & goto end_with_error
%silentCopy% %conf_dir%\gpg-agent.conf %gpg_home%\gpg-agent.conf /Y
%ifErr% echo %error_prefix%: Replacing gpg-agent.conf failed. Exiting. & call :cleanup & goto end_with_error
echo ..Success!

:gpgagent
::
:: GPG AGENT RESTART
::
echo.
call %lib_dir%/restart_gpg_agent.bat
%ifErr% echo %error_prefix%: Could not restart gpg-agent. Exiting. & call :cleanup & goto end_with_error

::
:: GPG KEY GENERATION SECTION
::
echo.
call %lib_dir%/pretty_print.bat "We are now about to generate PGP keys."
echo.
echo First, we need a little information from you.
set /p user_name=Please enter your full name: 
set /p user_email=Please enter your full e-mail address: 
set /p passphrase=Please enter your passphrase: 

copy %keygen_input% %keygen_input_copy%
echo %user_name% (itemis AG)>> %keygen_input_copy%
echo %user_email%>> %keygen_input_copy%
echo Vocational OpenPGP key of itemis AG's %user_name%>> %keygen_input_copy%

:: Master key generation
echo.
echo Now generating the master key. This may take a while..
type %keygen_input_copy% | gpg --command-fd=0 --status-fd=1 --expert --full-gen-key --pinentry-mode loopback --passphrase %passphrase%
%ifErr% echo %error_prefix%: Generating the keypair raised an error. Exiting. & call :cleanup & goto end_with_error
echo ..Success!

:: print secret keys, find all lines beginning with "sec", extract 5th token and store into i. The last value stored into i will be the id of the key just created.
:: Line example: sec:u:4096:1:91E21FE19B31FF56:1558085668:1589621668::u:::cC:::+:::23::0:
for /f "tokens=5 delims=:" %%i in ('gpg -K --with-colons ^| findstr /C:"sec"') do set key_id=%%i
%ifErr% echo %error_prefix%: Could not figure out key id. Exiting. & call :cleanup & goto end_with_error

for /f "tokens=2 delims=:" %%i in ('gpg -K --with-colons ^| findstr /C:"fpr"') do set key_fpr=%%i
%ifErr% echo %error_prefix%: Could not figure out key fingerprint. Exiting. & call :cleanup & goto end_with_error

:: Subkeys generation
echo Now generating subkeys. This may take even longer..
type %subkeys_input% | gpg --command-fd=0 --status-fd=1 --expert --edit-key --pinentry-mode loopback --passphrase %passphrase% %key_id%
%ifErr% echo %error_prefix%: Generating subkeys raised an error. Exiting. & call :cleanup & goto end_with_error
echo ..Success!

::
:: BACKUP SECTION
::
echo.
echo We are about to backup the generated stuff..
set key_dir=%key_backups_dir%\%key_id%
echo %TAB%Revocation certificate: %key_dir%\%key_id%.rev

:: Does only create intermediate non existing directories if command extensions are enabled which should be the case at this point of the script.
mkdir %key_dir%

type %revoke_input% | gpg --command-fd=0 --status-fd=1 --output %key_dir%\%key_id%.rev --gen-revoke --pinentry-mode loopback --passphrase %passphrase% %key_id%
%ifErr% echo %error_prefix%: Could not generate copy of revocation certificate. Exiting. & call :cleanup & goto end_with_error

echo %TAB%Pub key: %key_dir%\%key_id%.pub.asc
gpg --export --armor --pinentry-mode loopback --passphrase %passphrase% %key_id% > %key_dir%\%key_id%.pub.asc
%ifErr% echo %error_prefix%: Could not generate backup of pub key. Exiting. & call :cleanup & goto end_with_error

echo %TAB%Private master key: %key_dir%\%key_id%.priv.asc
gpg --export-secret-keys --armor --pinentry-mode loopback --passphrase %passphrase% %key_id% > %key_dir%\%key_id%.priv.asc
%ifErr% echo %error_prefix%: Could not create backup of priv master key. Exiting. & call :cleanup & goto end_with_error

echo %TAB%Private sub keys: %key_dir%\%key_id%.sub_priv.asc
gpg --export-secret-subkeys --armor --pinentry-mode loopback --passphrase %passphrase% %key_id% > %key_dir%\%key_id%.sub_priv.asc
%ifErr% echo %error_prefix%: Could not create backup of priv sub keys. Exiting. & call :cleanup & goto end_with_error
echo ..Success!

::
:: REMOVE MASTER KEY SECTION
::
echo.
echo To increase security, it is a good idea to delete the master key.
call %lib_dir%/are_you_sure.bat "Delete master key"
if defined answerisno goto keyserver

echo Removing..
gpg --batch --yes --delete-secret-keys --pinentry-mode loopback --passphrase %passphrase% %key_fpr%
%ifErr% echo %error_prefix%: Could not delete private master key. Exiting. & call :cleanup & goto end_with_error
echo ..Success^!

echo Reimporting private sub keys..
gpg --pinentry-mode loopback --passphrase %passphrase% --import %key_dir%\%key_id%.sub_priv.asc
%ifErr% echo %error_prefix%: Re-import of private sub keys failed. Exiting. & call :cleanup & goto end_with_error
echo ..Success^!

::
:: KEY SERVER UPLOAD SECTION
::
:keyserver
echo.
call %lib_dir%/are_you_sure.bat "Should the generated public key be uploaded to your configured keyserver"
if defined answerisno goto key_generation_result
echo Dryrun: gpg --send-keys %key_id%

::
:: KEY GENERATION RESULT OVERVIEW
::
:key_generation_result
echo.
call %lib_dir%/pretty_print.bat "Key generation result overview"
call %lib_dir%/pretty_print.bat ""
call %lib_dir%/pretty_print.bat "Your key id: %key_id%"
call %lib_dir%/pretty_print.bat "Your key fingerprint: %key_fpr%"
call %lib_dir%/pretty_print.bat "Backups are in: %key_dir%"

::
:: YUBIKEY SECTION
::
echo.
call %lib_dir%/are_you_sure.bat "Should we continue with setting up your YubiKey"
if defined answerisno goto end

echo Checking if we can access your Yubikey..
call findyubi.bat
%ifErr% echo %error_prefix%: Could not communicate with your Yubikey. Exiting. & call :cleanup & goto end_with_error

::
:: RESET YUBIKEY
::
echo.
echo Ok, now we must reset the OpenPGP module of your Yubikey..
call resetyubi.bat
%ifErr% echo %error_prefix%: Resetting YubiKey ran into an error. Exiting. & call :cleanup & goto end_with_error

::
:: YUBIKEY SETUP AND KEYTOCARD
::
echo.
echo Now we need to setup your Yubikey and move the generated subkeys to it..
:setupYubi
call setupyubi.bat "%user_name%" "%user_email%" %key_id% "%passphrase%"
%ifErr% echo %error_prefix%: Setting up your Yubikey ran into an error. Exiting. & call :cleanup & goto end_with_error

call %lib_dir%/pretty_print.bat "All done! Exiting now."

call :cleanup
goto end

:cleanup
set YUBISET_MAIN_SCRIPT_RUNS=
%silentDel% %keygen_input_copy%
rd /S /Q %yubiset_temp_dir%
exit /b 0

:end_with_error
endlocal
exit /b 1

:end
endlocal
