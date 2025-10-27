#!/bin/bash
. /etc/sysconfig/cranix

abort() {
        TASK="add_device-$( uuidgen -t )"
        mkdir -p /var/adm/cranix/opentasks/
	echo "reason: $1" >> /var/adm/cranix/opentasks/$TASK
        echo "name: $name" >> /var/adm/cranix/opentasks/$TASK
        echo "ip: $ip" >> /var/adm/cranix/opentasks/$TASK
        echo "mac: $mac" >> /var/adm/cranix/opentasks/$TASK
        echo "wlanip: $wlanip" >> /var/adm/cranix/opentasks/$TASK
        echo "wlanmac: $wlanmac" >> /var/adm/cranix/opentasks/$TASK
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
    name)
      name="${c}"
    ;;
    ip)
      ip="${c}"
    ;;
    mac)
      mac="${c}"
    ;;
    wlanip)
      wlanip="${c}"
    ;;
    wlanmac)
      wlanmac="${c}"
    ;;
    roomname)
      roomname="${c}"
    ;;
  esac
done

cat << EOF | socat UNIX:/run/kea/kea4-ctrl-socket -,ignoreeof
{
    "command": "reservation-add",
    "service": [ "dhcp4" ],
    "arguments": {
        "reservation": {
                  "subnet-id": 1,
                  "hw-address": "${mac}",
                  "ip-address": "${ip}",
                  "hostname": "${name}.${CRANIX_DOMAIN}",
                  "client-classes": ["${roomname}"]
        }
     }
}
EOF

if [ "$wlanip" -a "$wlanmac" ]; then
cat << EOF | socat UNIX:/run/kea/kea4-ctrl-socket -,ignoreeof
{
    "command": "reservation-add",
    "service": [ "dhcp4" ],
     "arguments": {
        "reservation": {
                  "subnet-id": 1,
                  "hw-address": "${wlanmac}",
                  "ip-address": "${wlanip}",
                  "hostname": "${name}-wlan.${CRANIX_DOMAIN}",
                  "client-classes": ["${roomname}"]
        }
     }
}
EOF
fi

