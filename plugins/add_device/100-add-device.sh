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
  esac
done

passwd=$( grep de.cranix.dao.User.Register.Password= /opt/cranix-java/conf/cranix-api.properties | sed 's/de.cranix.dao.User.Register.Password=//' )

samba-tool dns add localhost $CRANIX_DOMAIN $name  A $ip   -U register%"$passwd"
if [ $? != 0 ]; then
   abort 1
fi
if [ "$wlanip" -a "$wlanmac" ]; then
	samba-tool dns add localhost $CRANIX_DOMAIN "${name}-wlan"  A $wlanip   -U register%"$passwd"
	if [ $? != 0 ]; then
	   abort 2
	fi
fi

