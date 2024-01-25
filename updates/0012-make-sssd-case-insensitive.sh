#!/bin/bash
#

if [ -z "$( grep case_sensitive /etc/sssd/sssd.conf )" ];
then
	/usr/bin/sed -i '/\[domain\/default\]/a case_sensitive = false' /etc/sssd/sssd.conf
	/usr/bin/systemctl restart sssd
fi
