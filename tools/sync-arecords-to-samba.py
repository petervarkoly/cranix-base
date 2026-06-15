#!/usr/bin/python3
import json
import os
import os.path
from bashconfigparser import BashConfigParser

devices=json.load(os.popen('crx_api.sh GET devices/all'))
domain=os.popen('crx_api_text.sh GET system/configuration/DOMAIN').read()
config = BashConfigParser(config_file="/opt/cranix-java/conf/cranix-api.properties")
passwd = config.get('de.cranix.dao.User.Register.Password')
for device in devices:
  ip   = device["ip"]
  name = device["name"]
  print("samba-tool computer add --ip-address={0} {1} -U register%'{2}'".format(ip,name,passwd) )
  os.system("samba-tool computer add --ip-address={0} {1} -U register%'{2}'".format(ip,name,passwd) )

