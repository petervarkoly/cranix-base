#!/bin/bash
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.
user=$1
quota=$2

EXT3=$( mount | /usr/bin/grep "on /home type ext3" )
if [ "$EXT3" ]; then
	fquota=$((quota*1024))
	/usr/sbin/setquota -u $user $fquota $fquota 0 0 /home
else
	bsoft=$((quota*1024*1024))
	bhard=$((bsoft+bsoft/10))
	xfs_quota -x -c "limit -u bsoft=$bsoft bhard=$bhard $user" /home
fi
