#!/usr/bin/python3
#
# Copyright (c) Peter Varkoly <peter@varkoly.de> Nuremberg, Germany.  All rights reserved.
#

import json
import os
import sys
from configobj import ConfigObj
config = ConfigObj("/opt/cranix-java/conf/cranix-api.properties")
passwd = config['de.cranix.dao.User.Register.Password']
name=""
ip=[]
wlanip=[]

for line in sys.stdin:
  kv = line.rstrip().split(": ",1)
  key = kv[0].lower()
  if key == "ip":
    ip=kv[1].split('.')
  elif key == "name":
    name=kv[1]
  elif key == "wlanip":
    wlanip=kv[1].split('.')

domain=os.popen('crx_api_text.sh GET system/configuration/DOMAIN').read()
netmask=int(os.popen('crx_api_text.sh GET system/configuration/NETMASK').read().rstrip())
network=os.popen('crx_api_text.sh GET system/configuration/NETWORK').read().split('.')
revdomain=""
if netmask > 23:
  revdomain = network[2]+'.'+network[1]+'.'+network[0]+'.IN-ADDR.ARPA'
  rdomain = ip[3]
  if wlanip != []:
    revwlan=wlanip[3]
elif netmask > 15:
  revdomain = network[1]+'.'+network[0]+'.IN-ADDR.ARPA'
  rdomain = ip[3]+'.'+ip[2]
  if wlanip != []:
    revwlan=wlanip[3]+'.'+wlanip[2]
elif netmask > 7:
  revdomain = network[0]+'.IN-ADDR.ARPA'
  rdomain = ip[3]+'.'+ip[2]+'.'+ip[1]
  if wlanip != []:
    revwlan=wlanip[3]+'.'+wlanip[2]+'.'+wlanip[1]

if os.system("samba-tool dns delete localhost " + revdomain + " " + rdomain + " PTR " + name + "." + domain + "  -U register%" + passwd ) != 0:
  TASK = "/var/adm/cranix/opentasks/101-delete-device-" + os.popen('uuidgen -t').read().rstrip()
  with open(TASK, "w") as f:
    f.write("ip: "+'.'.join(ip) +"\n")
    f.write("name: "+name +"\n")
    f.write("wlanip: " + '.'.join(wlanip))

if wlanip != []:
  if os.system("samba-tool dns delete localhost " + revdomain + " " + revwlan + " PTR " + name + "-wlan." + domain + "  -U register%" + passwd ) != 0:
    TASK = "/var/adm/cranix/opentasks/101-delete-device-" + os.popen('uuidgen -t').read().rstrip()
    with open(TASK, "w") as f:
      f.write("ip: "+'.'.join(ip) +"\n")
      f.write("name: "+name +"\n")
      f.write("wlanip: " + '.'.join(wlanip))

