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

surname=''
givenname=''
role=''
uid=''
password=''
rpassword='no'
mpassword='no'
groups=""

abort() {
        TASK="delete_user-$( uuidgen -t )"
	mkdir -p /var/adm/cranix/opentasks/
        echo "uid: $uid" >> /var/adm/cranix/opentasks/$TASK
        echo "password: $password" >> /var/adm/cranix/opentasks/$TASK
        echo "surname: $surname" >> /var/adm/cranix/opentasks/$TASK
        echo "givenname: $givenname" >> /var/adm/cranix/opentasks/$TASK
        echo "role: $role" >> /var/adm/cranix/opentasks/$TASK
        exit 1
}

while read a
do
  b=${a/:*/}
  if [ "$a" != "${b}:" ]; then
     c=${a/$b: /}
  else
     c=""
  fi
  case "${b,,}" in
    surname)
      surname="${c}"
    ;;
    givenname)
      givenname="${c}"
    ;;
    uid)
      uid="${c}"
    ;;
    role)
      role="${c}"
      sysadmin="${c}"
    ;;
  esac
done

echo "uid:       $uid"

if [ -z "$uid" ]; then
   echo "ERROR You have to define an uid."
   exit 4;
fi
for i in ${CRANIX_DB_ONLY_ROLES,,}
do
    [ "$i" == "$role" ] && exit 0
done


HOMEDIR=$( /usr/sbin/crx_get_home.sh $uid )
UIDNUMBER=$(  /usr/sbin/crx_get_uidNumber.sh $uid )
# delete logon script
if [ -e /var/lib/samba/netlogon/$uid.bat ]; then
   rm  /var/lib/samba/netlogon/$uid.bat
fi

nice -19 /usr/share/cranix/tools/del_user_files --uid=$uid --uidnumber=$UIDNUMBER --startpath=${CRANIX_HOME_BASE} --homedir=${HOMEDIR} &

# delete user
samba-tool user delete "$uid"

if [ $? != 0 ]; then
   abort
fi
rm ${CRANIX_HOME_BASE}/${CRANIX_WORKGROUP}/$uid


