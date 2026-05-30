#!/usr/bin/python3
# Sync the ip addresses from the Devices table into the samba dns server
# This can be neccessary if someone has made some manual changes
# Copyright Dipl Ing Peter Varkoly <peter@varkoly.de>

import json
import os
import sys
import socket
from bashconfigparser import BashConfigParser

config = BashConfigParser(config_file="/opt/cranix-java/conf/cranix-api.properties")
passwd = config.get('de.cranix.dao.User.Register.Password')
domain = os.popen('crx_api_text.sh GET system/configuration/DOMAIN').read()

devices=json.load(os.popen('/usr/sbin/crx_api.sh GET devices/all'))
for device in devices:
  print(device)
  try:
    oldip=socket.gethostbyname(device['name'])
  except:
    if os.system("samba-tool dns add localhost " + domain + " " + device['name'] + " A " + device['ip'] + "  -U register%" + passwd ) != 0:
      print("Can not create dns entry for " + device['name'] + " " + device['ip'] )
    else:
      oldip=device['ip']
  if device['ip'] != oldip:
    if os.system("samba-tool dns update localhost " + domain + " " + device['name'] + " A " + oldip + " " + device['ip'] + "  -U register%" + passwd ) != 0:
      print("Can not update dns entry for " + device['name'] + " from:" + oldip + " to:" + device['ip'] )

print("Recreate the reverse zone")

netmask=int(os.popen('crx_api_text.sh GET system/configuration/NETMASK').read().rstrip())
network=os.popen('crx_api_text.sh GET system/configuration/NETWORK').read().split('.')
revdomain=""
print(netmask)
if netmask > 23:
  revdomain = network[2]+'.'+network[1]+'.'+network[0]+'.IN-ADDR.ARPA'
elif netmask > 15 and netmask < 24:
  revdomain = network[1]+'.'+network[0]+'.IN-ADDR.ARPA'
elif netmask > 7 and netmask < 16:
  revdomain = network[0]+'.IN-ADDR.ARPA'

os.system("samba-tool dns zonedelete localhost " + revdomain + " -U register%" + passwd)
os.system("samba-tool dns zonecreate localhost " + revdomain + " -U register%" + passwd)
for device in devices:
  ip   = device["ip"].split('.')
  name = device["name"]
  if netmask > 23:
    if ip[0] != network[0] or ip[1] != network[1] or ip[2] != network[2]:
      next
    rdomain = ip[3]
  elif netmask > 15:
    if ip[0] != network[0] or ip[1] != network[1]:
      next
    rdomain = ip[3]+'.'+ip[2]
  elif netmask > 7:
    if ip[0] != network[0]:
      next
    rdomain = ip[3]+'.'+ip[2]+'.'+ip[1]
  os.system("samba-tool dns add localhost " + revdomain + " " + rdomain + " PTR " + name + "." + domain + "  -U register%" + passwd )

