#!/bin/bash
timestamp=$(date '+%y%m%d-%H%M%S')

function createCertificateAuthority {
	echo "Enter company name [Default is bluewoks]:"
	read  -p 'Company: ' caCompany
	vpnCompany=${caCompany:-'blueworks'}
	echo "Using CA for ${vpnCompany}"

	/usr/local/bin/ipsec pki --gen --outform pem > "${vpnCompany}"_key.pem
		if [ ${vpnCompany} == "blueworks" ]; then
			/usr/local/bin/ipsec pki --self --in "${vpnCompany}"_key.pem --dn "CN=$vpnCompany CA" --ca --outform pem > "${vpnCompany}"_ca.pem
		else
			/usr/local/bin/ipsec pki --self --in "${vpnCompany}"_key.pem --dn "CN=blueworks $vpnCompany CA" --ca --outform pem > "${vpnCompany}"_ca.pem
		fi
	caKeyFile="${vpnCompany}"_key.pem
	caFile="${vpnCompany}"_ca.pem
}

function backUpCA {
	mkdir -p .CA-backup
	cp ${caFile} .CA-backup/${timestamp}-${caFile}
	cp ${caKeyFile} .CA-backup/${timestamp}-${caKeyFile}
}

function createClientCert {
	echo "Enter username for client certificate:"
	read vpnUser
	echo -n "Certificate will be generated for $vpnUser"
	echo -e "\nEnter certificate password (leave blank to generate random password): "
	read -s password

	if [ -z "$password" ];
	then
		password=$(openssl rand -base64 32)
	else
		password=$password
	fi

	mkdir -p ClientCerts/"${vpnCompany}"/"${vpnUser}"
	touch ClientCerts/"${vpnCompany}"/"${vpnUser}/${timestamp}"
	touch ClientCerts/"${vpnCompany}"/"${vpnUser}/password.txt"
	echo ${password} > ClientCerts/"${vpnCompany}"/"${vpnUser}/password.txt"

	# Generate Client Certificate Keypair
	/usr/local/bin/ipsec pki --gen --outform pem > ClientCerts/"${vpnCompany}"/"${vpnUser}"/"${vpnUser}_key.pem"
	/usr/local/bin/ipsec pki --pub --in ClientCerts/"${vpnCompany}"/"${vpnUser}"/"${vpnUser}_key.pem" | ipsec pki --issue --cacert "${caFile}" --cakey "${caKeyFile}" --dn "CN=${vpnUser}" --san "${vpnUser}" --flag clientAuth --outform pem > ClientCerts/"${vpnCompany}"/"${vpnUser}"/"${vpnUser}.pem"

	# Generate P12 Format Client Certificate
	/usr/bin/openssl pkcs12 -in ClientCerts/"${vpnCompany}"/"${vpnUser}"/"${vpnUser}.pem" -inkey ClientCerts/"${vpnCompany}"/"${vpnUser}"/"${vpnUser}_key.pem" -certfile "${caFile}" -export -out ClientCerts/"${vpnCompany}"/"${vpnUser}"/"${vpnUser}.p12" -password "pass:${password}"

	# Reset password variable and cleanup
	unset password
	history -c

	read -p "Do you wish to create another client certificates for ${vpnCompany}?" yn
	case $yn in
		[Yy]* ) createClientCert;;
		[Nn]* ) backUpCA; exit;;
		* ) echo "Please answer yes or no.";;
	esac
}

if [[ $# -eq 0 ]]; then
echo "Provide script parameters. Use -h for details."
elif [[ $1 == "-n" ]]; then
echo "New certificate authority"
createCertificateAuthority
elif [[ $1 == "-e" && $2 != 0 && $3 != 0 ]]; then
echo "Existing certificate authority"
caFile=$2
caKeyFile=$3
vpnCompany=$(echo ${caFile} | cut -d'_' -f 1)
echo "Using CA for ${vpnCompany}"
elif [[ $1 == "-h" ]]; then
echo -e "
Option	Description
-n	New Certificate Authority
	Usage: -n
-e	Existing Certificate authority
	Usage: -e path/to/cert.pem path/to/key.pem
	"
fi

createClientCert


exit
