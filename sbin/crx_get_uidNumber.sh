#!/bin/bash
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.

uid=$1

/usr/bin/ldbsearch -H /var/lib/samba/private/sam.ldb "uid=$uid" uidNumber  | /usr/bin/grep uidNumber: | /usr/bin/sed 's/uidNumber: //'

