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

declare -r yubiset_version="0.1.0"
declare -r me="$(basename $0)"

# https://stackoverflow.com/questions/630372/determine-the-path-of-the-executing-bash-script
declare -r relative_root_folder="$(dirname $0)"
declare -r root_folder="$(cd $relative_root_folder/.. && pwd)"
if [ -z "$root_folder" ] ; then
  # error; for some reason, the path is not accessible
  # to the script (e.g. permissions re-evaled after suid)
  cleanup
  end_with_error "Could not determine yubiset's root folder."
fi

# Not sure if forcing the language does actually work on Unix's gpg flavor.
# declare -r LANG=EN
declare -r conf_dir="${root_folder}/conf_templates"
declare -r input_dir="${root_folder}/input_files"
declare -r key_backups_dir="${root_folder}/key_backups"
declare -r temp_dir=/tmp/yubiset

if [[ -d "${temp_dir}" ]]; then
	rm -rf "${temp_dir}" > /dev/null 2>&1 || { cleanup; end_with_error "Could not cleanup temporary directory.";}
fi
mkdir -p "${temp_dir}" || { cleanup; end_with_error "Could not create temporary directory.";}

if [[ "${YUBISET_GPG_OVERRIDE}" ]]; then
	. "${YUBISET_GPG_OVERRIDE}" || { cleanup; end_with_error "Sourcing the gpg override failed."; }
else
	declare -r YUBISET_GPG_BIN="gpg"
	declare -r YUBISET_GPG_CONNECT_AGENT="gpg-connect-agent"
	declare -r YUBISET_GPG_CONF="gpgconf"
fi

gpg_home="$(${YUBISET_GPG_BIN} --version | grep -i "home")"
IFS=':'
# <<< means here-string, see https://askubuntu.com/questions/678915/whats-the-difference-between-and-in-bash
read -r _unused gpg_home <<< "${gpg_home}" || { cleanup; end_with_error "Could not determine gpg's home dir.";}
# Trim, see https://stackoverflow.com/a/3232433
gpg_home="$(echo -e "${gpg_home}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

