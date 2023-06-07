#!/bin/bash
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.

cn=$1

/usr/bin/ldbsearch -H /var/lib/samba/private/sam.ldb "cn=$cn"  gidNumber  | /usr/bin/grep gidNumber: | /usr/bin/sed 's/gidNumber: //'

