@ECHO OFF
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

REM
REM SETUP SECTION
REM
set lib_dir=lib
call %lib_dir%/bootstrap.bat "%~n0" "%~dp0"
%ifErr% echo %error_prefix%: Bootstraping the script failed. Exiting. & call :cleanup & goto end_with_error
REM Make sure to always set this after bootstrapping, so that the setup script may create the temp dir correctly.
set YUBISET_MAIN_SCRIPT_RUNS=y

set keygen_input=%input_dir%\keygen.input
set keygen_input_copy=%yubiset_temp_dir%\keygen.input.copy
set subkeys_input=%input_dir%\subkeys.input
set revoke_input=%input_dir%\revoke.input
set subkey_length=4096

if "%~1" == "4" (
	set subkeys_input=%input_dir%\subkeys_2048.input
	set subkey_length=2048
)

call %lib_dir%/check_powershell_availability.bat
%ifErr% echo %error_prefix%: Could not find out if Powershell is available or not. & call :cleanup & goto end_with_error

call %lib_dir%/pretty_print.bat "OpenPGP key generation and Yubikey setup script"
call %lib_dir%/pretty_print.bat "Version: %yubiset_version%"
call %lib_dir%/pretty_print.bat ""
call %lib_dir%/pretty_print.bat "gpg home:                %gpg_home%"
call %lib_dir%/pretty_print.bat "Subkey length:           %subkey_length% bit"
call %lib_dir%/pretty_print.bat "Yubiset temp dir:        %yubiset_temp_dir%"
call %lib_dir%/pretty_print.bat "Yubiset key backups dir: %key_backups_dir%"
call %lib_dir%/pretty_print.bat "gpg:                     %YUBISET_GPG_BIN%"
call %lib_dir%/pretty_print.bat "gpg-connect-agent:       %YUBISET_GPG_CONNECT_AGENT%"
call %lib_dir%/pretty_print.bat "gpgconf:                 %YUBISET_GPG_CONF%"
call %lib_dir%/pretty_print.bat "Powershell (optional):   %powershell_version%"
echo.
pause

REM
REM GPG CONF SECTION
REM
echo Should your gpg.conf and gpg-agent.conf files be replaced by the ones provided by Yubiset? If you don't know what this is about, it is safe to say 'y' here. Backup copies of the originals will be created first.
call %lib_dir%/are_you_sure.bat "Replace files"

if defined answerisno goto gpgagent

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
REM
REM GPG AGENT RESTART
REM
echo.
call %lib_dir%/restart_gpg_agent.bat
%ifErr% echo %error_prefix%: Could not restart gpg-agent. Exiting. & call :cleanup & goto end_with_error

REM
REM GPG KEY GENERATION SECTION
REM
echo.
call %lib_dir%/pretty_print.bat "We are now about to generate PGP keys."
echo.
echo First, we need a little information from you.
set /p user_name=Please enter your full name: 
set /p user_email=Please enter your full e-mail address: 
if defined powershell_available (
	call %lib_dir%\mask_user_input.bat "Please enter your passphrase"
	%ifErr% echo %error_prefix%: Could not acquire passphrase from user. & call :cleanup & goto end_with_error
	set passphrase=!masked_user_input!
) else (
	set /p passphrase=Please enter your passphrase: 
)

echo.

call %lib_dir%/branding.bat "%user_name%"
%ifErr% echo %error_prefix%: Could not load key branding information. & call :cleanup & goto end_with_error

%silentCopy% %keygen_input% %keygen_input_copy%
echo %branded_user_name%>> %keygen_input_copy%
echo %user_email%>> %keygen_input_copy%
if defined branded_user_comment (
	REM Some characters are not supported in key comments. See https://github.com/JanMosigItemis/yubiset/issues/4
	set sanitized_user_comment=!branded_user_comment:^(=!
	set sanitized_user_comment=!sanitized_user_comment:^)=!
	echo Found custom user comment branding: !sanitized_user_comment!
	echo !sanitized_user_comment!>> %keygen_input_copy%
) else (
	echo.>> %keygen_input_copy%
)

REM Master key generation
echo Now generating the master key. This may take a while..
type %keygen_input_copy% | gpg --command-fd=0 --status-fd=1 --expert --full-gen-key --pinentry-mode loopback --passphrase %passphrase% >nul 2>&1
%ifErr% echo %error_prefix%: Generating the keypair raised an error. Exiting. & call :cleanup & goto end_with_error
echo ..Success!

REM print secret keys, find all lines beginning with "sec", extract 5th token and store into i. The last value stored into i will be the id of the key just created.
REM Line example: sec:u:4096:1:91E21FE19B31FF56:1558085668:1589621668::u:::cC:::+:::23::0:
for /f "tokens=5 delims=:" %%i in ('gpg -K --with-colons ^| findstr /C:"sec"') do set key_id=%%i
%ifErr% echo %error_prefix%: Could not figure out key id. Exiting. & call :cleanup & goto end_with_error

for /f "tokens=2 delims=:" %%i in ('gpg -K --with-colons ^| findstr /C:"fpr"') do set key_fpr=%%i
%ifErr% echo %error_prefix%: Could not figure out key fingerprint. Exiting. & call :cleanup & goto end_with_error

REM Subkeys generation
echo Now generating subkeys. This may take even longer..
type %subkeys_input% | gpg --command-fd=0 --status-fd=1 --expert --edit-key --pinentry-mode loopback --passphrase %passphrase% %key_id% >nul 2>&1
%ifErr% echo %error_prefix%: Generating subkeys raised an error. Exiting. & call :cleanup & goto end_with_error
echo ..Success!

REM
REM BACKUP SECTION
REM
echo.
echo We are about to backup the generated stuff..
set key_dir=%key_backups_dir%\%key_id%
echo %TAB%Revocation certificate: %key_dir%\%key_id%.rev

REM Does only create intermediate non existing directories if command extensions are enabled which should be the case at this point of the script.
mkdir %key_dir%

type %revoke_input% | gpg --command-fd=0 --status-fd=1 --gen-revoke --pinentry-mode loopback --passphrase %passphrase% -o %key_dir%\%key_id%.rev %key_id% >nul 2>&1
%ifErr% echo %error_prefix%: Could not generate copy of revocation certificate. Exiting. & call :cleanup & goto end_with_error

echo %TAB%Pub key: %key_dir%\%key_id%.pub.asc
gpg --export --armor --pinentry-mode loopback --passphrase %passphrase% -o %key_dir%\%key_id%.pub.asc %key_id% >nul 2>&1
%ifErr% echo %error_prefix%: Could not generate backup of pub key. Exiting. & call :cleanup & goto end_with_error

echo %TAB%Private master key: %key_dir%\%key_id%.priv.asc
gpg --export-secret-keys --armor --pinentry-mode loopback --passphrase %passphrase% -o %key_dir%\%key_id%.priv.asc %key_id% >nul 2>&1
%ifErr% echo %error_prefix%: Could not create backup of priv master key. Exiting. & call :cleanup & goto end_with_error

echo %TAB%Private sub keys: %key_dir%\%key_id%.sub_priv.asc
gpg --export-secret-subkeys --armor --pinentry-mode loopback --passphrase %passphrase% -o %key_dir%\%key_id%.sub_priv.asc %key_id% >nul 2>&1
%ifErr% echo %error_prefix%: Could not create backup of priv sub keys. Exiting. & call :cleanup & goto end_with_error
echo ..Success!

REM
REM REMOVE MASTER KEY SECTION
REM
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

REM
REM KEY SERVER UPLOAD SECTION
REM
:keyserver
echo.
call %lib_dir%/are_you_sure.bat "Should the generated public key be uploaded to your configured keyserver"
if defined answerisno goto key_generation_result
echo Dryrun: gpg --send-keys %key_id%

REM
REM KEY GENERATION RESULT OVERVIEW
REM
:key_generation_result
echo.
call %lib_dir%/pretty_print.bat "Key generation result overview"
call %lib_dir%/pretty_print.bat ""
call %lib_dir%/pretty_print.bat "Your key id: %key_id%"
call %lib_dir%/pretty_print.bat "Your key fingerprint: %key_fpr%"
call %lib_dir%/pretty_print.bat "Backups are in: %key_dir%"

REM
REM YUBIKEY SECTION
REM
echo.
call %lib_dir%/are_you_sure.bat "Should we continue with setting up your YubiKey"
if defined answerisno goto end

echo Checking if we can access your Yubikey..
call findyubi.bat
%ifErr% echo %error_prefix%: Could not communicate with your Yubikey. Exiting. & call :cleanup & goto end_with_error
echo Ok, Yubikey communication works!

REM
REM RESET YUBIKEY
REM
echo.
echo Now we must reset the OpenPGP module of your Yubikey..
call resetyubi.bat
%ifErr% echo %error_prefix%: Resetting YubiKey ran into an error. Exiting. & call :cleanup & goto end_with_error

REM
REM YUBIKEY SETUP AND KEYTOCARD
REM
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
rd >nul 2>&1 /S /Q !yubiset_temp_dir!
exit /b 0

:end_with_error
endlocal
exit /b 1

:end
endlocal
