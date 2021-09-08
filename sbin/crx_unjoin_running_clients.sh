#!/bin/bash
. /etc/sysconfig/cranix
passwd=$( grep de.cranix.dao.User.Register.Password= /opt/cranix-java/conf/cranix-api.properties | sed 's/de.cranix.dao.User.Register.Password=//' )
for i in /var/adm/cranix/running/*
do
     client=$( basename $i )
     salt "${client}" system.unjoin_domain domain="${CRANIX_DOMAIN}" username='register' password="${passwd}" restart=True
     echo ${client}
done
