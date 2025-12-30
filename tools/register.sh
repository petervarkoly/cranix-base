#!/bin/bash

. /etc/sysconfig/cranix
REPO_USER=${CRANIX_REG_CODE:0:9}
REPO_PASSWORD=${CRANIX_REG_CODE:10:9}
. /etc/os-release

if [ -z "${REPO_USER}" -o -z "${REPO_PASSWORD}" ]; then
	echo "Invalid regcode."
	exit 1
fi

VALID=$( curl --insecure -X GET https://repo.cephalix.eu/api/customers/regcodes/${CRANIX_REG_CODE} )
if [ $? -gt 0 ]; then
        echo "Can not register."
        exit 1
fi
if [ "${VALID}" = "0" ]; then
        echo "Regcode is not valid."
        exit 2
fi

rm /etc/zypp/repos.d/*
#Save the credentials
echo "[${CRANIX_UPDATE_URL}/CRANIX/${VERSION_ID}]
username = ${REPO_USER}
password = ${REPO_PASSWORD}

[${CRANIX_SALT_PKG_URL}]
username = ${REPO_USER}
password = ${REPO_PASSWORD}
" > /etc/zypp/credentials.cat

chmod 600 /etc/zypp/credentials.cat

#Register salt-packages repository
mkdir -p /srv/salt/repos.d/
zypper  -D /srv/salt/repos.d/  rr salt-packages &> /dev/null
echo "[salt-packages]
name=salt-packages
enabled=1
autorefresh=1
baseurl=${CRANIX_SALT_PKG_URL}
path=/
type=rpm-md
keeppackages=0
priority=20
" > /tmp/salt-packages.repo

zypper -D /srv/salt/repos.d/ ar -G /tmp/salt-packages.repo

zypper --gpg-auto-import-keys -D /srv/salt/repos.d/ ref

echo "[CRANIX]
name=CRANIX
enabled=1
autorefresh=1
baseurl=${CRANIX_UPDATE_URL}/CRANIX/$VERSION_ID
path=/
type=rpm-md
keeppackages=0
priority=10
" > /tmp/cranix.repo

zypper ar -G /tmp/cranix.repo

#Add customer specific repositories
for repo in $( /usr/bin/curl --insecure -X GET http://repo.cephalix.eu/api/customers/regcodes/${CRANIX_REG_CODE}/repositories )
do
	repoType=$( echo $repo | gawk -F '#' '{ print $1 }' )
	repoName=$( echo $repo | gawk -F '#' '{ print $2 }' )
	repoUrl=$(  echo $repo | gawk -F '#' '{ print $3 }' )
	repoUrl=${repoUrl/VERSION/$VERSION_ID}
	case $repoType in
		SALTPKG)
			zypper -D /srv/salt/repos.d/ ar --refresh --no-gpgcheck -p 30 ${repoUrl} ${repoName}
			echo "[${repoUrl}]" >> /etc/zypp/credentials.cat
			echo "username = ${REPO_USER}" >> /etc/zypp/credentials.cat
			echo "password = ${REPO_PASSWORD}" >> /etc/zypp/credentials.cat
			;;
		SYSTEM)
			zypper ar --refresh --no-gpgcheck -p 30 ${repoUrl} ${repoName}
			echo "[${repoUrl}]" >> /etc/zypp/credentials.cat
			echo "username = ${REPO_USER}" >> /etc/zypp/credentials.cat
			echo "password = ${REPO_PASSWORD}" >> /etc/zypp/credentials.cat
			;;
		*)
			echo "Unknown repo"
	esac
done

#We need the CRANIX packages for the salt packages too
if [ ! -e /srv/salt/repos.d/CRANIX.repo ]; then
	ln -s /etc/zypp/repos.d/CRANIX.repo  /srv/salt/repos.d/CRANIX.repo
fi

/usr/bin/zypper --gpg-auto-import-keys ref
