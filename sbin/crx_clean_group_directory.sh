#!/bin/bash
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.
group=$1
CRANIX_HOME_BASE="/home"
. /etc/sysconfig/cranix

nameUp=`echo "$group" | tr "[:lower:]" "[:upper:]"`

gdir=${CRANIX_HOME_BASE}/groups/${nameUp}

if [ -d "${gdir}" ] ; then
	rm -rf ${gdir}
fi

mkdir -p -m 3770 $gdir
chgrp $nameUp $gdir
setfacl -d -m g::rwx $gdir

