#!/bin/bash
# Copyright 2015 ISRG.  All rights reserved
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

set -o pipefail

SETTINGS=~/.cfssl-pkcs11-ca

if [ "$(uname)" == "Darwin" ] ; then
  # OSX Settings: Use `brew install engine_pkcs11 opensc libp11`
  SPYMODULE=/usr/local/Cellar/opensc/0.14.0_1/lib/pkcs11/pkcs11-spy.so
  MODULE=/usr/local/Cellar/opensc/0.14.0_1/lib/pkcs11/opensc-pkcs11.so
fi
if [ "$(uname)" == "Linux" ] ; then
  # Linux settings, at least for CentOS x64.
  SPYMODULE=/usr/lib64/pkcs11/pkcs11-spy.so
  MODULE=/usr/lib64/pkcs11/opensc-pkcs11.so
fi

die() {
  printf "[!] Stopping.\n%s\n" "$@"
  exit 1
}

join() {
  local IFS="$1"
  shift
  echo "$*"
}

debug() {
  echo "Enabling PKCS11 Spying"
  [ -r "${SPYMODULE}" ] \
    || die "${SPYMODULE} does not exist; it comes from the OpenSC project."

  # Let the PKCS11 Spy know where the real module is
  export PKCS11SPY="${MODULE}"
  # Override the module
  MODULE="${SPYMODULE}"
}

install() {
  echo "Reinstalling CFSSL tools"
  go install -tags pkcs11 github.com/cloudflare/cfssl/cmd/cfssl \
    || die "Could not install"
  go install -tags pkcs11 github.com/cloudflare/cfssl/cmd/cfssljson \
    || die "Could not install"
}

info() {
  [ -x "$(which pkcs11-tool)" ] \
    || die "Couldn't find pkcs11-tool; you probably need to install it."

  cat <<EOF
If things fail, you probably want to try 2-3 times before deciding a
configuration is bad; most consumer HSMs have lots of spurious failure with
the OpenSC library in particular.

EOF

  cat <<EOF
********************************************************************************
Determining the SLOT field
********************************************************************************
  You need to figure out the slot name that describes this HSM. It's going to
  be to the right of the "Slot X (0xY):" part. In this example, it's the entire
  string "PIV_II (PIV Card Holder pin)"

Available slots:
Slot 0 (0x1): Yubico Yubikey NEO OTP+CCID
  token label        : PIV_II (PIV Card Holder pin)
  token manufacturer : piv_II
  token model        : PKCS#15 emulated
  token flags        : rng, login required, PIN initialized, token initialized
  hardware version   : 0.0
  firmware version   : 0.0
  serial num         : 00000000


********************************************************************************
</example>
********************************************************************************

EOF
  pkcs11-tool --module "${MODULE}" --login --pin "${PIN}" --list-slots

  cat <<EOF
********************************************************************************
Determining the LABEL field
********************************************************************************
  You need to figure out the label for the thing labeled a Private Key Object.
  It will look something like this:

Private Key Object; RSA
  label:      SIGN key
  ID:         02
  Usage:      decrypt, sign, non-repudiation
  Access:     always authenticate
Public Key Object; RSA 2048 bits
  label:      SIGN pubkey
  ID:         02
  Usage:      encrypt, verify
Certificate Object, type = X.509 cert
  label:      Certificate for Digital Signature
  ID:         02


********************************************************************************
</example>
********************************************************************************

EOF

  pkcs11-tool --module "${MODULE}" --login --pin "${PIN}" --list-objects
}

sign() {
  CERT_ID=$(date +%s)

  [ -r "${MODULE}" ] || die "Module not found at ${MODULE}"
  [ -w "${CERTDIR}" ] || die "You need to make a certs directory at ${CERTDIR}"
  [ -r "${CACERT}" ] || die "CA Cert not readable at ${CACERT}"
  [ -x "$(which cfssl)" ] || die "Couldn't find cfssl - try $0 install"
  [ -x "$(which cfssljson)" ] || die "Couldn't find cfssljson - try $0 install"

  OUTFILE=$(mktemp /tmp/signtmpXXXXXX)
  SAN_CSV=$(join , ${HOSTNAMES})


  if [ -x $(which openssl) ] ; then
    echo "CSR details:"
    $(which openssl) req -in "${CSR}" -text | grep "Subject:"
    $(which openssl) req -in "${CSR}" -text | grep "Subject Alternative" -A 1
  fi

  if [ "x${HOSTNAMES}" != "x" ] ; then
    echo "Producing SAN for:"
    for h in ${HOSTNAMES}; do
      echo "* ${h}"
    done
  fi

  echo "Profile in use: ${PROFILE}"
  echo " "
  echo "Sign? [y/N], or press ctrl-c to cancel"
  read x
  if [ "${x}" != "y" ] && [ "${x}" != "Y" ] ; then
    exit 0
  fi

  cfssl sign -ca="${CACERT}" -pkcs11-module="${MODULE}" \
    -pkcs11-label="${LABEL}" -pkcs11-token="${SLOT}" -pkcs11-pin="${PIN}" \
    -config="${CONFIG}" -profile="${PROFILE}" -hostname="${SAN_CSV}" \
    "${CSR}" > "${OUTFILE}" || die "Signing failure. Likely spurious. Maybe retry?" \
    "$(cat ${OUTFILE})"

  cfssljson -bare "${CERTDIR}/${CERT_ID}" < "${OUTFILE}" || die "Failed to save"
  rm -f "${OUTFILE}"

  if [ -x $(which openssl) ] ; then
    $(which openssl) x509 -in "${CERTDIR}/${CERT_ID}.pem" -text
  fi

  echo "Produced: "
  ls -la "${CERTDIR}/${CERT_ID}"*
}

help() {
cat <<EOF
$0 [-debug] {command} [CSR] {SAN Name 1..n}

Options:
  -debug    Enable PKCS11 Debugging with the OpenSC PKCS11 Spy

Commands:
  sign      Sign a CSR
  install   Install the CFSSL binaries
  info      Use PKCS11-Tool to help select the PKCS11 module options
  help      This message
EOF
}


[ -r "${SETTINGS}" ] || die "Could not load settings from ${SETTINGS}. Start from cfssl-pkcs11-ca.example."
source "${SETTINGS}"


if [ "$1" == "-debug" ] ; then
  debug
  shift
fi

if [ "$1" == "sign" ] ; then
  shift
  CSR="$1"
  shift
  HOSTNAMES="$@"
  [ -r "${CSR}" ] || die "Cannot open CSR: ${CSR}"
  sign
elif [ "$1" == "install" ] ; then
  install
elif [ "$1" == "info" ] ; then
  info
else
  help
fi
