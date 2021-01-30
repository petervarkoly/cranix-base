#!/bin/bash

sed -i s#OSS/4.1#CRANIX/4.3# /etc/zypp/credentials.cat
sed -i 's/solver.dupAllowVendorChange.*$/solver.dupAllowVendorChange = true/' /etc/zypp/zypp.conf
mv /etc/zypp/repos.d/OSS.repo /etc/zypp/repos.d/CRANIX.repo
sed -i s/OSS/CRANIX/ /etc/zypp/repos.d/CRANIX.repo
sed -i s/4.1/4.3/ /etc/zypp/repos.d/CRANIX.repo
sed s/SCHOOL_/CRANIX_/ /etc/sysconfig/schoolserver > /etc/sysconfig/cranix
sed -i "s/oss_/crx_/g" /etc/sysconfig/cranix
sed -i "s/samba /samba-ad /" /etc/sysconfig/cranix
sed -i s/ntpd/chronyd/ /etc/sysconfig/cranix
sed -i s/oss-api/cranix-api/ /etc/sysconfig/cranix
mkdir -p /usr/share/cranix/templates/
rsync -aAv /usr/share/oss/templates/ /usr/share/cranix/templates/
sed -i s#oss/plugins#cranix/plugins# /etc/samba/smb.conf
sed -i s#oss/tools#cranix/tools# /etc/samba/smb.conf
sed -i s#oss/templates#cranix/templates# /usr/share/cranix/templates/password.html
sed -i s/oss_api.sh/crx_api.sh/ /etc/sysconfig/scripts/SuSEfirewall2-custom
sed -i 's#^external_acl_type checkip.*$#external_acl_type checkip ttl=60 children-max=30 ipv4 %SRC /usr/share/cranix/tools/squid_sso.py#'  /etc/squid/squid.conf
zypper mr -G -p 1 CRANIX

if [ -e /etc/chrony.d/oss.conf ]; then
	mv /etc/chrony.d/oss.conf /etc/chrony.d/cranix.conf
fi
cp /usr/share/oss/tools/migrate-db-to-cranix.sh /var/adm/oss/migrate-db-to-cranix.sh
passwd=$( grep de.openschoolserver.dao.User.Register.Password= /opt/oss-java/conf/oss-api.properties | sed 's/de.openschoolserver.dao.User.Register.Password=//' )
echo "#Rejoin printserver to AD" >> /var/adm/oss/migrate-db-to-cranix.sh
echo "net ADS JOIN -s /etc/samba/smb-printserver.conf -U register%${passwd}" >> /var/adm/oss/migrate-db-to-cranix.sh

chmod 755 /var/adm/oss/migrate-db-to-cranix.sh
systemctl restart atd

echo "/usr/bin/zypper ref &>  /var/log/MIGRATE-TO-CRANIX-1.log
/usr/bin/zypper -n dup &>  /var/log/MIGRATE-TO-CRANIX-2.log
if [ ! -e /etc/products.d/CRANIX.prod ]
then
	echo "Migration TO CRANIX Failed" > /var/log/MIGRATE-TO-CRANIX-FAILED
	exit 1
fi
/usr/bin/systemctl enable samba-ad
/usr/bin/systemctl start  samba-ad
sleep 600
/bin/rpm -e --nodeps OSS-release-dvd &>  /var/log/MIGRATE-TO-CRANIX-3.log
cd /etc/products.d
rm baseproduct
ln -s CRANIX.prod baseproduct
cd
if [ ! -e /etc/chrony.d/cranix.conf ]; then
	/usr/share/cranix/setup/scripts/setup-chrony.sh
fi
/var/adm/oss/migrate-db-to-cranix.sh
/usr/lib/systemd-presets-branding/branding-preset-states save
reboot
" |  at "now + 1 minute"

