end_with_error()
{
	echo "ERROR: ${1:-"Unknown Error"} Exiting." 1>&2
	exit 1
}

