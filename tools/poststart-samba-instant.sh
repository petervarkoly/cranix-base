#!/bin/bash
# Some check after starting the samba instant

instant=$1

registerpw=$( /usr/bin/grep de.cranix.dao.User.Register.Password= /opt/cranix-java/conf/cranix-api.properties | sed 's/de.cranix.dao.User.Register.Password=//' )
sleep 1
/usr/bin/smbclient -L ${instant} -U register%"${registerpw}"
if [ "$?" -ne 0 ]; then
	/usr/bin/systemctl restart samba-ad
	sleep 3
	/usr/bin/net ADS JOIN -s /etc/samba/smb-${instant}.conf -U register%"${registerpw}"
fi

