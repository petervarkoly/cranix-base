#!/usr/bin/python3
# Copyright 2022 pvarkoly@cephalix.eu

import configparser
import json
import subprocess
import sys

printer = {}
printer = json.loads(sys.stdin.read())

#Remove printer from cups
subprocess.run(['/usr/sbin/lpadmin','-x',printer['name']])

#Remove printer from samba
config = configparser.ConfigParser(delimiters=('='), strict=False)
config.read('/etc/samba/smb-printserver.conf')
if printer['name'] in config:
    config.remove_section(printer['name'])
    with open('/etc/samba/smb-printserver.conf','wt') as f:
        config.write(f)
#Restart samba
subprocess.run(['/usr/bin/systemctl','restart','samba-printserver'])
