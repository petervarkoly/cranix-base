#!/bin/bash

cn=$1

/usr/bin/ldbsearch -H /var/lib/samba/private/sam.ldb "cn=$cn"  gidNumber  | /usr/bin/grep gidNumber: | /usr/bin/sed 's/gidNumber: //'

