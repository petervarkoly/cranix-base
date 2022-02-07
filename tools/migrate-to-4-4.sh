#!/bin/bash
. /etc/sysconfig/cranix
DATE=$( /usr/share/cranix/tools/crx_date.sh )
sed -i 's/solver.dupAllowVendorChange.*/solver.dupAllowVendorChange = true/' /etc/zypp/zypp.conf
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

        rpm -e --nodeps apparmor-parser
        rpm -e --nodeps apparmor-abstractions
	rpm -e --nodeps yast2-apparmor
fi

#Ask if separate printserver should stay
if [ -e /usr/lib/systemd/system/samba-printserver.service ]; then
	echo ""
	echo "#################################################################"
	echo ""
	echo -n "Möchten Sie die alte Printserverkonfigration behalten [j/n]";
	read KEEPPRINT
	if [ "${KEEPPRINT,,}" != "j" ]; then
		systemctl disable samba-printserver.service
		mv /usr/lib/systemd/system/samba-printserver.service /var/adm/cranix/migrate-4-4/
		EFOUND=$( gawk  '/CRANIX_PRINTSERVER/ { print NR } ' /etc/sysconfig/cranix )
		if [ "${EFOUND}" ]; then
			SFOUND=$((EFOUND-4))
			sed -i "${SFOUND},${EFOUND}d" /etc/sysconfig/cranix
		fi
		/usr/sbin/crx_update_host.sh printserver ${CRANIX_PRINTSERVER} ${CRANIX_SERVER}
		sed -i /printserver/d /etc/hosts
		IFCFGPRINT=$( grep -l IPADDR_print /etc/sysconfig/network/ifcfg-* )
		if [ "${IFCFGPRINT}" ]; then
			cp ${IFCFGPRINT} /var/adm/cranix/migrate-4-4/
			sed -i /IPADDR_print/d ${IFCFGPRINT}
			sed -i /LABEL_print/d  ${IFCFGPRINT}
		fi
	fi
fi

/usr/bin/zypper ref
zypper rl firewalld
export LDAPBASE=$( crx_get_dn.sh ossreader | sed 's/dn: CN=ossreader,CN=Users,//' )
/usr/bin/zypper -n dup 2>&1 | tee /var/log/CRANIX-MIGRATE-TO-4-4
if [ "$( rpm -q --qf %{VERSION} cranix-base )" = "4.4" ]; then
	. /etc/sysconfig/cranix
	#Adapt firewall configuration
	cp /etc/firewalld/firewalld.conf /etc/firewalld/firewalld.conf.orig
	sed -i 's/DefaultZone=.*/DefaultZone=external/'         /etc/firewalld/firewalld.conf
	sed -i 's/FirewallBackend=.*/FirewallBackend=iptables/' /etc/firewalld/firewalld.conf
	sed -i "s/CRANIX_MONITOR_SERVICES=.*/CRANIX_MONITOR_SERVICES=\"${CRANIX_MONITOR_SERVICES} firewalld\"/" /etc/sysconfig/cranix

        /usr/share/cranix/tools/sync-rooms-to-firewalld.py
	if [ $CRANIX_ISGATE = "yes" ]; then
		EXTDEV=$( ip route | gawk '/default via/ { print $5 }' )
		echo "## Enable forwarding."                  >  /etc/sysctl.d/cranix.conf
		echo "net.ipv4.ip_forward = 1 "              >>  /etc/sysctl.d/cranix.conf
		echo "net.ipv6.conf.all.forwarding = 1 "     >>  /etc/sysctl.d/cranix.conf
		/usr/bin/firewall-offline-cmd --zone=external --add-interface=$EXTDEV
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
	#Importing incoming rules:
	. /etc/sysconfig/SuSEfirewall2
	for i in $FW_SERVICES_EXT_TCP;
	do
		if [ $i = 444 ]; then
			/usr/bin/firewall-offline-cmd --zone=external --add-service=admin
			echo "Enable admin service";
		elif [[ ${i,,} == *[a-z] ]]; then
			/usr/bin/firewall-offline-cmd --zone=external --add-service=${i,,}
			echo "Enable $i service";
		else
			/usr/bin/firewall-offline-cmd --zone=external --add-port="${i}/tcp"
			echo "Enable $i tcp port";
		fi;
	done
	for i in $FW_SERVICES_EXT_UDP;
	do
		if [[ ${i,,} == *[a-z] ]]; then
			/usr/bin/firewall-offline-cmd --zone=external --add-service=${i,,}
			echo "Enable $i service";
		else
			/usr/bin/firewall-offline-cmd --zone=external --add-port="${i}/udp"
			echo "Enable $i udp port";
		fi;
	done

	#Adapt samba settings
	/usr/share/cranix/tools/sync-cups-to-samba.py

	#Setup sssd configuration
	sed "s/###LDAPBASE###/$LDAPBASE/" /usr/share/cranix/setup/templates/sssd.conf > /etc/sssd/sssd.conf
	sed -i "s/###WORKGROUP###/${CRANIX_WORKGROUP}/" /etc/sssd/sssd.conf
	cp /usr/share/cranix/setup/templates/nsswitch.conf  /etc/nsswitch.conf
	chmod 600 /etc/sssd/sssd.conf
	PAMWINBIND=$( grep winbind /etc/pam.d/* )
	if [ "${PAMWINBIND}" ]; then
		pam-config --add --sss
	fi
	/usr/bin/systemctl enable sssd firewalld
	/sbin/reboot	
else
        echo "Migration failed"
fi
