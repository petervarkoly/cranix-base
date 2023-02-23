#!/bin/bash
. /etc/sysconfig/cranix
DATE=$( /usr/share/cranix/tools/crx_date.sh )
sed -i s#CRANIX/4.4#CRANIX/4.5# /etc/zypp/credentials.cat
sed -i s/4.4/4.5/ /etc/zypp/repos.d/CRANIX.repo
/usr/bin/zypper ref
sed -i "s/samba-ad /samba-ad-dc /" /etc/sysconfig/cranix
/usr/bin/zypper -n dup 2>&1 | tee /var/log/CRANIX-MIGRATE-TO-4-5

if [ "$( rpm -q --qf %{VERSION} cranix-base )" = "4.4" ]; then
	/usr/bin/systemctl enable samba-ad-dc
	[ -e /etc/samba/smb-printserver.conf ] && /usr/bin/systemctl enable samba-printserver
	[ -e /etc/samba/smb-fileserver.conf ]  && /usr/bin/systemctl enable samba-fileserver
	if [ -e /usr/lib/systemd/system/cyrus-imapd.service ]; then
		/usr/bin/systemctl enable cyrus-imapd
		/usr/bin/systemctl enable saslauthd
	fi
else
	echo "Migration failed."
	echo "A support issue was created."
	echo "Do not restart the system!!!!"
fi
