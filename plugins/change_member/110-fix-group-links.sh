#!/bin/bash
#
# Copyright (c) 2025 Peter Varkoly Nürnberg, Germany.  All rights reserved.
#

if [ ! -x /usr/share/cranix/plugins/shares/groups/open/create_group_links.sh ]; then
   echo "ERROR This ist not an CRANIX."
   exit 1
fi

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
    users)
      users="${c}"
    ;;
  esac
done

IFS=','
for user in $users
do
        /usr/share/cranix/plugins/shares/groups/open/create_group_links.sh $user
done
