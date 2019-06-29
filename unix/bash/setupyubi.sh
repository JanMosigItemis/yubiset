#!/bin/bash

#
# Arg 1: Full name
# Arg 2: email address
# Arg 3: PGP key ID
# Optional Arg 4: Passphrase (will be asked for if omitted)
#

#
# SETUP SECTION
#
if [[ -z "${lib_dir}" ]] ; then declare -r lib_dir=lib ; fi
. "${lib_dir}"/bootstrap.sh
. "${lib_dir}"/lib.sh

cleanup()
{
	remove_tmp_dir_if_standalone
}

pin_setup()
{
	echo
	echo "Remember: Default PIN is 123456 | Default Admin PIN is 12345678"
	{ cat "${pin_input}" | "${YUBISET_GPG_BIN}" --command-fd=0 --status-fd=1 --card-edit --expert >/dev/null 2>&1 ; } || { cleanup; end_with_error "Setting the PINs ran into an error." ; }
	echo "PIN setup successfull!"
}

personal_info()
{
	echo
	echo "First we must collect some personal info of yours.."
	read -p "Enter your language pref (e.g. en): " lang_pref

	while true; do
		local _mw=w
		read -p "Enter your sex (m/[w]): " _mw
		case $_mw in
			[Mm]* ) declare -r sex="m"; break;;
			[Ww]* ) declare -r sex="w"; break;;
			""    ) declare -r sex="w"; break;;
		esac
	done

	echo "admin" >> "${pers_info_input}"
	echo "name" >> "${pers_info_input}"
	echo "${sur_name}" >> "${pers_info_input}"
	echo "${given_name}" >> "${pers_info_input}"
	echo "lang" >> "${pers_info_input}"
	echo "${lang_pref}" >> "${pers_info_input}"
	echo "sex" >> "${pers_info_input}"
	echo "${sex}" >> "${pers_info_input}"
	echo "login" >> "${pers_info_input}"
	echo "${user_email}" >> "${pers_info_input}"
	echo "url" >> "${pers_info_input}"
	echo "https://sks-keyservers.net/pks/lookup?op=get&search=0x${key_id}" >> "${pers_info_input}"

	echo
	if $(are_you_sure "Write personal information to your Yubikey") ; then
		echo Now writing..
		{ cat "${pers_info_input}" | "${YUBISET_GPG_BIN}" --command-fd=0 --status-fd=1 --card-edit --expert >/dev/null 2>&1 ; } || { cleanup; end_with_error "Writing personal data to Yubikey ran into an error." ; }
		echo ..Success!
	fi
}

keytocard() {
	echo "Now moving keys.."
	{ cat "${keytocard_input}" | "${YUBISET_GPG_BIN}" --command-fd=0 --status-fd=1 --pinentry-mode loopback --passphrase "${passphrase}" --edit-key --expert "${key_id}" >/dev/null 2>&1 ; } || { cleanup; end_with_error "Moving GPG keys to Yubikey ran into an error." ; }
	echo ..Success!
}

if [[ -z "${yubiset_main_script_runs}" ]] ; then
	if [[ -z "${1}" ]] ; then { cleanup; end_with_error "Missing arg 1: Full name." ; } fi
	declare -r user_name="${1}"
	if [[ -z "${2}" ]] ; then { cleanup; end_with_error "Missing arg 2: EMail address." ; } fi
	declare -r user_email="${2}"
	if [[ -z "${3}" ]] ; then { cleanup; end_with_error "Missing arg 3: PGP key ID." ; } fi
	# Sanitize the key id: Remove trailing 0x if it exists.
	if [[ "${3}" == 0x* ]] ; then declare -r key_id="${3:2}" ; else declare -r key_id="${3}" ; fi
	if [[ -z "${4}" ]] ; then 
		read -s -p "Please enter your passphrase: " passphrase
	else declare -r passphrase="${4}" ; fi
	
fi

declare -r given_name="${user_name% *}"
declare -r sur_name="${user_name##* }"
declare -r pin_input="${input_dir}/pin.input"
declare -r pers_info_input="${yubiset_temp_dir}/pers_info.input"
declare -r keytocard_input="${input_dir}/keytocard.input"

pretty_print "Yubikey setup and key to card script"
pretty_print "Version: ${yubiset_version}"

#
# PIN SECTION
#
echo
if $(are_you_sure "Should we first setup your Yubikey's PIN and Admin PIN") ; then pin_setup ; fi

#
# PERSONAL INFO SECTION
#
echo
if $(are_you_sure "Should personal info be modified") ; then personal_info ; fi

#
# KEYTOCARD SECTION
#
echo
if $(are_you_sure "Move your subkeys to your Yubikey") ; then keytocard ; fi
