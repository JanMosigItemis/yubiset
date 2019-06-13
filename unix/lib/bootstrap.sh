declare -r yubiset_version="0.1.0"
declare -r me=`basename "$0"`

# https://stackoverflow.com/questions/630372/determine-the-path-of-the-executing-bash-script
declare -r relative_root_folder="`dirname \"$0\"`"
declare -r root_folder="`( cd \"$relative_root_folder/..\" && pwd )`"
if [ -z "$root_folder" ] ; then
  # error; for some reason, the path is not accessible
  # to the script (e.g. permissions re-evaled after suid)
  exit 1  # fail
fi

declare -r LANG=EN
declare -r conf_dir="${root_folder}/conf_templates"
declare -r input_dir="${root_folder}/input_files"
declare -r key_backups_dir="${root_folder}/key_backups"
declare -r temp_dir=/tmp

alias silentDel='rm -rf > /dev/null 2>&1'
alias silentCopy='cp -rf > /dev/null 2>&1'

