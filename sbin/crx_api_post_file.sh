#!/bin/bash
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.
# Copyright 2018 Peter Varkoly <peter@varkoly.de>

CALL=$1
DATA=$2
DATA=" -d @${DATA}"

TOKEN=$( /usr/bin/grep de.cranix.api.auth.localhost= /opt/cranix-java/conf/cranix-api.properties | /usr/bin/sed 's/de.cranix.api.auth.localhost=//' )
/usr/bin/curl -s -X POST --header 'Content-Type: application/json' --header 'Accept: application/json' $DATA --header 'Authorization: Bearer '${TOKEN} "http://localhost:9080/api/$CALL"
