These scripts assist with using [CFSSL](https://github.com/cloudflare/cfssl/) as a
Certificate Authority using its [PKCS11 support](https://github.com/cloudflare/cfssl/pull/95/files).

# Requirements
- Go 1.5+
- a PKSC11 driver (such as OpenSC or SoftHSM)

These scripts are made available in the hope that they'll help others
navigate the minefield that is setting these things up. They will not
help you with generating keys or importing them.


## Installation
```shell
git clone https://github/jcjones/cfssl-pkcs11-ca.git
cd cfssl-pkcs11-ca
cp cfssl-pkcs11-ca.example ~/.cfssl-pkcs11-ca
echo You should edit ~/.cfssl-pkcs11-ca to suit
echo Also customize ca-config.json.example to suit.
```

## Usage
```
./cfssl-ca.sh [-debug] {command} [CSR]

Options:
  -debug    Enable PKCS11 Debugging with the OpenSC PKCS11 Spy

Commands:
  sign      Sign a CSR
  install   Install the CFSSL binaries
  info      Use PKCS11-Tool to help select the PKCS11 module options
  help      This message
```

## Example
```
~/git/cfssl-pkcs11-ca/cfssl-ca.sh sign ~/Desktop/server.csr
2015/07/24 11:20:52 [INFO] signed certificate with serial number 8977880180546080632
Produced:
-rw-r--r--  1 user  staff  1869 Jul 24 11:20 ./certs/1437762051.csr
-rw-r--r--  1 user  staff  1123 Jul 24 11:20 ./certs/1437762051.pem
```

## HSM Compatibility
This script is tested with a Yubikey NEO and SoftHSM.

If you know the slot / token information for other HSMs that work with
CFSSL, feel free to add them to the configuration and open a PR.

# Useful other guides
* https://github.com/cloudflare/cfssl/issues/247
* https://github.com/OpenSC/OpenSC/wiki/Using-OpenSC
* https://security.stackexchange.com/questions/31098/how-to-use-a-yubikey-neo-or-any-openpgp-card-or-gnupg-in-general-to-sign-x-509