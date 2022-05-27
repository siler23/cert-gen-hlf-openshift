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

TeamBanner
#Set Environment Variables
shopt -s expand_aliases
# Check if os is mac or linux
if [[ "$OSTYPE" == "linux-gnu"* ]]
then
	echo -e "\nRunning on Linux: ${OSTYPE}\n"
	alias base64="base64 -w0"
elif [[ "$OSTYPE" == "darwin"* ]]
then
	echo -e "\nRunning on Mac OSx: ${OSTYPE}\n"
	alias date="gdate"
else
	echo "Operating System Not Supported! Please use Linux or Mac OSX"
	exit 1
fi

# Save PROJECT_DIR to use throughout script
export PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Get environment variables from NFS_VARS.env
source "${PROJECT_DIR}/GENCERTS_VARS.env"

# Set cert start date 5 minutes early to prevent delays in using certs
start_date_root="$(date -u --date='5 minutes ago' '+%Y%m%d%H%M%S')Z"

echo "********************************************************"
echo "Generating Certs"
echo
echo "********************************************************"
bchain_dir="${PROJECT_DIR}/bchain"
rm -rf "${bchain_dir}"
mkdir -p "${bchain_dir}/keys" "${bchain_dir}/csr/ca" "${bchain_dir}/csr/server" "${bchain_dir}/configmaps"

# Gen application csrs

# OpenShift ingress cert
# Gen openssl config with subject alt name for openshift ingress
cat << EOF > "${bchain_dir}/${ingress_name}-openssl.cnf"
[ req ]
# Options for the req tool (man req).
prompt             = no
default_bits        = 2048
distinguished_name  = req_distinguished_name
string_mask         = utf8only
# SHA-1 is deprecated, so use SHA-2 instead.
default_md          = sha256
# Extension to add when the -x509 option is used.
req_extensions     = server_cert
[ req_distinguished_name ]
# See <https://en.wikipedia.org/wiki/Certificate_signing_request>.
countryName                     = "${Country}"
stateOrProvinceName             = "${State}"
localityName                    = "${Locality}"
0.organizationName              = "${Organization}"
0.organizationalUnitName        = "${OrgUnit0}"
1.organizationalUnitName        = "${OrgUnit1}"
2.organizationalUnitName        = "${OrgUnit2}"
commonName                      = "*.${OSHIFT_HOSTNAME}"
[ server_cert ]
# Extensions for server certificates (man x509v3_config).
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[ alt_names ]
DNS.1 = "*.${OSHIFT_HOSTNAME}"
[ crl_ext ]
# Extension for CRLs (man x509v3_config).
authorityKeyIdentifier=keyid:always
[ ocsp ]
# Extension for OCSP signing certificates (man ocsp).
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, OCSPSigning
EOF

openssl ecparam -out "${bchain_dir}/keys/${ingress_name}.key" -name prime256v1 -genkey -noout
chmod 400 "${bchain_dir}/keys/${ingress_name}.key"
openssl req -new -config "${bchain_dir}/${ingress_name}-openssl.cnf" -sha256 -key "${bchain_dir}/keys/${ingress_name}.key" -out "${bchain_dir}/csr/server/${ingress_name}.csr"
openssl req -in "${bchain_dir}/csr/server/${ingress_name}.csr" -text -noout

# Blockchain console cert

# Gen openssl config with subject alt name for blockchain console
cat << EOF > "${bchain_dir}/${ibp_console_name}-openssl.cnf"
[ req ]
# Options for the req tool (man req).
prompt             = no
default_bits        = 2048
distinguished_name  = req_distinguished_name
string_mask         = utf8only
# SHA-1 is deprecated, so use SHA-2 instead.
default_md          = sha256
# Extension to add when the -x509 option is used.
req_extensions     = server_cert
[ req_distinguished_name ]
# See <https://en.wikipedia.org/wiki/Certificate_signing_request>.
countryName                     = "${Country}"
stateOrProvinceName             = "${State}"
localityName                    = "${Locality}"
0.organizationName              = "${Organization}"
0.organizationalUnitName        = "${OrgUnit0}"
1.organizationalUnitName        = "${OrgUnit1}"
2.organizationalUnitName        = "${OrgUnit2}"
commonName                      = "${OSHIFT_PROJECT}-${ibp_console_name}-console.${OSHIFT_HOSTNAME}"
[ server_cert ]
# Extensions for server certificates (man x509v3_config).
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[ alt_names ]
DNS.1 = "${OSHIFT_PROJECT}-${ibp_console_name}-console.${OSHIFT_HOSTNAME}"
DNS.2= "${OSHIFT_PROJECT}-${ibp_console_name}-proxy.${OSHIFT_HOSTNAME}"
[ crl_ext ]
# Extension for CRLs (man x509v3_config).
authorityKeyIdentifier=keyid:always
[ ocsp ]
# Extension for OCSP signing certificates (man ocsp).
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, OCSPSigning
EOF

openssl ecparam -out "${bchain_dir}/keys/${ibp_console_name}.key" -name prime256v1 -genkey -noout
chmod 400 "${bchain_dir}/keys/${ibp_console_name}.key"
openssl req -new -config "${bchain_dir}/${ibp_console_name}-openssl.cnf" -sha256 -key "${bchain_dir}/keys/${ibp_console_name}.key" -out "${bchain_dir}/csr/server/${ibp_console_name}.csr"
openssl req -in "${bchain_dir}/csr/server/${ibp_console_name}.csr" -text -noout

for CA in "${CAS[@]}"
do
	cat <<- EOF > "${bchain_dir}/${CA}-ca-openssl.cnf"
	[ req ]
	# Options for the req tool (man req).
	prompt             = no
	default_bits        = 2048
	distinguished_name  = req_distinguished_name
	string_mask         = utf8only
	# SHA-1 is deprecated, so use SHA-2 instead.
	default_md          = sha256
	# Extension to add when the -x509 option is used.
	req_extensions     = blockchain_ca
	[ req_distinguished_name ]
	# See <https://en.wikipedia.org/wiki/Certificate_signing_request>.
	countryName                     = "${Country}"
	stateOrProvinceName             = "${State}"
	localityName                    = "${Locality}"
    0.organizationName              = "${Organization}"    
    0.organizationalUnitName        = "${OrgUnit0}"
    1.organizationalUnitName        = "${OrgUnit1}"
    2.organizationalUnitName        = "${OrgUnit2}"
    commonName                      = "${CA}-ca"
	[ blockchain_ca ]
	subjectKeyIdentifier = hash
	basicConstraints = critical, CA:true, pathlen:0
	keyUsage = critical, digitalSignature, cRLSign, keyCertSign
	subjectAltName = @alt_names
	[ alt_names ]
	IP.1 = "127.0.0.1"
	[ crl_ext ]
	# Extension for CRLs (man x509v3_config).
	authorityKeyIdentifier=keyid:always
	[ ocsp ]
	# Extension for OCSP signing certificates (man ocsp).
	basicConstraints = CA:FALSE
	subjectKeyIdentifier = hash
	authorityKeyIdentifier = keyid,issuer
	keyUsage = critical, digitalSignature
	extendedKeyUsage = critical, OCSPSigning
	EOF

	cat <<- EOF > "${bchain_dir}/${CA}-tlsca-openssl.cnf"
	[ req ]
	# Options for the req tool (man req).
	prompt             = no
	default_bits        = 2048
	distinguished_name  = req_distinguished_name
	string_mask         = utf8only
	# SHA-1 is deprecated, so use SHA-2 instead.
	default_md          = sha256
	# Extension to add when the -x509 option is used.
	req_extensions     = blockchain_ca
	[ req_distinguished_name ]
	# See <https://en.wikipedia.org/wiki/Certificate_signing_request>.
	countryName                     = "${Country}"
	stateOrProvinceName             = "${State}"
	localityName                    = "${Locality}"
	0.organizationName              = "${Organization}"
    0.organizationalUnitName        = "${OrgUnit0}"
    1.organizationalUnitName        = "${OrgUnit1}"
    2.organizationalUnitName        = "${OrgUnit2}"
	commonName                      = "${CA}-tlsca"
	[ blockchain_ca ]
	subjectKeyIdentifier = hash
	basicConstraints = critical, CA:true, pathlen:0
	keyUsage = critical, digitalSignature, cRLSign, keyCertSign
	[ crl_ext ]
	# Extension for CRLs (man x509v3_config).
	authorityKeyIdentifier=keyid:always
	[ ocsp ]
	# Extension for OCSP signing certificates (man ocsp).
	basicConstraints = CA:FALSE
	subjectKeyIdentifier = hash
	authorityKeyIdentifier = keyid,issuer
	keyUsage = critical, digitalSignature
	extendedKeyUsage = critical, OCSPSigning
	EOF

	cat <<- EOF > "${bchain_dir}/${CA}-tls-openssl.cnf"
	[ req ]
	# Options for the req tool (man req).
	prompt             = no
	default_bits        = 2048
	distinguished_name  = req_distinguished_name
	string_mask         = utf8only
	# SHA-1 is deprecated, so use SHA-2 instead.
	default_md          = sha256
	# v3 extensions to add
	req_extensions     = server_cert
	[ req_distinguished_name ]
	# See <https://en.wikipedia.org/wiki/Certificate_signing_request>.
	countryName                     = "${Country}"
	stateOrProvinceName             = "${State}"
    localityName                    = "${Locality}"
    0.organizationName              = "${Organization}"
    0.organizationalUnitName        = "${OrgUnit0}"
    1.organizationalUnitName        = "${OrgUnit1}"
    2.organizationalUnitName        = "${OrgUnit2}"
	commonName                      = "${OSHIFT_PROJECT}-${CA}-ca.${OSHIFT_HOSTNAME}"
	[ server_cert ]
	# Extensions for server certificates (man x509v3_config).
	basicConstraints = CA:FALSE
	nsCertType = server
	nsComment = "OpenSSL Generated Server Certificate"
	subjectKeyIdentifier = hash
	keyUsage = critical, digitalSignature, keyEncipherment
	extendedKeyUsage = serverAuth
	subjectAltName = @alt_names
	[ alt_names ]
	DNS.1 = "${OSHIFT_PROJECT}-${CA}-ca.${OSHIFT_HOSTNAME}"
	DNS.2 = "${OSHIFT_PROJECT}-${CA}-operations.${OSHIFT_HOSTNAME}"
	[ crl_ext ]
	# Extension for CRLs (man x509v3_config).
	authorityKeyIdentifier=keyid:always
	[ ocsp ]
	# Extension for OCSP signing certificates (man ocsp).
	basicConstraints = CA:FALSE
	subjectKeyIdentifier = hash
	authorityKeyIdentifier = keyid,issuer
	keyUsage = critical, digitalSignature
	extendedKeyUsage = critical, OCSPSigning
	EOF

	# Create CSRs
    openssl ecparam -out "${bchain_dir}/keys/${CA}-ca.key" -name prime256v1 -genkey -noout
    chmod 400 "${bchain_dir}/keys/${CA}-ca.key"
    openssl req -new -config "${bchain_dir}/${CA}-ca-openssl.cnf" -sha256 -key "${bchain_dir}/keys/${CA}-ca.key" -out "${bchain_dir}/csr/ca/${CA}-ca.csr"
	openssl req -in "${bchain_dir}/csr/ca/${CA}-ca.csr" -text -noout

    openssl ecparam -out "${bchain_dir}/keys/${CA}-tlsca.key" -name prime256v1 -genkey -noout
    chmod 400 "${bchain_dir}/keys/${CA}-tlsca.key"
    openssl req -new -config "${bchain_dir}/${CA}-tlsca-openssl.cnf" -sha256 -key "${bchain_dir}/keys/${CA}-tlsca.key" -out "${bchain_dir}/csr/ca/${CA}-tlsca.csr"
	openssl req -in "${bchain_dir}/csr/ca/${CA}-tlsca.csr" -text -noout

    openssl ecparam -out "${bchain_dir}/keys/${CA}-tls.key" -name prime256v1 -genkey -noout
    chmod 400 "${bchain_dir}/keys/${CA}-tls.key"
    openssl req -new -config "${bchain_dir}/${CA}-tls-openssl.cnf" -sha256 -key "${bchain_dir}/keys/${CA}-tls.key" -out "${bchain_dir}/csr/server/${CA}-tls.csr"
	openssl req -in "${bchain_dir}/csr/server/${CA}-tls.csr" -text -noout

	# Create fabric-ca-server ConfigMaps from base config files (one for ca and one for tlsca)
	cat <<- EOF > "${bchain_dir}/configmaps/${CA}-fabric-ca-server-cm.yaml"
	kind: ConfigMap
	apiVersion: v1
	metadata:
	  labels:
	    app: ${CA}
	    app.kubernetes.io/instance: ibpca
	    app.kubernetes.io/managed-by: ibp-operator
	    app.kubernetes.io/name: ibp
	    creator: ibp
	    helm.sh/chart: ibm-ibp
	    release: operator
	  name: ${CA}-ca-config
	  namespace: ${OSHIFT_PROJECT}
	binaryData: 
	  fabric-ca-server-config.yaml: $(base64 "${PROJECT_DIR}/fabric-ca-server-config.yaml")
	EOF


	cat <<- EOF > "${bchain_dir}/configmaps/${CA}-fabric-tlsca-server-cm.yaml"
	kind: ConfigMap
	apiVersion: v1
	metadata:
	  labels:
	    app: ${CA}
	    app.kubernetes.io/instance: ibpca
	    app.kubernetes.io/managed-by: ibp-operator
	    app.kubernetes.io/name: ibp
	    creator: ibp
	    helm.sh/chart: ibm-ibp
	    release: operator
	  name: ${CA}-tlsca-config
	  namespace: ${OSHIFT_PROJECT}
	binaryData: 
	  fabric-ca-server-config.yaml: $(base64 "${PROJECT_DIR}/fabric-tlsca-server-config.yaml")
	EOF


done

CelebrationTime
