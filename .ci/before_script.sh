#!/bin/bash

end_with_error()
{
	echo "ERROR: ${1:-"Unknown Error"} Exiting." 1>&2
	exit 1
}

declare -r custom_gpg_home="./.ci"
declare -r secring_auto="${custom_gpg_home}/secring.auto"
declare -r pubring_auto="${custom_gpg_home}/pubring.auto"

echo
echo Importing required public keys..
{ gpg --home "${custom_gpg_home}" --import "${custom_gpg_home}/37F0780907ABEF78.pub.asc" ; } || { end_with_error "Could not import public key into gpg." ; }
{ gpg --home "${custom_gpg_home}" --import "${pubring_auto}" ; } || { end_with_error "Could not import public key into gpg." ; }

echo
echo "Decrypting secret gpg keyring.."
{ echo $super_secret_password | gpg --home "${custom_gpg_home}" --passphrase-fd 0 "${secring_auto}".gpg ; } || { end_with_error "Failed to decrypt secret gpg keyring." ; }
echo Success!

echo
echo Importing required private keys..
{ gpg --home "${custom_gpg_home}" --import "${secring_auto}" ; } || { end_with_error "Could not import secret keyring into gpg." ; }
echo Success!

echo
