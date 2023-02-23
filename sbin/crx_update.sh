DATE=$( /usr/share/cranix/tools/crx_date.sh )
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.
. /etc/profile.d/profile.sh
#Restart all processes which have deleted files
systemctl restart $( zypper ps --print "%s" )

zypper ref
echo "/var/log/CRANIX-UPDATE-$DATE" > /var/adm/cranix/update-started
zypper --no-gpg-checks --gpg-auto-import-keys -n up --auto-agree-with-licenses $@ 2>&1 | tee /var/log/CRANIX-UPDATE-$DATE

#Restart all processes which have deleted files
systemctl restart $( zypper ps --print "%s" )
rm /var/adm/cranix/update-started
