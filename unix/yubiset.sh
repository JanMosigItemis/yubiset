#!/bin/bash

declare -r lib_dir=lib
. "${lib_dir}"/bootstrap.sh
. "${lib_dir}"/helper.sh
declare -r yubiset_main_script_runs=true

declare -r keygen_input="${input_dir}"/keygen.input
declare -r keygen_input_copy="${temp_dir}"/keygen.input.copy
if [[ "${1}" -eq "4" ]]; then 
	declare -r subkey_length=2048
	declare -r subkeys_input="${input_dir}"/subkeys_2048.input
else
	declare -r subkey_length=4096
	declare -r subkeys_input="${input_dir}"/subkeys.input
fi

declare -r revoke_input="${input_dir}"/revoke.input

pretty_print "OpenPGP key generation and Yubikey setup script"
pretty_print "Version: ${yubiset_version}"
pretty_print
pretty_print "gpg home: ${gpg_home}"
pretty_print "Subkey length: ${subkey_length} bit"
pretty_print "Yubiset tmp dir: ${temp_dir}"
pretty_print "gpg: ${YUBISET_GPG_BIN}"
pretty_print "gpg-connect-agent: ${YUBISET_GPG_CONNECT_AGENT}"
pretty_print "gpgconf: ${YUBISET_GPG_CONF}"
echo

press_any_key

cleanup()
{
	silentDel "${keygen_input_copy}"
	silentDel "${temp_dir}"
	echo
}

create_conf_backup()
{
	echo Now making backup copies..

	if [[ -f "${gpg_home}/gpg.conf" ]]; then
		echo "${gpg_home}/gpg.conf => ${gpg_home}/gpg.conf.backup.by.yubiset"
		cp -f "${gpg_home}/gpg.conf" "${gpg_home}/gpg.conf.backup.by.yubiset" || { cleanup; end_with_error "Creating backup of gpg.conf failed."; }
	fi

	if [[ -f "${gpg_home}/gpg-agent.conf" ]]; then
		echo "${gpg_home}/gpg-agent.conf => ${gpg_home}/gpg-agent.conf.backup.by.yubiset"
		cp -f "${gpg_home}/gpg-agent.conf" "${gpg_home}/gpg-agent.conf.backup.by.yubiset" || { cleanup; end_with_error "Creating backup of gpg-agent.conf failed."; }
	fi
	echo ..Success!
	echo
	echo "Now copying yubiset's conf files.."
	silentCopy "${conf_dir}/gpg.conf" "${gpg_home}/gpg.conf" || { cleanup; end_with_error "Replacing gpg.conf failed."; }
	silentCopy "${conf_dir}/gpg-agent.conf" "${gpg_home}/gpg-agent.conf" || { cleanup; end_with_error "Replacing gpg-agent.conf failed."; }
	echo ..Success!
}

delete_master_key()
{
	echo Removing..
	{ "${YUBISET_GPG_BIN}" --batch --yes --delete-secret-keys --pinentry-mode loopback --passphrase "${passphrase}" "${key_fpr}" ; } || { cleanup; end_with_error "Could not delete private master key." ; }
	echo ..Success!

	echo Reimporting private sub keys..
	{ "${YUBISET_GPG_BIN}" --pinentry-mode loopback --passphrase "${passphrase}" --import "${key_dir}/${key_id}.sub_priv.asc" ; } || { cleanup; end_with_error "Re-import of private sub keys failed." ; }
	echo ..Success!
}

#
# GPG CONF SECTION
#
echo "Should your gpg.conf and gpg-agent.conf files be replaced by the ones provided by Yubiset? If you don't know what this is about, it is safe to say 'y' here. Backup copies of the originals will be created first."
if $(are_you_sure "Replace files") ; then create_conf_backup; fi

#
# GPG AGENT RESTART
#
echo
restart_gpg_agent || { cleanup; end_with_error "Could not restart gpg-agent."; }

#
# GPG KEY GENERATION SECTION
#
echo 
pretty_print "We are now about to generate PGP keys."
echo
echo "First, we need a little information from you."
read -p "Please enter your full name: " user_name
read -p "Please enter your full e-mail address: " user_email
read -s -p "Please enter your passphrase: " passphrase

silentCopy "${keygen_input}" "${keygen_input_copy}"
echo "${user_name} (itemis AG)" >> "${keygen_input_copy}"
echo "${user_email}" >> "${keygen_input_copy}"
echo "Vocational OpenPGP key of itemis AG's ${user_name}" >> "${keygen_input_copy}"

# Master key generation
echo
echo "Now generating the master key. This may take a while.."
{ cat "${keygen_input_copy}" | "${YUBISET_GPG_BIN}" --command-fd=0 --status-fd=1 --expert --full-gen-key --pinentry-mode loopback --passphrase "${passphrase}" ; } || { cleanup; end_with_error "Generating the keypair raised an error." ; }
echo ..Success!

# Print secret keys, reverse order, find all lines beginning with "sec", extract 5th token and return.
# The last secret key displayed will be the key just created, thus the reversal of print order.
# Line example: sec:u:4096:1:91E21FE19B31FF56:1558085668:1589621668::u:::cC:::+:::23::0:
declare -r key_id=$( { "${YUBISET_GPG_BIN}" -K --with-colons | tac | grep -i -m1 "sec" | cut -d ":" -f5 ; } || { cleanup; end_with_error "Could not figure out id of generated key." ; } )

# tr is used for replacing multiple ::: with only one :. Its a sort of normalization of the output of gpg -K
declare -r key_fpr=$( { "${YUBISET_GPG_BIN}" -K --with-colons | tac | grep -i -m1 "fpr" | tr -s ":" | cut -d ":" -f2;} || { cleanup; end_with_error "Could not figure out fingerprint of generated key."; } )

# Subkey generation
echo
echo Now generating subkeys. This may take even longer..
{ cat "${subkeys_input}" | "${YUBISET_GPG_BIN}" --command-fd=0 --status-fd=1 --expert --edit-key --pinentry-mode loopback --passphrase "${passphrase}" "${key_id}" ; } || { cleanup; end_with_error "Generating subkeys raised an error." ; }
echo ..Success!

#
# BACKUP SECTION
#
echo
echo We are about to backup the generated stuff..
declare -r key_dir="${key_backups_dir}/${key_id}"
printf "\t"
echo "Revocation certificate: ${key_dir}/${key_id}.rev"

mkdir -p "${key_dir}" || { cleanup; end_with_error "Could not generate copy of revocation certificate." ; }

printf "\t"
echo "Pub key: ${key_dir}/${key_id}.pub.asc"
{ "${YUBISET_GPG_BIN}" --export --armor --pinentry-mode loopback --passphrase "${passphrase}" "${key_id}" > "${key_dir}/${key_id}.pub.asc" ; } || { cleanup; end_with_error "Could not generate backup of pub key." ; }

printf "\t"
echo "Private master key: ${key_dir}/${key_id}.priv.asc"
{ "${YUBISET_GPG_BIN}" --export-secret-keys --armor --pinentry-mode loopback --passphrase "${passphrase}" "${key_id}" > "${key_dir}/${key_id}.priv.asc" ; } || { cleanup; end_with_error "Could not create backup of priv master key." ; }

printf "\t"
echo "Private sub keys: ${key_dir}/${key_id}.sub_priv.asc"
{ "${YUBISET_GPG_BIN}" --export-secret-subkeys --armor --pinentry-mode loopback --passphrase "${passphrase}" "${key_id}" > "${key_dir}/${key_id}.sub_priv.asc" ; } || { cleanup; end_with_error "Could not create backup of priv sub key." ; }
echo ..Success!

#
# REMOVE MASTER KEY SECTION
#
echo
echo "To increase security, it is a good idea to delete the master key."
if $(are_you_sure "Delete master key") ; then delete_master_key; fi

#
# KEY SERVER UPLOAD SECTION
#
echo
if $(are_you_sure "Should the generated public key be uploaded to your configured keyserver") ; then
	echo Dryrun: gpg --send-keys "${key_id}"
fi

#
# KEY GENERATION RESULT OVERVIEW
#
echo 
pretty_print "Key generation result overview"
pretty_print ""
pretty_print "Your key id: ${key_id}"
pretty_print "Your key fingerprint: ${key_fpr}"
pretty_print "Backups are in: ${key_dir}"

#
# YUBIKEY SECTION
#
echo
if ! $(are_you_sure "Should we continue with setting up your YubiKey") ; then cleanup; exit 0 ; fi

echo Checking if we can access your Yubikey..
(. ./findyubi.sh) || { cleanup; end_with_error "Could not communicate with your Yubikey." ; }
echo "Ok, Yubikey communication is working!"

#
# RESET YUBIKEY
#
echo
echo Now we must reset the OpenPGP module of your Yubikey..
(. ./resetyubi.sh) || { cleanup; end_with_error "Resetting YubiKey ran into an error." ; }

#
# YUBIKEY SETUP AND KEYTOCARD
#
echo
echo Now we need to setup your Yubikey and move the generated subkeys to it..
(. ./setupyubi.sh) || { cleanup; end_with_error "Setting up your Yubikey ran into an error." ; }

pretty_print "All done! Exiting now."

cleanup
