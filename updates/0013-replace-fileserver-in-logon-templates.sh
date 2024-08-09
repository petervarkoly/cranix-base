#!/bin/bash
#
#
. /etc/sysconfig/cranix
if [ -z "${CRANIX_FILESERVER_NETBIOSNAME}" ]; then
        CRANIX_FILESERVER_NETBIOSNAME="${CRANIX_NETBIOSNAME}"
fi
if [ "${CRANIX_FILESERVER_NETBIOSNAME}" ]; then
	for i in /usr/share/cranix/templates/login-*bat
	do
		sed -i "s/${CRANIX_FILESERVER_NETBIOSNAME}/#FILE-SERVER#/" $i
	done
fi
