#!/bin/bash -x

if [ -e /var/adm/cranix/migrate-4-4/printserver-fixed ]; then
        exit
fi
. /etc/sysconfig/cranix

IPPRINTSERVER=$( host printserver | gawk '{ print $4 }' )
IPPRSQL=$( echo  "select IP from Devices where name='printserver'" | mysql CRX | tail -n 1 )
NEXTIP=$( crx_api.sh GET rooms/1/availableIPAddresses | jq .[1] | sed 's/"//g' )
DEVINT=$( grep -l $CRANIX_SERVER /etc/sysconfig/network/ifcfg-* )

/usr/bin/systemctl restart samba-ad
sleep 3
if [ -z "${IPPRSQL}" ]
then
        #Original 4.4 There is nothing with printserver
        echo "INSERT INTO Devices VALUES(4,1,1,NULL,'printserver','${NEXTIP}',NULL,'','',0,0,'','','',0);" | mysql CRX
        /usr/bin/systemctl restart cranix-api.service
	sleep 3
        sed -i "s/CRANIX_PRINTSERVER=.*$/CRANIX_PRINTSERVER=\"${NEXTIP}\"/" /etc/sysconfig/cranix
        echo "${NEXTIP} printserver.${CRANIX_DOMAIN} printserver" >> /etc/hosts
        echo "IPADDR_print='${NEXTIP}/${CRANIX_NETMASK}'
LABEL_print='print'" >> ${DEVINT}
        ip addr add ${NEXTIP}/${CRANIX_NETMASK} dev ${DEVINT/*ifcfg-/}
        /usr/share/cranix/setup/scripts/crx-setup.sh --printserver
elif [ "${IPPRINTSERVER}" = ${CRANIX_SERVER} ]
then
        /usr/sbin/crx_update_host.sh printserver ${IPPRINTSERVER} ${IPPRSQL}
        sed -i "s/CRANIX_PRINTSERVER=.*$/CRANIX_PRINTSERVER=\"${IPPRSQL}\"/" /etc/sysconfig/cranix
        echo "IPADDR_print='${IPPRSQL}/${CRANIX_NETMASK}'
LABEL_print='print'" >> ${DEVINT}
        echo "${IPPRSQL} printserver.${CRANIX_DOMAIN} printserver" >> /etc/hosts
        ip addr add ${IPPRSQL}/${CRANIX_NETMASK} dev ${DEVINT/*ifcfg-/}
else
	registerpw=$( grep de.cranix.dao.User.Register.Password= /opt/cranix-java/conf/cranix-api.properties | sed 's/de.cranix.dao.User.Register.Password=//' )
        smbclient -L printserver -U register%${registerpw}
        if [ $? ! -eq 0 ];
        then
                SUPPORT='{"email":"noreply@cephalix.eu","subject":"Can not fix printserver configuration","description":"Can not fix printserver configuration","regcode":"'${CRANIX_REG_CODE}'"}'
                curl -s -X POST --header 'Content-Type: application/json' --header 'Accept: application/json' -d "${SUPPORT}" ${CRANIX_SUPPORT_URL}
        fi
fi
cp /usr/share/cranix/setup/templates/samba-printserver.service /usr/lib/systemd/system/
/usr/bin/systemctl daemon-reload
/usr/share/cranix/tools/sync-ptrrecords-to-samba.py
/usr/share/cranix/tools/sync-cups-to-samba.py
/usr/sbin/crx_manage_room_access.py --all --set_defaults
/usr/bin/systemctl start samba-printserver
/usr/bin/systemctl enable samba-printserver

mkdir -p /var/adm/cranix/migrate-4-4/
touch /var/adm/cranix/migrate-4-4/printserver-fixed
