#!/bin/bash
. lib/bootstrap.sh
. lib/helper.sh

{ /c/devtools/gnupg/bin/gpg --export-secret-subkeys --armor --pinentry-mode loopback --passphrase 1234 0x3B18A0EA6E3CB8E9 > lala.sub.priv.asc ; } || { cleanup; end_with_error "Could not create backup of priv sub key." ; }
