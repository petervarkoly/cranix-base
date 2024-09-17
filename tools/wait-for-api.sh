#!/bin/bash

i=0
while test -z "$( /usr/bin/curl -s -X GET --header 'Content-Type: application/json' --header 'Accept: text/plain' --header 'Authorization: Bearer ' "http://localhost:9080/api/system/name" )"
do
    	echo "Waiting";
    	sleep 1;
	i=$((i+1))
	[ $i -gt 30 ] && break
done

