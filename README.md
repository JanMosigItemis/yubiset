# YUBISET  
A collection of scripts to make OpenPGP key generation and YubiKey manipulation easy. Key generation and gpg setup things are inspired by [the perfect key pair](https://blog.eleven-labs.com/en/openpgp-almost-perfect-key-pair-part-1).

# What does it do?
It generates ["the perfect key pair"](https://blog.eleven-labs.com/en/openpgp-almost-perfect-key-pair-part-1), puts in some reasonable values for account / user id information and optionally transfers keys to a [Yubikey](www.yubico.com) device.

The Yubikey is also provided with user info and PIN setup.

The scripts do also feature a heuristic for finding and setting up the correct (Windows) smart card slot device in case gpg does not find your Yubikey automatically.

- [Supported Environments](#supported-environments)
- [Prerequisites](#prerequisites)
  * [Windows](#windows)
  * [Linux](#linux)
  * [Mac](#mac)
- [Download](#download)
- [Usage](#usage)
  * [Windows](#windows-1)
    + [Start here: Key generation & Yubikey setup (all in one script)](#start-here-key-generation--yubikey-setup-all-in-one-script)
      - [Move PGP keys to Yubikey only](#move-pgp-keys-to-yubikey-only)
      - [Reset Yubikey's OpenPGP module](#reset-yubikeys-openpgp-module)
      - [Find Yubikey Slot](#find-yubikey-slot)
  * [Unix](#unix)
    + [Start here: Key generation & Yubikey setup (all in one script)](#start-here-key-generation--yubikey-setup-all-in-one-script-1)
      - [Move PGP keys to Yubikey only](#move-pgp-keys-to-yubikey-only-1)
      - [Reset Yubikey's OpenPGP module](#reset-yubikeys-openpgp-module-1)
      - [Find Yubikey Slot](#find-yubikey-slot-1)
    + [Override GPG Binaries](#override-gpg-binaries)
- [For Developers](#for-developers)
  * [Clone with git](#clone-with-git)
  * [Windows Batch File Line Endings](#windows-batch-file-line-endings)
  * [Flush issues](#flush-issues)


# Supported Environments
* Windows (Batch)
* Windows ([git-bash](https://gitforwindows.org))
* Unix (Bash)

# Prerequisites  
The only thing you'll need is a working gpg installation:

## Windows  
* [gpg4win](https://www.gpg4win.org)
* Optionally [git-bash](https://gitforwindows.org)

## Linux  
Use the *GnuPG* package provided with your distribution or follow the instructions on [https://gnupg.org](https://gnupg.org).

## Mac  
[gpgtools](https://gpgtools.org)

# Download
[https://github.com/JanMosigItemis/yubiset/releases](https://github.com/JanMosigItemis/yubiset/releases)

# Usage

## Windows

### Start here: Key generation & Yubikey setup (all in one script)
```
cd windows\batch
yubiset.bat
```
In case your Yubikey does only support subkeys of 2048bit length (like the NEO), use `yubiset.bat 4` instead.

The following scripts may be used standalone but are also called from the `yubiset` main script:
#### Move PGP keys to Yubikey only
```
cd windows\batch
setupyubi.bat "Given Name Surname" "my.email@provider.com" "PGP key id" "passphrase"
```

#### Reset Yubikey's OpenPGP module
**BE AWARE:** Only tested with Yubikey 4 NEO and Yubikey 5
```
cd windows\batch
resetyubi.bat
```

#### Find Yubikey Slot
```
cd windows/batch
findyubi.bat
```

## Unix

### Start here: Key generation & Yubikey setup (all in one script)
```
cd unix/bash
sh yubiset.sh
```
In case your Yubikey does only support subkeys of 2048bit length (like the NEO), use `sh yubiset .sh 4` instead.

The following scripts may be used standalone but are also called from the `yubiset` main script:
#### Move PGP keys to Yubikey only
```
cd unix/bash
sh setupyubi.sh "Given Name Surname" "my.email@provider.com" "PGP key id" "passphrase"
```
Due to security reasons the passphrase may also be omitted. In this case the user will be prompted to enter it.

#### Reset Yubikey's OpenPGP module
**BE AWARE:** Only tested with Yubikey 4 NEO and Yubikey 5
```
cd unix/bash
sh resetyubi.sh
```

#### Find Yubikey Slot
```
cd unix/bash
sh findyubi.sh
```

### Override GPG Binaries
Since the original bash scripts have been developed on Windows with git-bash and gpg4win, it was necessary to override the gpg binaries provided by git-bash with those of gpg4win.

This feature is still active and officially supported, i. e. it is possible to manually tell yubiset which binaries to use.

This is done via the `YUBISET_GPG_OVERRIDE` environment varibale. Its value should be a valid path to a bash script that sets variables with paths for relevant binaries. Example:
```
declare -r YUBISET_GPG_BIN="/c/devtools/gnupg/bin/gpg" # absolute path to gpg binary.
declare -r YUBISET_GPG_CONNECT_AGENT="/c/devtools/gnupg/bin/gpg-connect-agent" # absolute path to gpg-connect-agent binary.
declare -r YUBISET_GPG_CONF="gpgconfw" # Bash functions or aliases are also supported.
declare -r YUBISET_SCDAEMON_IS_WINDOWS="true" # Wether or not the scdaemon in use is a Windows binary or not. With gpg4win this is true of course.
```
You could define the `YUBISET_GPG_OVERRIDE` variable in your `.bashrc` but it may be more convenient to use the ad hoc definition when running commands in bash like so:
```
YUBISET_GPG_OVERRIDE=/path/to/yubiset_gpg_override.sh sh yubiset.sh
```
The script will list the binaries in use before the start.

# For Developers
## Clone with git  
```
git clone git@github.com:JanMosigItemis/yubiset.git
```
## Windows Batch File Line Endings
Be aware that all Windows batch files need CRLF as line endings (as opposed to LF on Unix) in order for batch labels to work appropriately.

## Flush issues
Be aware that on some file systems / operating systems generating (log) files may take some time and in order for the gpg-agent and scdaemon to recognize changes it may also take some time, so retrying probes etc. is advised in order to make sure the script does not unnecessarily fail.

## README.md Table of Contents
This README's TOC has been generated with [markdown-toc](https://github.com/jonschlinkert/markdown-toc).
