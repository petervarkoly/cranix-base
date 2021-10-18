#!/bin/bash

sed -i 's/Header always set Access-Control-Allow-Methods.*/Header always set Access-Control-Allow-Methods "POST, GET, OPTIONS, DELETE, PUT, PATCH"/' \
	/etc/apache2/vhosts.d/admin_include.conf

if [ -e /etc/apache2/vhosts.d/cephalix_include.conf ]
then
	sed -i 's/Header always set Access-Control-Allow-Methods.*/Header always set Access-Control-Allow-Methods "POST, GET, OPTIONS, DELETE, PUT, PATCH"/' \
		/etc/apache2/vhosts.d/cephalix_include.conf
fi

/usr/bin/systemctl reload apache2
