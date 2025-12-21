#!/bin/bash
#
# Copyright (c) 2025 Peter Varkoly Nürnberg, Germany.  All rights reserved.
#
if [ ! -e /etc/sysconfig/cranix ]; then
   echo "ERROR This ist not an CRANIX."
   exit 1
fi

uid=''

while read a
do
  b=${a/:*/}
  if [ "$a" != "${b}:" ]; then
     c=${a/$b: /}
  else
     c=""
  fi
  case "${b,,}" in
    uid)
      uid="${c}"
    ;;
  esac
done

if [ -z "$uid" ]; then
   echo "ERROR You have to define an uid."
   exit 4;
fi

if [[ "${CRANIX_DB_ONLY_ROLES,,}" =~ [[:<:]]${role,,}[[:>:]] ]]; then
	#This user does not exist in system
	exit 0
fi
MAILDIR="/var/spool/dovecot/${uid}/"
CANDIR=$( readlink -e ${MAILDIR} )
DATUM=$( /usr/share/cranix/tools/crx_date.sh )

if [ -d "$MAILDIR" -a ${CANDIR} != "/var/spool/dovecot/" ];
then
    tar czf /home/archiv/${uid}-mails-${DATUM}.tgz ${MAILDIR} && rm -rf ${MAILDIR}
fi
