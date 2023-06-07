#!/bin/bash
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.

usage() 
{
	echo 
	echo -e "\tcrx_set_quota_for_group_member.sh -g=<group name> -q=<quota in MB> [-t|--teachers-also]"
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
       -q=*|--quota=*)
       QUOTA="${i#*=}"
       shift
       ;;
       -t|--teachers-also)
       TEACHERS="1"
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

if [ -z "$GROUP" -o -z "$QUOTA" ]; then
	usage
fi
for U in $( /usr/sbin/crx_api_text.sh GET groups/text/$GROUP/members )
do
	echo "Proceeding $U"
	role=$( /usr/sbin/crx_api_text.sh GET users/byUid/$U/role )
	if [ "$role" = "teachers" -a  -z "$TEACHERS" ]; then
		continue
	fi
	/usr/sbin/crx_set_quota.sh $U $QUOTA
done

