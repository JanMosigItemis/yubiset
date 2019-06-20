#!/bin/bash
. lib/bootstrap.sh
. lib/helper.sh

readarray -t my_array <<< $( cat ../scdaemon.log | grep "detected" | cut -d "'" -f2 )
echo "${my_array[@]}"
