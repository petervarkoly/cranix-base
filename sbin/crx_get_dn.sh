#!/bin/bash
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.

cn=$1

if [ "$cn" ]; then
        /usr/bin/ldbsearch -H /var/lib/samba/private/sam.ldb "(&(!(objectClass=computer))(cn=$cn))" dn  | /usr/bin/grep dn:
else
        /usr/bin/ldbsearch -H /var/lib/samba/private/sam.ldb "(&(!(objectClass=computer))(cn=Builtin))" dn  | /usr/bin/grep dn: | sed 's/dn: CN=Builtin,//'
fi
