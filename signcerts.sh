#!/usr/bin/env bash
set -Eeo pipefail

function TeamBanner(){
printf '
 ____   ___            ___ ____________ __   __    _    _____ __________ 
|  _ \\ / _ \\    /\\    / _ \\\\  ___)  ___)  \\ /  | _| |_ |  ___)  _ \\  ___)
| |_) ) |_| |  /  \\  | |_| |\\ \\   \\ \\  |   v   |/     \\| |_  | |_) ) \\   
|  _ (|  _  | / /\\ \\ |  _  | > >   > > | |\\_/| ( (| |) )  _) |  __/ > >  
| |_) ) | | |/ /__\\ \\| | | |/ /__ / /__| |   | |\\_   _/| |___| |   / /__ 
|____/|_| |_/________\\_| |_/_____)_____)_|   |_|  |_|  |_____)_|  /_____)
'
}

function CelebrationTime(){
printf '
 :::===== :::===  :::====  :::===       :::=======  :::====  :::====  :::=====
 :::      :::     :::  === :::          ::: === === :::  === :::  === :::     
 ===       =====  =======   =====       === === === ======== ===  === ======  
 ===          === === ===      ===      ===     === ===  === ===  === ===     
  ======= ======  ===  === ======       ===     === ===  === =======  ========
'
}

shopt -s nullglob

TeamBanner
#Set Environment Variables

# Check if os is mac or linux
if [[ "$OSTYPE" == "linux-gnu"* ]]
then
	echo "Running on Linux: $OSTYPE"
elif [[ "$OSTYPE" == "darwin"* ]]
then
	echo "Running on Mac OSx: $OSTYPE"
	shopt -s expand_aliases
	alias date="gdate"
else
	echo "Operating System Not Supported! Please use Linux or Mac OSX"
	exit 1
fi

# Save PROJECT_DIR to use throughout script
export PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Get environment variables from NFS_VARS.env
source "${PROJECT_DIR}/GENCERTS_VARS.env"
source "${PROJECT_DIR}/SIGNCERTS_VARS.env"

# Set expiration date for certs
tls_days=${TLS_DAYS:-"397"}
ca_days=${CA_DAYS:-"3650"}

# Set cert start date 5 minutes early to prevent delays in using certs
cert_start_date="$(date -u --date='5 minutes ago' '+%Y%m%d%H%M%S')Z"

echo "********************************************************"
echo "Generating Certs From CSRs"
echo
echo "********************************************************"
bchain_dir="${PROJECT_DIR}/bchain"
mkdir -p "${bchain_dir}/certs"

## Get file names to generate certs for (csrs, etc.)
pushd "${bchain_dir}/csr/ca"
csr_filenames_ca=( * )
popd
pushd "${bchain_dir}/csr/server"
csr_filenames_server=( * )
popd
## Get file names to generate certs for (csrs, etc.)
filenames_ca=( ${csr_filenames_ca[@]/%.*/} )
filenames_server=( ${csr_filenames_server[@]/%.*/} )

cat << EOF > "${bchain_dir}/externalca-openssl.cnf"
# OpenSSL root CA configuration file.
# Copy to /root/ca/openssl.cnf.
[ ca ]
# man ca
default_ca = CA_default
[ CA_default ]
# Directory and file locations.
dir               = ${EXTERNAL_CA_DIR}
certs             = ${EXTERNAL_CA_DIR}/certs
crl_dir           = ${EXTERNAL_CA_DIR}/crl
new_certs_dir     = ${EXTERNAL_CA_DIR}/newcerts
database          = ${EXTERNAL_CA_DIR}/index.txt
serial            = ${EXTERNAL_CA_DIR}/serial
RANDFILE          = ${EXTERNAL_CA_DIR}/private/.rand
# The root key and root certificate.
private_key       = ${EXTERNAL_CA_DIR}/private/${EXTERNAL_CA}.key
certificate       = ${EXTERNAL_CA_DIR}/certs/${EXTERNAL_CA}.cert
# For certificate revocation lists.
crlnumber         = ${EXTERNAL_CA_DIR}/crlnumber
crl               = ${EXTERNAL_CA_DIR}/crl/${EXTERNAL_CA}.crl
crl_extensions    = crl_ext
default_crl_days  = 1095
copy_extensions = copy
# SHA-1 is deprecated, so use SHA-2 instead.
default_md        = sha256
name_opt          = ca_default
cert_opt          = ca_default
default_days      = 1095
preserve          = no
policy            = policy_loose
[ policy_strict ]
# The root CA should only sign intermediate certificates that match.
# See the POLICY FORMAT section of man ca.
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional
[ policy_loose ]
# Allow the intermediate CA to sign a more diverse range of certificates.
# See the POLICY FORMAT section of the ca man page.
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional
[ server_cert ]
# Extensions for server certificates (man x509v3_config).
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
[ blockchain_ca ]
subjectKeyIdentifier = hash
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
[ ocsp ]
# Extension for OCSP signing certificates (man ocsp).
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, OCSPSigning
EOF

# for each csr gen cert according to it with proper permissions and create cert chain (ca)
for filename in "${filenames_ca[@]}"
do
    openssl ca -batch -config "${bchain_dir}/externalca-openssl.cnf" -extensions blockchain_ca -startdate "${cert_start_date}" -notext -md sha256 -days ${ca_days} -in "${bchain_dir}/csr/ca/${filename}.csr" -out "${bchain_dir}/certs/${filename}.cert"
    cat "${bchain_dir}/certs/${filename}.cert" "${EXTERNAL_CA_DIR}/certs/${EXTERNAL_CA}.chain" > "${bchain_dir}/certs/${filename}.chain"
    chmod 444 "${bchain_dir}/certs/${filename}.cert" && chmod 444 "${bchain_dir}/certs/${filename}.chain"
    openssl verify -CAfile "${EXTERNAL_CA_DIR}/certs/${EXTERNAL_CA}.chain" "${bchain_dir}/certs/${filename}.cert"
    openssl x509 -in "${bchain_dir}/certs/${filename}.cert" -noout -text
done

# for each csr gen cert according to it with proper permissions and create cert chain (server)
for filename in "${filenames_server[@]}"
do
    openssl ca -batch -config "${bchain_dir}/externalca-openssl.cnf" -extensions server_cert -startdate "${cert_start_date}" -notext -md sha256 -days ${tls_days} -in "${bchain_dir}/csr/server/${filename}.csr" -out "${bchain_dir}/certs/${filename}.cert"
    cat "${bchain_dir}/certs/${filename}.cert" "${EXTERNAL_CA_DIR}/certs/${EXTERNAL_CA}.chain" > "${bchain_dir}/certs/${filename}.chain"
    chmod 444 "${bchain_dir}/certs/${filename}.cert" && chmod 444 "${bchain_dir}/certs/${filename}.chain"
    openssl verify -CAfile "${EXTERNAL_CA_DIR}/certs/${EXTERNAL_CA}.chain" "${bchain_dir}/certs/${filename}.cert"
    openssl x509 -in "${bchain_dir}/certs/${filename}.cert" -noout -text
done

CelebrationTime