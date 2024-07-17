#!/bin/bash -x
. /etc/sysconfig/cranix
DATE=$( /usr/share/cranix/tools/crx_date.sh )
/usr/share/cranix/tools/register.sh
sed -i s/4.5/15.6/ /etc/zypp/credentials.cat
zypper ar /usr/share/cranix/setup/openLeap.repos
for i in /etc/zypp/repos.d/*.repo
do
	sed -i s/4.5/15.6/ $i
	sed -i s/VERSION_ID/15.6/ $i
done
/usr/bin/zypper ref
#To be safe if samba will not start after update.
sed -i 's/solver.dupAllowVendorChange = .*/solver.dupAllowVendorChange = true/' /etc/zypp/zypp.conf
sed -i 's/^net.ipv4.ip_forward/#net.ipv4.ip_forward/'  /etc/sysctl.conf
sed -i 's/^net.ipv6.conf.all.forwarding/#net.ipv6.conf.all.forwarding/'  /etc/sysctl.conf
sed -i /repo1.cephalix.eu/d /etc/hosts
host repo1.cephalix.eu | gawk '{ print $4 " repo1.cephalix.eu vpn.cephalix.eu" }' >> /etc/hosts
CEPHALIX_VPN=$( gawk '/^remote/ { print $2 }' /etc/openvpn/CEPHALIX.conf )
if [ -n "${CEPHALIX_VPN}" -a "${CEPHALIX_VPN}" != "vpn.cephalix.eu" ]; then
	sed -i /${CEPHALIX_VPN}/d /etc/hosts
	host ${CEPHALIX_VPN} | gawk '{ print $4 " " $1 }' >> /etc/hosts
fi
#Make backup from the most important things:
mkdir -p /var/adm/cranix/backup/${DATE}
rsync -aAv /var/lib/samba/       /var/adm/cranix/backup/${DATE}/samba/
rsync -aAv /var/lib/printserver/ /var/adm/cranix/backup/${DATE}/printserver/
if [ -e /var/lib/fileserver/ ]; then
	rsync -aAv /var/lib/fileserver/ /var/adm/cranix/backup/${DATE}/fileserver/
fi
mysqldump --databases CRX > /var/adm/cranix/backup/${DATE}/CRX.sql

#Start the migration
/usr/bin/zypper --releasever 15.6 -n dup --no-recommends 2>&1 | tee /var/log/CRANIX-MIGRATE-TO-15.6

if [ "$( rpm -q --qf %{VERSION} cranix-base )" = "15.6" ]; then
	/usr/bin/systemctl enable samba-ad
	[ -e /etc/samba/smb-printserver.conf ] && /usr/bin/systemctl enable samba-printserver
	[ -e /etc/samba/smb-fileserver.conf ]  && /usr/bin/systemctl enable samba-fileserver
	if [ -e /usr/lib/systemd/system/cyrus-imapd.service ]; then
		/usr/bin/systemctl enable cyrus-imapd
		/usr/bin/systemctl enable saslauthd
	fi
	chmod 755 /opt/cranix-java/data/adapt_crx_db.sh
	/opt/cranix-java/data/adapt_crx_db.sh
	/sbin/reboot
else
	SUPPORT='{"email":"noreply@cephalix.eu","subject":"Migtration to CRANIX-15.6 failed","description":"Migtration to CRANIX-15.6 failed.","regcode":"'${CRANIX_REG_CODE}'"}'
        curl -s -X POST --header 'Content-Type: application/json' --header 'Accept: application/json' -d "${SUPPORT}" ${CRANIX_SUPPORT_URL}
	echo "Migration failed."
	echo "A support issue was created."
	echo "Do not restart the system!!!!"
fi
