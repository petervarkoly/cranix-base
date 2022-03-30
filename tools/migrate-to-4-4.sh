#!/bin/bash
. /etc/sysconfig/cranix
DATE=$( /usr/share/cranix/tools/crx_date.sh )
sed -i 's/solver.dupAllowVendorChange.*/solver.dupAllowVendorChange = true/' /etc/zypp/zypp.conf
if [ ! -e /var/adm/cranix/migrate-4-4/outgoingRules.json ]; then
        sed -i s#CRANIX/4.3#CRANIX/4.4# /etc/zypp/credentials.cat
        sed -i s/4.3/4.4/ /etc/zypp/repos.d/CRANIX.repo

        mkdir -p /var/adm/cranix/migrate-4-4
        crx_api.sh GET system/firewall/outgoingRules > /var/adm/cranix/migrate-4-4/outgoingRules.json

        rpm -e --nodeps apparmor-parser
        rpm -e --nodeps apparmor-abstractions
	rpm -e --nodeps yast2-apparmor
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
                echo "$i" | sed 's/prot/protocol/' > /tmp/out.json
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
	ldapServer=$( grep 'ldap server require' /etc/samba/smb.conf )
	if [ -z "${ldapServer}" ]; then
		sed -i '/\[global\]/a ldap server require strong auth = no' /etc/samba/smb.conf
	fi

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
