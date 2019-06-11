# YUBISET  
A collection of scripts to make OpenPGP key generation and YubiKey manipulation easy. Key generation and gpg setup things are inspired by [the perfect key pair](https://blog.eleven-labs.com/en/openpgp-almost-perfect-key-pair-part-1).

Currently only Windows is supported. Bash script for Linux & Mac will follow.

# What does it do?
It generates the "perfect" key pair, puts in some reasonable values for account / user id information and optionally transfers keys to a [Yubikey](www.yubico.com) device.

The Yubikey is also provided with user info and PIN setup.

The scripts do also feature a heuristic for finding and setting up the correct (Windows) smart card slot device in case gpg does not find your Yubikey automatically.

# Prerequisites  
The only thing you'll need is a working gpg installation:

## Windows  
[gpg4win](https://www.gpg4win.org)

## Linux  
Use the *GnuPG* package provided with your distribution or follow the instructions on [https://gnupg.org](https://gnupg.org).

## Mac  
[gpgtools](https://gpgtools.org)

# Download
TBA

# Usage

## Windows

### Start here: Key generation & Yubikey setup (all in one script)
```
cd yubiset\windows
yubiset.bat
```
In case your Yubikey does only support subkeys of 2048bit length (like the NEO), use `yubiset 4` instead.

The following scripts may be used standalone but are also called from the `yubiset` main script:
#### Move PGP keys to Yubikey only
```
cd windows
setupyubi.bat "Given Name Surname" "my.email@provider.com" "PGP key id" "passphrase"
```

#### Reset Yubikey's OpenPGP module
**BE AWARE:** Only tested with Yubikey 4 NEO and Yubikey 5
```
cd windows
resetyubi.bat
```

#### Find Yubikey Slot
```
cd windows
findyubi.bat
```

# For Developers
## Clone with git  
```
git clone git@github.com:JanMosigItemis/yubiset.git
```
## Windows Batch File Line Endings
Be aware that all Windows batch files need CRLF as line endings (as opposed to LF on Unix) in order for batch labels to work appropriately.
