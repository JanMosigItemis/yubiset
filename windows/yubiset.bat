@ECHO OFF
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

set LANG=EN
set me=%~n0
set root_folder=%~dp0\..
set "ifErr=set foundErr=1&(if errorlevel 0 if not errorlevel 1 set foundErr=)&if defined foundErr"
set "silentDel=del >nul 2>&1"
set "silentCopy=copy >nul 2>&1"

set keygen_input=%root_folder%\keygen.input
set keygen_input_copy=%root_folder%\keygen.input.copy
set subkeys_input=%root_folder%\subkeys.input
if "%~1" == "4" set subkeys_input=%root_folder%\subkeys_2048.input
set revoke_input=%root_folder%\revoke.input

echo.
echo .....^| OpenPGP key generation and Yubikey setup script ^|.....
echo.

echo Should your gpg.conf and gpg-agent.conf files be replaced by the ones provided by Yubiset? If you don't know what this is about, it is safe to say 'y' here. Backup copies of the originals will be created first.
set areyousure=
set /p areyousure="Replace files (y/[n])? "
if /I "!areyousure!" NEQ "y" goto gpgagent
for /f "tokens=2 delims= " %%i in ('gpg --version ^| findstr /C:"Home"') do set gpg_home=%%i
%ifErr% echo %me%: Could not figure out current user's gpg home dir. Exiting. && goto end
set gpg_home=!gpg_home:/=\!
echo.
echo %me%: %USERNAME%'s gpg home dir is: %gpg_home%
echo %me:% Making  backup copies..

if exist %gpg_home%\gpg.conf (
	echo %gpg_home%\gpg.conf.backup.by.yubiset
	copy %gpg_home%\gpg.conf %gpg_home%\gpg.conf.backup.by.yubiset /Y
	%ifErr% echo %me%: Creating backup of gpg.conf failed. Exiting. && goto end
)

if exist %gpg_home%\gpg-agent.conf (
	echo %gpg_home%\gpg-agent.conf.backup.by.yubiset
	copy %gpg_home%\gpg-agent.conf %gpg_home%\gpg-agent.conf.backup.by.yubiset /Y
	%ifErr% echo %me%: Creating backup of gpg-agent.conf failed. Exiting. && goto end
)

%silentCopy% %root_folder%\gpg.conf %gpg_home%\gpg.conf /Y
%ifErr% echo %me%: Replacing gpg.conf failed. Exiting. && goto end
%silentCopy% %root_folder%\gpg-agent.conf %gpg_home%\gpg-agent.conf /Y
%ifErr% echo %me%: Replacing gpg-agent.conf failed. Exiting. && goto end

:gpgagent
echo. 
echo %me%: Making sure that the gpg-agent is running..
gpg-connect-agent reloadagent /bye
%ifErr% echo Seems like the gpg-agent could not be started. Exiting. && goto end

echo.
echo Now collecting data for GPG key generation..
set /p user_name=Please enter your full name: 
set /p user_email=Please enter your full e-mail address: 
set /p passphrase=Please enter your passphrase: 

copy %keygen_input% %keygen_input_copy%
echo %user_name% (itemis AG)>> %keygen_input_copy%
echo %user_email%>> %keygen_input_copy%
echo Vocational OpenPGP key of itemis AG's %user_name%>> %keygen_input_copy%

type %keygen_input_copy% | gpg --command-fd=0 --status-fd=1 --expert --full-gen-key --pinentry-mode loopback --passphrase %passphrase%
%ifErr% echo %me%: Generating the keypair raised an error. Exiting. && goto end

:: find print secret keys, find all lines beginning with "sec", extract 5th token and store into i. The last value stored into i will be the id of the key just created.
:: Line example: sec:u:4096:1:91E21FE19B31FF56:1558085668:1589621668::u:::cC:::+:::23::0:
for /f "tokens=5 delims=:" %%i in ('gpg -K --with-colons ^| findstr /C:"sec"') do set key_id=%%i
%ifErr% echo %me%: Could not figure out key id. Exiting. && goto end

for /f "tokens=2 delims=:" %%i in ('gpg -K --with-colons ^| findstr /C:"fpr"') do set key_fpr=%%i
%ifErr% echo %me%: Could not figure out key fingerprint. Exiting. && goto end

echo %me%: Now generating subkeys..
type %subkeys_input% | gpg --command-fd=0 --status-fd=1 --expert --edit-key --pinentry-mode loopback --passphrase %passphrase% %key_id%

set key_dir=%root_folder%\%key_id%
mkdir %key_dir%

echo.
echo %me%: Now creating backup of revocation certificate: %key_dir%\%key_id%.rev
type %revoke_input% | gpg --command-fd=0 --status-fd=1 --output %key_dir%\%key_id%.rev --gen-revoke --pinentry-mode loopback --passphrase %passphrase% %key_id%
%ifErr% echo %me%: Could not generate copy of revocation certificate. Exiting. && goto end

echo.
echo %me%: Now creating backup of pub key: %key_dir%\%key_id%.pub.asc
gpg --export --armor --pinentry-mode loopback --passphrase %passphrase% %key_id% > %key_dir%\%key_id%.pub.asc
%ifErr% echo %me%: Could not generate backup of pub key. Exiting. && goto end

echo.
echo %me%: Now creating backup of priv master key: %key_dir%\%key_id%.priv.asc
gpg --export-secret-keys --armor --pinentry-mode loopback --passphrase %passphrase% %key_id% > %key_dir%\%key_id%.priv.asc
%ifErr% echo %me%: Could not create backup of priv master key. Exiting. && goto end

echo.
echo %me%: Now creating backup of priv sub keys: %key_dir%\%key_id%.sub_priv.asc
gpg --export-secret-subkeys --armor --pinentry-mode loopback --passphrase %passphrase% %key_id% > %key_dir%\%key_id%.sub_priv.asc
%ifErr% echo %me%: Could not create backup of priv sub keys. Exiting. && goto end

echo.
echo To increase security, it is a good idea to delete the master key.
set areyousure=
set /p areyousure="Should the master key be deleted (y/[n])? "
if /I "!areyousure!" NEQ "y" goto keyserver
gpg --batch --yes --delete-secret-keys --pinentry-mode loopback --passphrase %passphrase% %key_fpr%
%ifErr% echo %me%: Could not delete private master key. Exiting. && goto end
gpg --pinentry-mode loopback --passphrase %passphrase% --import %key_dir%\%key_id%.sub_priv.asc

:keyserver
echo.
set areyousure=
set /p areyousure="Should this key be uploaded to your configured keyserver (y/[n])? "
if /I "!areyousure!" NEQ "y" goto result
echo %me%: Dryrun: gpg --send-keys %key_id%

:result
echo.
echo .....^| Your key id: %key_id% ^|.....
echo .....^| Your key fingerprint: %key_fpr% ^|.....
echo.

echo.
set areyousure=
set /p areyousure="All done! Should we continue with setting up your YubiKey (y/[n])? "
if /I "!areyousure!" NEQ "y" goto end

echo.
gpg --card-status 2>&1 >nul
%ifErr% (
	set areyousure=
	set /p areyousure="Looks like your YubiKey cannot be found. This is most likely, because your GPG does not know which card reader to use. Should we try setting things up for you (y/[n])? "
	if /I "!areyousure!"=="y" (
		call yubi_find.bat
		%ifErr% echo %me%: Could not find your Yubikey. Exiting. && goto end
	) else (
		echo Can't continue without a properly recognized Yubikey. Exiting. goto end
	)
)

echo.
call reset_yubi.bat
%ifErr% echo %me%: Resetting YubiKey ran into an error. Exiting. && goto end

:setupYubi
call setup_yubi.bat "%user_name%" "%user_email%" %key_id% "%passphrase%"
%ifErr% echo %me%: Setting up your YubiKey ran into an error. Exiting. && goto end

echo.
echo .....^| Done! ^|.....
echo.

:end
%silentDel% %keygen_input_copy%
endlocal


