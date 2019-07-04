cleanup()
{
	unset _unused
	unset IFS
}

end_with_error()
{
	echo "ERROR: ${1:-"Unknown Error"} Exiting." 1>&2
	exit 1
}

if [[ -z "${yubiset_version}" ]] ; then declare -r yubiset_version="0.3.1" ; fi
if [[ -z "${me}" ]] ; then declare -r me="$(basename $0)" ; fi

# https://stackoverflow.com/questions/630372/determine-the-path-of-the-executing-bash-script
if [[ -z "${relative_root_folder}" ]] ; then declare -r relative_root_folder="$(dirname $0)" ; fi
if [[ -z "${root_folder}" ]] ; then declare -r root_folder="$(cd $relative_root_folder/../.. && pwd)" ; fi
if [[ -z "${root_folder}" ]] ; then
  # error; for some reason, the path is not accessible
  # to the script (e.g. permissions re-evaled after suid)
  cleanup
  end_with_error "Could not determine yubiset's root folder."
fi

# Not sure if forcing the language does actually work on Unix's gpg flavor.
# declare -r LANG=EN
if [[ -z "${conf_dir}" ]] ; then declare -r conf_dir="${root_folder}/conf_templates" ; fi
if [[ -z "${input_dir}" ]] ; then declare -r input_dir="${root_folder}/input_files" ; fi
if [[ -z "${key_backups_dir}" ]] ; then 
	cd ~
	_cwd="$(pwd -P)"
	cd "${OLDPWD}"
	declare -r key_backups_dir="${_cwd}/.yubiset_key_backups" ; fi
if [[ -z "${yubiset_temp_dir}" ]] ; then 
	declare -r yubiset_temp_dir="/tmp/yubiset"
	if [[ -d "${yubiset_temp_dir}" ]]; then
		rm -rf "${yubiset_temp_dir}" > /dev/null 2>&1 || { cleanup; end_with_error "Could not cleanup temporary directory.";}
	fi
	mkdir -p "${yubiset_temp_dir}" || { cleanup; end_with_error "Could not create temporary directory.";}
fi

if [[ "${YUBISET_GPG_OVERRIDE}" ]] && [[ -z "${YUBISET_GPG_OVERRIDE_DONE}" ]] ; then
	. "${YUBISET_GPG_OVERRIDE}" || { cleanup; end_with_error "Sourcing the gpg override failed."; }
	declare -r YUBISET_GPG_OVERRIDE_DONE="true"
else
	if [[ -z "${YUBISET_GPG_BIN}" ]]; then declare -r YUBISET_GPG_BIN="gpg" ; fi
	if [[ -z "${YUBISET_GPG_CONNECT_AGENT}" ]]; then declare -r YUBISET_GPG_CONNECT_AGENT="gpg-connect-agent" ; fi
	if [[ -z "${YUBISET_GPG_CONF}" ]]; then declare -r YUBISET_GPG_CONF="gpgconf" ; fi
fi

if [[ -z "${gpg_home}" ]]; then
	gpg_home="$(${YUBISET_GPG_BIN} --version | grep -i "home")"
	IFS=':'
	# <<< means here-string, see https://askubuntu.com/questions/678915/whats-the-difference-between-and-in-bash
	read -r _unused gpg_home <<< "${gpg_home}" || { cleanup; end_with_error "Could not determine gpg's home dir.";}
	# Trim, see https://stackoverflow.com/a/3232433
	gpg_home="$(echo -e "${gpg_home}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
fi

#
# Delete the yubiset tmp dir in case the calling script is running standalone and did not get called from yubiset.
#
remove_tmp_dir_if_standalone()
{
	if [[ -z "${yubiset_main_script_runs}" ]] ; then silentDel "${yubiset_temp_dir}" ; fi
}
