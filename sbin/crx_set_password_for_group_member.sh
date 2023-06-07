#!/bin/bash
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.

usage() 
{
	echo 
	echo -e "\tcrx_set_password_for_group_member.sh -g=<group name> -p=<password> [ --must-change ]"
	echo
	exit 
}

for i in "$@"
do
   case $i in
       -g=*|--group=*)
       GROUP="${i#*=}"
       shift
       ;;
       -p=*|--password=*)
       PASSWORD="${i#*=}"
       shift
       ;;
       -m|--must-change)
       ATTR="${ATTR} --must-change-at-next-login"
       shift
       ;;
       -h|--help)
           usage
       ;;
       *)
   	   usage
       ;;
   esac
done

if [ -z "$GROUP" -o -z "$PASSWORD" ]; then
	usage
fi
for i in $( /usr/sbin/crx_api_text.sh GET groups/text/$GROUP/members )
do
	echo "Proceeding $i"
	samba-tool user setpassword $i --newpassword="$PASSWORD" ${ATTR}
done

