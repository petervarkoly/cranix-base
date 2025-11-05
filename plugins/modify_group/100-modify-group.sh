#!/bin/bash
#
# Copyright (c) 2022 Peter Varkoly Nürnberg, Germany.  All rights reserved.
#

if [ ! -e /etc/sysconfig/cranix ]; then
   echo "ERROR This ist not an CRANIX."
   exit 1
fi

abort() {
        TASK="modify_group-$( uuidgen -t )"
        mkdir -p /var/adm/cranix/opentasks/
        echo "name: $name" >> /var/adm/cranix/opentasks/$TASK
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

nameLo="${name,,}"
name="${name^^}"

echo "name:        $name"
echo "description: $description"
echo "groupType:   $groupType"
echo "mail:        $mail"
#exit

DN=$( /usr/bin/ldbsearch -H /var/lib/samba/private/sam.ldb cn=${name} dn | grep dn: )

FILE=$( mktemp /tmp/modify-group-XXXXXXXX )

echo "$DN
changetype: modify
replace: description
description: ${description}" > $FILE

ldbmodify  -H /var/lib/samba/private/sam.ldb $FILE
if [ $? != 0 ]; then
   rm -f $FILE
   abort 1
fi
rm -f $FILE

