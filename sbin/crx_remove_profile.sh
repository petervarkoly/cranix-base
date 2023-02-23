#!/bin/bash
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.
. /etc/sysconfig/cranix
uid=$1

for i in ${CRANIX_HOME_BASE}/profiles/$uid.V*
do
    if [ -e "$i" ]
    then
        rm -rf $i
    fi
done
