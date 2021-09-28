#!/bin/bash

USER=$1
IFS=$'\n'
for i in $( /usr/sbin/crx_api_text.sh GET users/text/$USER/groups )
do
        samba-tool group addmembers "$i" $USER
done
for i in $( /usr/sbin/crx_api_text.sh GET users/text/$USER/classes )
do
        samba-tool group addmembers "$i" $USER
done
samba-tool group addmembers  "$( /usr/sbin/crx_api_text.sh GET users/text/$USER/role )" $USER


