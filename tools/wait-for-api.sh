#!/bin/bash

while test -z "$( /usr/sbin/crx_api.sh GET users/all )"
do
        echo "Waiting";
        sleep 1;
done

