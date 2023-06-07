#!/bin/bash
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.

passwd=$( /usr/bin/grep de.cranix.dao.User.Register.Password= /opt/cranix-java/conf/cranix-api.properties | /usr/bin/sed 's/de.cranix.dao.User.Register.Password=//' )
/usr/bin/samba-tool dns zonelist admin -U register%${passwd} | /usr/bin/grep pszZoneName  | /usr/bin/grep -v _msdcs. | /usr/bin/gawk  '{ print $3 }'
