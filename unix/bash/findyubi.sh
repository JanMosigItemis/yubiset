#!/bin/bash

#
# SETUP SECTION
#
if [[ -z "${lib_dir}" ]] ; then declare -r lib_dir=lib ; fi
. "${lib_dir}"/bootstrap.sh
. "${lib_dir}"/lib.sh

cleanup()
{
	silentCopy "${gpg_home}/${conf_backup}" "${gpg_home}/scdaemon.conf"
	silentDel "${gpg_home}/${conf_backup}"
	restart_scdaemon
	remove_tmp_dir_if_standalone
}

find_slot_heuristic()
{
	#
	# ACTIVATE SCDAEMON DEBUG MODE
	#
	echo
	echo "In order to find the correct card slot, we need to switch scdaemon into debug mode. This is done via a change to the config file. We are going to reset the changes, when we are done. Promise :)"
	if ! $(are_you_sure "Continue") ; then { cleanup; end_with_error; } fi 

	if [[ -f "${gpg_home}/scdaemon.conf" ]] ; then
		echo "Now creating backup: ${gpg_home}/${conf_backup}"
		silentCopy "${gpg_home}/scdaemon.conf" "${gpg_home}/${conf_backup}" || { cleanup; end_with_error "Could not create backup of scdaemon.conf." ; }
		echo ..Success!
	else
		touch "${gpg_home}/${conf_backup}"
	fi

	#
	# Special case if running in git-bash on Windows and the scdaemon from gpg4win is used.
	# In this case, the scdaemon is a Windows process and needs a Windows path.
	#
	local scdaemon_log_sanitized="${scdaemon_log}"
	if [[ "${YUBISET_SCDAEMON_IS_WINDOWS}" == "true" ]] ; then
		local scdaemon_log_sanitized_dir=$(dirname "${scdaemon_log_sanitized}")
		local scdaemon_log_sanitized_name=$(basename "${scdaemon_log_sanitized}")
		cd "${scdaemon_log_sanitized_dir}"
		scdaemon_log_sanitized_dir="$(pwd -W)"
		cd "${OLDPWD}"
		scdaemon_log_sanitized="${scdaemon_log_sanitized_dir}/${scdaemon_log_sanitized_name}"
		# Replace / with \
		scdaemon_log_sanitized="${scdaemon_log_sanitized//\//\\}"
	fi
	
	echo >> "${gpg_home}/scdaemon.conf"
	echo "#Start: Temporarily added by Yubiset">> "${gpg_home}/scdaemon.conf"
	echo "log-file ${scdaemon_log_sanitized}">> "${gpg_home}/scdaemon.conf"
	echo "debug-level guru">> "${gpg_home}/scdaemon.conf"
	echo "debug-all">> "${gpg_home}/scdaemon.conf"
	echo "#End: Temporarily added by Yubiset">> "${gpg_home}/scdaemon.conf"

	echo
	echo Please remove your YubiKey.
	press_any_key
	
	#
	# GPG AGENT RESTART
	#
	echo
	restart_gpg_agent || { cleanup; end_with_error "Could not restart gpg-agent."; }

	#
	# SCDAEMON RESTART
	#
	echo
	restart_scdaemon || { cleanup; end_with_error "Could not restart scdaemon."; }
	
	echo Please insert your YubiKey.
	press_any_key
	
	echo
	echo Now generating debug log..
	"${YUBISET_GPG_BIN}" --card-status > /dev/null 2>&1
	echo ..Done!

	#
	# PROCESS DEBUG LOG
	#
	readarray -t reader_port_candidates <<< $( { cat ${scdaemon_log} | grep "detected" | cut -d "'" -f2 ; } || { cleanup; end_with_error "Could not parse scdaemon log." ; } )
	for reader_port_candidate in "${reader_port_candidates[@]}"
	do
		reader_port_candidate="${reader_port_candidate% *}"
		if $(are_you_sure "Found reader port '${reader_port_candidate}' - Is this the right one") ; then 
			reader_port="${reader_port_candidate}"
			break
		fi
	done
	
	cleanup
	
	if [[ -z "${reader_port}" ]] ; then { end_with_error "Could not find any viable readers." ; } fi
	
	echo Writing scdaemon.conf..
	echo >> "${gpg_home}/scdaemon.conf"
	echo "#Added by yubiset:" >> "${gpg_home}/scdaemon.conf"
	echo "reader-port ${reader_port}" >> "${gpg_home}/scdaemon.conf"
	echo ..Success!
}

pretty_print "Yubikey smartcard slot find and configuration script"
pretty_print "Version: ${yubiset_version}"

declare -r conf_backup=scdaemon.conf.orig
declare -r scdaemon_log="${yubiset_temp_dir}/scdaemon.log"

#
# GPG AGENT RESTART
#
echo
restart_gpg_agent || { cleanup; end_with_error "Could not restart gpg-agent."; }

#
# SCDAEMON RESTART
#
echo
restart_scdaemon || { cleanup; end_with_error "Could not restart scdaemon."; }

#
# COMM CHECK
#
reinsert_yubi

echo "Now checking if we are able to communicate with your Yubikey.."
{ "${YUBISET_GPG_BIN}" --card-status > /dev/null 2>&1 ; } || {
	echo "..Failed :("
	if $(are_you_sure "This is most likely because your GPG does not know which card reader to use. Should we try setting things up for you") ; then 
		find_slot_heuristic
		#
		# COMM CHECK
		#
		reinsert_yubi
		echo "Now checking if we are able to communicate with your Yubikey.."
		{ "${YUBISET_GPG_BIN}" --card-status > /dev/null 2>&1 ; } || { cleanup; end_with_error "Sorry, setting up your Yubikey did not work." ; }
		echo ..Success!
	else
		cleanup
		end_with_error "We cannot continue without a properly recognized Yubikey."
	fi
}

echo All done. Performing cleanup..
cleanup
