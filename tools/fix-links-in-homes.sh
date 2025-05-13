#!/bin/bash
for u in $( /usr/sbin/crx_get_all_user.sh )
do
	/usr/share/cranix/plugins/shares/groups/open/create_group_links.sh $u
done
