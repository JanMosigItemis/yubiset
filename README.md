# YUBISET

A collection of scripts to make OpenPGP key generation and YubiKey manipulation easy. Key generation and gpg setup things are inspired by [the perfect key pair](https://blog.eleven-labs.com/en/openpgp-almost-perfect-key-pair-part-1).

Currently only Windows is supported. Bash script for Linux & Mac will follow.

Usage:

```
git clone git@github.com:JanMosigItemis/yubiset.git
cd yubiset\windows
yubiset
```
In case your Yubikey does only support subkeys of 2048bit length (like the NEO), use `yubiset 4` instead.
