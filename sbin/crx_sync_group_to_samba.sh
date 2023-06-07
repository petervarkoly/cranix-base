#!/bin/bash
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.

GROUP=$1
for i in $( /usr/sbin/crx_api_text.sh GET groups/text/$GROUP/members )
do
        samba-tool group addmembers "$GROUP" $i
done

