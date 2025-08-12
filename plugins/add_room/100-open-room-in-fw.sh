#!/bin/bash


id=""
name=""
description=""
startip=""
netmask=""
while read a
do
  b=${a/:*/}
  if [ "$a" != "${b}:" ]; then
     c=${a/$b: /}
  else
     c=""
  fi
  case "${b,,}" in
    if)
      id="${c}"
    ;;
    name)
      name="${c}"
    ;;
    description)
      description="${c}"
    ;;
    startip)
      startip="${c}"
    ;;
    netmask)
      netmask="${c}"
    ;;
  esac
done

/usr/share/cranix/tools/firewall/open_rooms.py ${id}

