#!/bin/bash
# (C) 2021 Peter Varkoly <pvarkoly@cephalix.eu>

import=$1
itype=$2
if [ -z "${itype}" ]; then
        itype="txt"
fi

if [ -d  /home/groups/SYSADMINS/userimports/${import} ]
then
        cd /home/groups/SYSADMINS/userimports/${import}
        rm -f userimport.zip
        zip userimport.zip *.${itype}
fi
