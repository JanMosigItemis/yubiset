# YUBISET  
A collection of scripts to make OpenPGP key generation and YubiKey manipulation easy. Key generation and gpg setup things are inspired by [the perfect key pair](https://blog.eleven-labs.com/en/openpgp-almost-perfect-key-pair-part-1).

Currently only Windows is supported. Bash script for Linux & Mac will follow.

# Prerequisites  
The only thing you'll need is a working gpg installation:

## Windows  
[gpg4win](https://www.gpg4win.org)

## Linux  
Use the *GnuPG* package provided with your distribution or follow the instructions on [https://gnupg.org](https://gnupg.org).

## Mac  
[gpgtools](https://gpgtools.org)

# Usage
## Download
TBA

## Clone with git  
```
git clone git@github.com:JanMosigItemis/yubiset.git
```

## Windows

### Key generation & Yubikey setup
```
git clone git@github.com:JanMosigItemis/yubiset.git
cd yubiset\windows
yubiset.bat
```
In case your Yubikey does only support subkeys of 2048bit length (like the NEO), use `yubiset 4` instead.

### Move PGP keys to Yubikey only
```
cd windows
setupyubi.bat "Given Name Surname" "my.email@provider.com" "PGP key id" "passphrase"
```

### Reset Yubikey's OpenPGP module
**BE AWARE:** Only tested with Yubikey 4 NEO and Yubikey 5
```
cd windows
resetyubi.bat
```

### Find Yubikey Slot
```
cd windows
findyubi.bat
```