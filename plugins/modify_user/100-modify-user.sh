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
uid=''
password=''
rpassword='no'
mpassword='no'
groups=""
fsquota=0
msquota=0

abort() {
	TASK="modify_user-$( uuidgen -t )"
	mkdir -p /var/adm/cranix/opentasks/
	echo "reason: $1"            >> /var/adm/cranix/opentasks/$TASK
	echo "uid: $uid"             >> /var/adm/cranix/opentasks/$TASK
	echo "password: $password"   >> /var/adm/cranix/opentasks/$TASK
	echo "mpassword: $mpassword" >> /var/adm/cranix/opentasks/$TASK
	echo "surname: $surname"     >> /var/adm/cranix/opentasks/$TASK
	echo "givenname: $givenname" >> /var/adm/cranix/opentasks/$TASK
	echo "fsquota: $fsquota"     >> /var/adm/cranix/opentasks/$TASK
        echo "msquota: $msquota"     >> /var/adm/cranix/opentasks/$TASK
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
    password)
      password="${c}"
    ;;
    mpassword)
      mpassword="${c}"
    ;;
    fsquota)
      fsquota="${c}"
    ;;
    msquota)
      msquota="${c}"
      msquota=$((msquota*1024))
    ;;
  esac
done

#Set fsquota
/usr/sbin/crx_set_quota.sh $uid $fsquota

#Set mailsystem quota
/usr/sbin/crx_set_mquota.pl $uid $msquota

if [ "$surname" -a "$givenname" ]
then

DN=$( /usr/bin/ldbsearch -H /var/lib/samba/private/sam.ldb uid=$uid dn | grep dn: | sed 's/dn: //' )

FILE=$( mktemp /tmp/modify-user-XXXXXXXX )
echo "dn: $DN
changetype: modify
replace: givenname
givenname: $givenname
-
replace: sn
sn: $surname" > $FILE

ldbmodify  -H /var/lib/samba/private/sam.ldb $FILE
if [ $? != 0 ]; then
   rm -f $FILE
   abort 1
fi
rm -f $FILE

fi

if [ "$mpassword" != "no" ]; then
    ADDPARAM="--must-change-at-next-login"
fi

if [ "$password" ]; then
    samba-tool user setpassword $uid --newpassword="$password" $ADDPARAM
    if [ $? != 0 ]; then
       abort 2
    fi
fi

