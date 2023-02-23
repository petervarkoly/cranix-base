#!/bin/bash
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.

name=$1
ip=$2
nip=$3
if [ -z "$1" -o -z "$2" -o -z "$3" ]; then
        echo "usage $@ name oldip newip [ domain ]"
        exit 1
fi
CRANIX_DOMAIN=$4
if [ -z "${CRANIX_DOMAIN}" ]; then
        . /etc/sysconfig/cranix
fi


passwd=$( /usr/bin/grep de.cranix.dao.User.Register.Password= /opt/cranix-java/conf/cranix-api.properties | /usr/bin/sed 's/de.cranix.dao.User.Register.Password=//' )

samba-tool dns update localhost $CRANIX_DOMAIN $name  A $ip $nip  -U register%"$passwd"
echo "name: $name
ip: $ip" | /usr/share/cranix/plugins/delete_device/101-delete-device.py
echo "name: $name
ip: $nip" | /usr/share/cranix/plugins/add_device/101-add-device.py

