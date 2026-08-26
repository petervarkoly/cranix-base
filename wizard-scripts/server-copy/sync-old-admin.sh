#!/bin/bash -x
DIRS_TO_SYNC="/etc/cups/ppd /etc/openvpn /etc/samba /etc/salt /etc/sssd /opt/cranix-java/conf /usr/share/cranix/templates /var/lib/printserver /var/lib/samba /var/lib/fileserver /var/lib/mysql /home /srv/salt /srv/itool"
SERVICES="cron cups mariadb salt-master samba-ad samba-fileserver samba-printserver"
FILES_TO_CP="/root/.my.cnf /etc/cranix-firewall.conf /etc/cups/printers.conf /etc/sysconfig/cranix-vpn /etc/sysconfig/CRX_PTM /etc/sysconfig/CRX_CAL /etc/sysconfig/CRX_PTC /etc/sysconfig/CRX_ID"
if [ "$1" ]; then
        old_admin=$1
else
        old_admin="old-admin"
fi
echo "###########################################"
echo "# stop services"
systemctl stop $SERVICES
ssh ${old_admin} systemctl stop $SERVICES

[ -e exclude ] || touch exclude
echo "###########################################"
echo "# copy files"
for file in $FILES_TO_CP
do
        scp ${old_admin}:${file} ${file}
done
for dir in $DIRS_TO_SYNC
do
        echo "###########################################"
        echo "# syncing ${dir}"
        rsync --delete -aAv --exclude-from=exclude ${old_admin}:${dir}/ ${dir}/
done
systemctl start $SERVICES
