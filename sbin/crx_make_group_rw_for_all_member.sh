#!/bin/bash
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.
# Copyright (c) 2020 Peter Varkoly <pvarkoly@cephalix.eu> Nürnberg, Germany.  All rights reserved.

if [ -z "$1" ]; then
        echo "You have to provide a group name"
        exit 1
fi

cn=$1

g=$( echo $cn|tr '[:lower:]' '[:upper:]' )
i="/home/groups/$g"
/bin/mkdir -p  "$i"
gid=`/usr/sbin/crx_get_gidNumber.sh "$cn"`
if [ "$gid" ]
then
    chgrp -R $gid "$i"
    /usr/bin/setfacl -P -R -b "$i"
    find "$i" -type d -exec /usr/bin/chmod o-t,g+rwx {} \;
    find "$i" -type d -exec /usr/bin/setfacl -m g:$gid:rwx {} \;
    find "$i" -type d -exec /usr/bin/setfacl -d -m g:$gid:rwx {} \;
    echo "Repairing $i"
else
   echo "Class $cn do not exists. Can not repair $i"
fi  
