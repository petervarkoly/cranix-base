#!/bin/bash

GROUP=$1
for i in $( /usr/sbin/crx_api_text.sh GET groups/text/$GROUP/members )
do
        samba-tool group addmembers "$GROUP" $i
done

