#!/bin/bash
DATE=$( /usr/share/cranix/tools/crx_date.sh )
cp /etc/sysconfig/cranix /etc/sysconfig/cranix-${DATE}
sed -i s/oss-support@extis.de/support@cephalix.eu/ /etc/sysconfig/cranix
sed -i s/oss_/crx_/ /etc/sysconfig/cranix
sed -i s/OSS/CRANIX/g /etc/sysconfig/cranix
EFOUND=$( gawk  '/CRANIX_SUPPORT_MAIL_URL/ { print NR } ' /etc/sysconfig/cranix )
if [ "${EFOUND}" ]; then
	SFOUND=$((EFOUND-5))
	sed -i "${SFOUND},${EFOUND}d" /etc/sysconfig/cranix
fi
sed -i s#https://support.extis.de/support#https://repo.cephalix.eu/api/tickets/add#    /etc/sysconfig/cranix
sed -i s#https://support.cephalix.de/support#https://repo.cephalix.eu/api/tickets/add# /etc/sysconfig/cranix

