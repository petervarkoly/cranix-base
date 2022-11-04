#!/usr/bin/python3
# Copyright 2022 Dipl. Ing. Peter Varkoly <pvarkoly@cephalix.eu>
import json
import os
import re

zones = []
to_reload = False
for line in os.popen('/usr/bin/firewall-offline-cmd --list-all-zones').readlines():
    match1 = re.search("^(\S+)",line)
    if match1:
        zones.append(match1.group(1))

for room in json.load(os.popen('crx_api.sh GET rooms/all')):
    roomName = room['name'].strip()[0:17]
    if roomName not in zones:
        os.system('/usr/bin/firewall-offline-cmd --new-zone={0}'.format(roomName))
        os.system('/usr/bin/firewall-offline-cmd --zone={0} --set-description="Zone for Room {0}"'.format(roomName))
        os.system('/usr/bin/firewall-offline-cmd --zone={0} --add-source="{1}/{2}"'.format(roomName,room['startIP'],room['netMask']))
        os.system('/usr/bin/firewall-offline-cmd --zone={0} --set-target=ACCEPT'.format(roomName))
        to_reload = True
if to_reload:
    os.system('/usr/bin/firewall-cmd --reload')

