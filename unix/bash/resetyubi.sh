#!/bin/bash

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

pretty_print "Yubikey reset script"
pretty_print "Version: ${yubiset_version}"
echo

if ! $(are_you_sure "About to reset your YubiKey's OpenPGP module. Continue") ; then { cleanup; exit 1 ; } fi

echo Now resetting..
{ "${YUBISET_GPG_CONNECT_AGENT}" >/dev/null 2>&1 < "${input_dir}/resetyubi.input" ; } || { cleanup; end_with_error "Could not properly reset your Yubikey." ; }
echo ..Success!

echo
pretty_print "PIN: 123456"
pretty_print "Admin PIN: 12345678"
reinsert_yubi