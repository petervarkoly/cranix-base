#!/bin/bash

i=0
while test -z "$( /usr/sbin/crx_api.sh GET users/all )"
do
    	echo "Waiting";
    	sleep 1;
	i=$((i+1))
	[ $i -gt 20 ] && break
done

