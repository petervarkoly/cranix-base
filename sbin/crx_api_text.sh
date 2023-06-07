#!/bin/bash
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.
# Copyright 2017 Peter Varkoly <peter@varkoly.de>

METHOD=$1
CALL=$2
DATA=$3
if [ "$DATA" ]; then
   DATAFILE=$( mktemp /tmp/CRANIX_APIXXXXXXXXXXX )
   echo "$DATA" > $DATAFILE
   DATA=" -d @${DATAFILE}"
fi

TOKEN=$( /usr/bin/grep de.cranix.api.auth.localhost= /opt/cranix-java/conf/cranix-api.properties | /usr/bin/sed 's/de.cranix.api.auth.localhost=//' )
/usr/bin/curl -s -X $METHOD --header 'Content-Type: application/json' --header 'Accept: text/plain' $DATA --header 'Authorization: Bearer '${TOKEN} "http://localhost:9080/api/$CALL"
if [ "${DATAFILE}" ]; then
    rm ${DATAFILE}
fi

