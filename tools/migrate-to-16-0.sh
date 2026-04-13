#!/bin/bash

DATE=$( /usr/share/cranix/tools/crx_date.sh )
NEW_VERSION="16.0"
#First we make backup
mkdir -p /var/adm/backup/BEFOR-16
mysqldump --databases CRX | gzip > /var/adm/backup/BEFOR-16/CRX.sql.gz
echo "SELECT 'INSERT INTO DefaultPrinter SET room_id=',room_id,',printer_id=',printer_id,';' from DefaultPrinter where room_id > 0" | mysql --skip-column-names CRX > /var/adm/backup/BEFOR-16/DefaultPrinter.sql
echo "SELECT 'INSERT INTO DeviceDefaultPrinter SET device_id=',device_id,',printer_id=',printer_id,';' from DefaultPrinter where device_id > 0" | mysql --skip-column-names CRX > /var/adm/backup/BEFOR-16/DeviceDefaultPrinter.sql
echo "SELECT 'INSERT INTO AvailablePrinters SET room_id=',room_id,',printer_id=',printer_id,';' from AvailablePrinters where room_id > 0" | mysql --skip-column-names CRX > /var/adm/backup/BEFOR-16/AvailablePrinter.sql
echo "SELECT 'INSERT INTO DeviceAvailablePrinters SET device_id=',device_id,',printer_id=',printer_id,';' from AvailablePrinters where device_id > 0" | mysql --skip-column-names CRX > /var/adm/backup/BEFOR-16/DeviceAvailablePrinter.sql

# NetworkManager-config-server is required as otherwise NM will immediately add connections for all interfaces, resulting in duplicates.
# NetworkManager-config-server can be removed after the migration is done.
zypper install wicked2nm NetworkManager NetworkManager-config-server || ( echo "==============Migration ERROR============="; echo "wicked2nm is not available. Migration is not possible."; exit 1 )

# If NetworkManager-config-server is not available you can also manually add the drop-in configuration.
echo -e "[main]\nno-auto-default=*" > /etc/NetworkManager/conf.d/10-server.conf

# WARNING: Run this as root, wicked will shut down the interfaces and they will only come up again once the migration is done.
# This oneliner shuts down wicked, starts NM and runs the migration, if anything went wrong it starts wicked again.
systemctl disable --now wicked \
    && (systemctl enable --now NetworkManager && wicked show-config | wicked2nm migrate --continue-migration --activate-connections -) \
    || (systemctl disable --now NetworkManager; systemctl enable --now wicked)


rm /etc/zypp/repos.d/*
rm /etc/zypp/services.d/*
sed -i "s/15.6/${NEW_VERSION}/g" /etc/zypp/credentials.cat
echo "[CRANIX]
name=CRANIX
enabled=1
autorefresh=1
baseurl=http://repo.cephalix.eu/CRANIX/${NEW_VERSION}
path=/
priority=10
gpgcheck=0
keeppackages=0
" > /etc/zypp/repos.d/CRANIX.repo

zypper ar https://download.opensuse.org/distribution/leap/${NEW_VERSION}/repo/oss/ openLeap-oss
zypper ar https://download.opensuse.org/distribution/leap/${NEW_VERSION}/repo/non-oss/ openLeap-non-oss
zypper ar http://codecs.opensuse.org/openh264/openSUSE_Leap_16 openh264

zypper refresh
# Sperren des games-Schemas
zypper addlock -t pattern games
# Sperren der KDE-spezifischen Schemata
zypper addlock -t pattern kde_games
zypper addlock -t pattern kde_office
# Sperren des kdump-Schemas
zypper addlock -t pattern kdump
# Optional: Sperren des office-Schemas
zypper addlock -t pattern office
zypper -n --releasever ${NEW_VERSION} dup --allow-vendor-change --no-recommends 2>&1 | tee /var/log/CRANIX-MIGRATE-TO-${NEW_VERSION}
if [ ${CRANIX_TYPE,,} == "cephalix" ]; then
	JAVA_API="cephalix-api"
        JAVA_LIB="/opt/cranix-java/lib/cranix-${NEW_VERSION}.jar"
        JAVA_APPLICATION="de.cranix.api.CephalixxApplication"
else
	JAVA_API="cephalix-api"
        JAVA_LIB="/opt/cranix-java/lib/cranix-${NEW_VERSION}.jar"
        JAVA_APPLICATION="de.cranix.api.CranixApplication"
fi

if [ "$( rpm -q --qf %{VERSION} cranix-base )" = "${NEW_VERSION}" ]; then
	/usr/bin/systemctl stop cron $JAVA_API
	sleep 30
        /usr/bin/systemctl enable samba-ad
        [ -e /etc/samba/smb-printserver.conf ] && /usr/bin/systemctl enable samba-printserver
        [ -e /etc/samba/smb-fileserver.conf ]  && /usr/bin/systemctl enable samba-fileserver
	echo "DROP TABLE DefaultPrinter" | /usr/bin/mariadb CRX
	echo "DROP TABLE AvailablePrinters" | /usr/bin/mariadb CRX
	java -Dfile.encoding=UTF-8 -Duser.country=US -Duser.language=en -Duser.variant -cp ${JAVA_LIB} ${JAVA_APPLICATION} setupDB
	sleep 3
	/usr/bin/mariadb CRX < /var/adm/backup/BEFOR-16/DefaultPrinter.sql
	/usr/bin/mariadb CRX < /var/adm/backup/BEFOR-16/DeviceDefaultPrinter.sql
	/usr/bin/mariadb CRX < /var/adm/backup/BEFOR-16/AvailablePrinter.sql
	/usr/bin/mariadb CRX < /var/adm/backup/BEFOR-16/DeviceAvailablePrinter.sql
        /sbin/reboot
else
        SUPPORT='{"email":"noreply@cephalix.eu","subject":"Migtration to CRANIX-'${NEW_VERSION}' failed","description":"Migtration to CRANIX-'${NEW_VERSION}' failed.","regcode":"'${CRANIX_REG_CODE}'"}'
        curl -s -X POST --header 'Content-Type: application/json' --header 'Accept: application/json' -d "${SUPPORT}" ${CRANIX_SUPPORT_URL}
        echo "Migration failed."
        echo "A support issue was created."
        echo "Do not restart the system!!!!"
fi

