#!/bin/bash
# Copyright (c) 2021 Peter Varkoly <pvarkoly@cephalix.eu> Nürnberg, Germany.  All rights reserved.
# This script creats the quota reports for users who have exceeded the disk quota

rm -rf /home/groups/SYSADMINS/SearchUsersFiles
for ROLE in $( /usr/sbin/crx_api_text.sh GET groups/text/byType/primary )
do
        for U in $( /usr/sbin/crx_api.sh GET users/uidsByRole/${ROLE} )
        do
                QUOTA=$( /usr/bin/quota -w ${U} | grep '*' )
                if [ "${QUOTA}" ]
                then
                        /usr/share/cranix/tools/find_files_of_user.sh --uid=${U} &> /dev/null
                fi
        done
done

