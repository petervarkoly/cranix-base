#!/bin/bash
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.
domain=$1
if [ -z "${domain}" ]; then
	echo ""
	echo "Usage: crx_dump_dns_domain.sh <domain>"
	echo ""
	exit 1
fi
passwd=$( /usr/bin/grep de.cranix.dao.User.Register.Password= /opt/cranix-java/conf/cranix-api.properties | /usr/bin/sed 's/de.cranix.dao.User.Register.Password=//' )
samba-tool dns query 127.0.0.1 ${domain} @ ALL -U register%${passwd} | /usr/bin/sed -r 's/^\s+//'

