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
        TASK="change_member-$( uuidgen -t )"
        mkdir -p /var/adm/cranix/opentasks/
        echo "changeType: $changeType" >> /var/adm/cranix/opentasks/$TASK
        echo "group: $group" >> /var/adm/cranix/opentasks/$TASK
        echo "users: $users" >> /var/adm/cranix/opentasks/$TASK
        exit 1
}

changeType=""
group=""
users=""

while read a
do
  b=${a/:*/}
  if [ "$a" != "${b}:" ]; then
     c=${a/$b: /}
  else
     c=""
  fi
  case "${b,,}" in
    changetype)
      changeType="${c}"
    ;;
    group)
      group="${c}"
    ;;
    users)
      users="${c}"
    ;;
  esac
done

samba-tool group $changeType "$group" $users
if [ $? != 0 ]; then
   abort
fi
