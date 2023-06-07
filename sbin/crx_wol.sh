#!/bin/bash
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.

MAC=$1
IP=$2

. /etc/sysconfig/dhcpd

if  [ -e /usr/bin/wol ]
then
	/usr/bin/wol -i $IP $MAC
fi

if [ -e /sbin/ether-wake ]
then
        for i in $DHCPD_INTERFACE
        do
                /sbin/ether-wake -i $i $MAC
        done
fi

