#!/bin/bash
DATE=$( /usr/share/cranix/tools/crx_date.sh )
if [ ! -e /var/adm/cranix/migrate-4-4/outgoingRules.json ]; then
        sed -i s#CRANIX/4.3#CRANIX/4.4# /etc/zypp/credentials.cat
        sed -i s/4.3/4.4/ /etc/zypp/repos.d/CRANIX.repo

        mkdir -p /var/adm/cranix/migrate-4-4
        crx_api.sh GET system/firewall/outgoingRules > /var/adm/cranix/migrate-4-4/outgoingRules.json

        /usr/bin/systemctl stop samba-ad samba-printserver cron
        cp /var/lib/samba/registry.tdb /var/lib/samba/registry.tdb-${DATE}
        cp /var/lib/printserver/registry.tdb /var/lib/printserver/registry.tdb-${DATE}

        #Merge printserver into admin
        /usr/share/cranix/tools/merge-registry.py  >  /var/adm/cranix/migrate-4-4/new-registry
        mv /var/lib/samba/registry.tdb /var/adm/cranix/migrate-4-4/
        cat /var/adm/cranix/migrate-4-4/new-registry | /usr/bin/tdbrestore /var/lib/samba/registry.tdb
        rsync -aAv /var/lib/printserver/drivers/ /var/lib/samba/drivers/
        /usr/bin/systemctl start samba-ad

        EFOUND=$( gawk  '/CRANIX_PRINTSERVER/ { print NR } ' /etc/sysconfig/cranix )
        if [ "${EFOUND}" ]; then
                SFOUND=$((EFOUND-4))
                sed -i "${SFOUND},${EFOUND}d" /etc/sysconfig/cranix
        fi

        rpm -e --nodeps apparmor-parser
        rpm -e --nodeps apparmor-abstractions
fi
/usr/bin/zypper ref
zypper rl firewalld
/usr/bin/zypper -n dup 2>&1 | tee /var/log/CRANIX-MIGRATE-TO-4-4
if [ "$( rpm -q --qf %{VERSION} cranix-base )" = "4.4" ]; then
	. /etc/sysconfig/cranix
	cp /etc/firewalld/firewalld.conf /etc/firewalld/firewalld.conf.orig
	sed -i 's/DefaultZone=.*/DefaultZone=external/'         /etc/firewalld/firewalld.conf
	sed -i 's/FirewallBackend=.*/FirewallBackend=iptables/' /etc/firewalld/firewalld.conf

        /usr/share/cranix/tools/sync-rooms-to-firewalld.py
	if [ $CRANIX_ISGATE = "yes" ]; then
		EXTDEV=$( ip route | gawk '/default via/ { print $5 }' )
		echo "## Enable forwarding."                  >  /etc/sysctl.d/cranix.conf
		echo "net.ipv4.ip_forward = 1 "              >>  /etc/sysctl.d/cranix.conf
		echo "net.ipv6.conf.all.forwarding = 1 "     >>  /etc/sysctl.d/cranix.conf
		/usr/bin/firewall-offline-cmd --zone=external  --add-interface=$EXTDEV
		/usr/bin/firewall-offline-cmd --zone=external --remove-masquerade
	fi
        for i in $( ls /sys/devices/virtual/net/ | grep tun )
        do
                /usr/bin/firewall-offline-cmd --zone=trusted  --add-interface=$i
        done
        /usr/bin/systemctl start firewalld.service
        #Import outgoing rules:
        for i in $( cat /var/adm/cranix/migrate-4-4/outgoingRules.json |  jq --compact-output .[] )
        do
                echo "$i" > /tmp/out.json
                crx_api_post_file.sh system/firewall/outgoingRules /tmp/out.json
        done

	#Adapt samba settings
	/usr/share/cranix/tools/sync-cups-to-samba.py
else
        echo "Migration failed"
fi
