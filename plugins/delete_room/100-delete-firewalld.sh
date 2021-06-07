#!/bin/bash

abort() {
        TASK="add_room-$( uuidgen -t )"
        mkdir -p /var/adm/cranix/opentasks/
        echo "name: $name" >> /var/adm/cranix/opentasks/$TASK
        echo "start: $start" >> /var/adm/cranix/opentasks/$TASK
        echo "netmask: $netmask" >> /var/adm/cranix/opentasks/$TASK
        echo "hwconf: $hwconf" >> /var/adm/cranix/opentasks/$TASK
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
  case $b in
    name)
      name="${c}"
    ;;
    startip)
      startip="${c}"
    ;;
    netmask)
      netmask="${c}"
    ;;
    hwconf)
      hwconf="${c}"
    ;;
  esac
done

firewall-cmd --permanent --delete-zone=${name}
firewall-cmd --reload
