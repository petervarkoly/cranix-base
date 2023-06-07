#!/bin/bash
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.

uid=$1
template=$2

if [ -z "$template" ]; then
   template=$( crx_api_text.sh GET users/byUid/$uid/role )
   template="t${template}"
fi

HOMEDIR=$( /usr/sbin/crx_get_home.sh $uid )
TEMPLATEDIR=$( /usr/sbin/crx_get_home.sh $template )

if [ -d "$HOMEDIR" -a -d "$TEMPLATEDIR" ]; then
   rsync -a --exclude-from=/usr/share/cranix/templates/exclude-from-sync-home ${TEMPLATEDIR}/ ${HOMEDIR}/
   uidNumber=$( /usr/sbin/crx_get_uidNumber.sh $uid )
   chown -R $uidNumber ${HOMEDIR}/
fi
