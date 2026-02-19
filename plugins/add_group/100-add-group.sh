#!/bin/bash
#
# Copyright (c) 2017 Peter Varkoly Nürnberg, Germany.  All rights reserved.
#

if [ ! -e /etc/sysconfig/cranix ]; then
   echo "ERROR This ist not an CRANIX."
   exit 1
fi

. /etc/sysconfig/cranix

if [ -z "${CRANIX_HOME_BASE}" ]; then
   echo "ERROR CRANIX_HOME_BASE must be defined."
   exit 2
fi

if [ ! -d "${CRANIX_HOME_BASE}" ]; then
   echo "ERROR CRANIX_HOME_BASE must be a directory and must exist."
   exit 3
fi

abort() {
        TASK="add_group-$( uuidgen -t )"
        mkdir -p /var/adm/cranix/opentasks/
        echo "name: $name" >> /var/adm/cranix/opentasks/$TASK
        echo "password: $password" >> /var/adm/cranix/opentasks/$TASK
        echo "description: $description" >> /var/adm/cranix/opentasks/$TASK
        echo "groupType: $groupType" >> /var/adm/cranix/opentasks/$TASK
	if [ "$mail" ]; then
		echo "mail: $mail" >> /var/adm/cranix/opentasks/$TASK
	fi
        exit 1
}


name=''
description=''
groupType=''
mail=''

while read a
do
  b=${a/:*/}
  if [ "$a" != "${b}:" ]; then
     c=${a/$b: /}
  else
     c=""
  fi
  case "${b,,}" in
    name)
      name="${c}"
    ;;
    description)
      description="${c}"
    ;;
    grouptype)
      groupType="${c}"
    ;;
    mail)
      mail="${c}"
    ;;
  esac
done

for i in ${CRANIX_DB_ONLY_ROLES,,}
do
    [ "$i" == "$role" ] && exit 0
done

nameLo="${name,,}"
name="${name^^}"

echo "name:        $name"
echo "description: $description"
echo "groupType:   $groupType"
echo "mail:        $mail"
#exit

params=''
if [ "$mail" ]; then
    params="--mail-address=\"$mail\""
fi

gidNumber=$( /usr/share/cranix/tools/get_next_id )
samba-tool group add "$name" --description="$description" --gid-number=$gidNumber --nis-domain="${CRANIX_WORKGROUP}" $params

if [ $? != 0 ]; then
   abort
fi

#create diredtory and set permission
gdir="${CRANIX_HOME_BASE}/groups/${name}"

mkdir -p -m 0770 "$gdir"
chgrp $gidNumber "$gdir"
setfacl -d -m g:$gidNumber:rwx "$gdir"

if [ "$groupType" = "primary" ]; then
   mkdir -m 750 "${CRANIX_HOME_BASE}/${nameLo}"
   chgrp $gidNumber "${CRANIX_HOME_BASE}/${nameLo}"
   samba-tool ou create OU="${nameLo}"
fi


#Take care about Class AdHocRooms
if [ "${CRANIX_MAINTAIN_ADHOC_ROOM_FOR_CLASSES}" = "yes" ]; then
	/usr/share/cranix/tools/handle_class_adhoc_rooms.py
fi
