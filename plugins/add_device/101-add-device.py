#!/usr/bin/python3
#
# Copyright (c) Peter Varkoly <peter@varkoly.de> Nuremberg, Germany.  All rights reserved.
#
import json
import os
import sys
import cranixconfig
from configobj import ConfigObj
config = ConfigObj("/opt/cranix-java/conf/cranix-api.properties")
passwd = config['de.cranix.dao.User.Register.Password']
name=""
ip=[]
wlanip=[]

for line in sys.stdin:
  kv  = line.rstrip().split(": ",1)
  key = kv[0].lower()
  if key == "ip":
    ip=kv[1].split('.')
  elif key == "name":
    name=kv[1]
  elif key == "wlanip":
    wlanip=kv[1].split('.')

domain=cranixconfig.CRANIX_DOMAIN
netmask=int(cranixconfig.CRANIX_NETMASK)
network=cranixconfig.CRANIX_NETWORK.split('.')
revdomain=""
revwlan=""
if netmask > 23:
  if ip[0] != network[0] or ip[1] != network[1] or ip[2] != network[2]:
    os.exit(0)
  revdomain = network[2]+'.'+network[1]+'.'+network[0]+'.IN-ADDR.ARPA'
  rdomain = ip[3]
  if wlanip != []:
    revwlan=wlanip[3]
elif netmask > 15:
  if ip[0] != network[0] or ip[1] != network[1]:
    os.exit(0)
  revdomain = network[1]+'.'+network[0]+'.IN-ADDR.ARPA'
  rdomain   = ip[3]+'.'+ip[2]
  if wlanip != []:
    revwlan=wlanip[3]+'.'+wlanip[2]
elif netmask > 7:
  if ip[0] != network[0]:
    os.exit(0)
  revdomain = network[0]+'.IN-ADDR.ARPA'
  rdomain = ip[3]+'.'+ip[2]+'.'+ip[1]
  if wlanip != []:
    revwlan=wlanip[3]+'.'+wlanip[2]+'.'+wlanip[1]

if os.system("samba-tool dns add localhost " + revdomain + " " + rdomain + " PTR " + name + "." + domain + "  -U register%" + passwd ) != 0:
  TASK = "/var/adm/cranix/opentasks/101-add-device-" + os.popen('uuidgen -t').read().rstrip()
  with open(TASK, "w") as f:
    f.write("ip: "+'.'.join(ip) +"\n")
    f.write("name: "+name +"\n")
    f.write("wlanip: "+ '.'.join(wlanip))

if wlanip != []:
  if os.system("samba-tool dns add localhost " + revdomain + " " + revwlan + " PTR " + name + "-wlan." + domain + "  -U register%" + passwd ) != 0:
    TASK = "/var/adm/cranix/opentasks/101-add-device-" + os.popen('uuidgen -t').read().rstrip()
    with open(TASK, "w") as f:
      f.write("ip: "+'.'.join(ip) +"\n")
      f.write("name: "+name +"\n")
      f.write("wlanip: " + '.'.join(wlanip))
