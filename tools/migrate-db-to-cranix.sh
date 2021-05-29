#!/bin/bash
if [ ! -e /etc/products.d/CRANIX.prod ]; then
	echo "Can be executed only after successfull migration to CRANIX."
        exit 0
fi
CALLER=$( cat /proc/$PPID/comm )
systemctl restart mysql
sleep 1
export HOME="/root"
CRANIX=$( echo "show tables" | mysql CRX | grep CrxNextID )
if [ "${CRANIX}" ];  then
        exit 0
fi

DATE=$( date +%Y-%m-%d-%H-%M )
echo "INSERT INTO Enumerates VALUES(NULL,'apiAcl','hwconf.modify',6);" | mysql OSS
mysqldump --databases OSS | gzip > OSS-BACKUP-${DATE}.sql.gz

echo "RENAME TABLE OssNextID TO CrxNextID;"     | mysql OSS
echo "RENAME TABLE OSSConfig  TO CrxConfig"     | mysql OSS
echo "RENAME TABLE OSSMConfig TO CrxMConfig"    | mysql OSS
echo "RENAME TABLE OssResponses TO CrxResponse" | mysql OSS
mysqldump --databases OSS > CRX.sql
sed -i '1,26s/OSS/CRX/' CRX.sql
mysql < CRX.sql
password=$( mktemp cranixXXXXXXXXXXXX )
if [ -e /opt/oss-java/conf/oss-api.properties.rpmsave ]; then
        cp /opt/cranix-java/conf/cranix-api.properties /opt/cranix-java/conf/cranix-api.properties.orig
        sed s/openschoolserver/cranix/ /opt/oss-java/conf/oss-api.properties.rpmsave > /opt/cranix-java/conf/cranix-api.properties
        rm /opt/oss-java/conf/oss-api.properties.rpmsave
fi
if [ -e /opt/oss-java/conf/config.yml.rpmsave ]; then
        cp /opt/cranix-java/conf/config.yml /opt/cranix-java/conf/config.yml.orig
	sed s/openschoolserver/cranix/g /opt/oss-java/conf/config.yml.rpmsave > /opt/cranix-java/conf/config.yml
	rm /opt/oss-java/conf/config.yml.rpmsave
fi
sed -i s/javax.persistence.jdbc.password=.*$/javax.persistence.jdbc.password=${password}/ /opt/cranix-java/conf/cranix-api.properties
sed -i 's/=claxss/=cranix/' /opt/cranix-java/conf/cranix-api.properties
echo "grant all on CRX.* to 'cranix'@'localhost'  identified by '$password'" | mysql
mkdir -p /var/adm/cranix/
#Add new acls:
ACLSUPPORT=$( echo "SELECT * FROM Acls where acl='system.support'" | mysql CRX )
ACLHWCONF=$( echo "SELECT * FROM Acls where acl='hwconf.modify'" | mysql CRX )
if [ -z "$ACLSUPPORT" ]; then
	echo "insert into Acls values(NULL,NULL,1,'system.support','Y',1);" | mysql CRX
fi
if [ -z "$ACLHWCONF" ]; then
	echo "insert into Acls Values(NULL,NULL,1,'hwconf.modify','Y',6);"  | mysql CRX
fi
ACLSUPPORT=$( echo "SELECT * FROM Enumerates where value='system.support'" | mysql CRX )
ACLHWCONF=$( echo "SELECT * FROM Enumerates where value='hwconf.modify'" | mysql CRX )
if [ -z "$ACLSUPPORT" ]; then
	echo "insert into Enumerates VALUES(NULL,'apiAcl','system.support',6);" | mysql CRX
fi
if [ -z "$ACLHWCONF" ]; then
	echo "insert into Enumerates VALUES(NULL,'apiAcl','hwconf.modify',6);" | mysql CRX
fi

if [ -e /usr/share/cephalix/templates ]; then
	/bin/bash /opt/cranix-java/data/adapt-cephalix-to-cranix.sh
	systemctl restart cephalix-api
else
	systemctl restart cranix-api
fi

for i in $( grep OSS in /etc/postfix/mysql*.cf )
do
	sed -i s/OSSConfig/CrxConfig/g $i
	sed -i s/OSS/CRX/g $i
done
echo "grant SELECT on CRX.Groups  to 'postfix'@'localhost'  identified by 'postfix';" | mysql
echo "grant SELECT on CRX.GroupMember  to 'postfix'@'localhost'  identified by 'postfix';" | mysql
echo "grant SELECT on CRX.CrxConfig  to 'postfix'@'localhost'  identified by 'postfix';" | mysql
echo "grant SELECT (id,uid) on CRX.Users to 'postfix'@'localhost'  identified by 'postfix'" | mysql
echo "grant SELECT on CRX.Aliases to 'postfix'@'localhost'  identified by 'postfix';" | mysql
