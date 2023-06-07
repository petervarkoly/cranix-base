#!/usr/bin/python3

from configobj import ConfigObj
config = ConfigObj("/opt/cranix-java/conf/cranix-api.properties")
passwd = config['de.cranix.dao.User.Register.Password']

import configparser
import json
import subprocess
import sys
import cranixconfig
import time

try:
    printserver = cranixconfig.CRANIX_PRINTSERVER_NAME
except AttributeError:
    printserver = "printserver"
try:
    config_file = cranixconfig.CRANIX_PRINTSERVER_CONFIG
except AttributeError:
    config_file = "/etc/samba/smb-printserver.conf"

printer = {}
printer = json.loads(sys.stdin.read())

if printer['action'] == 'activateWindowsDriver':
   ret =  subprocess.run(["/usr/sbin/cupsaddsmb",
            "-H",printserver,
            "-U","register%{0}".format(passwd),"-v",
            printer['name']
          ])
   if ret.returncode != 0:
        time.sleep(3)
        subprocess.run(["/usr/sbin/cupsaddsmb",
            "-H",printserver,
            "-U","register%{0}".format(passwd),"-v",
            printer['name']
        ])

elif printer['action'] == 'enable':
    config = configparser.ConfigParser(delimiters=('='), strict=False)
    config.read(config_file)
    allowed_rooms = config.get(printer['name'],'hosts allow').split()
    if printer['network'] not in allowed_rooms:
        allowed_rooms.append(printer['network'])
        config.set(printer['name'],'hosts allow'," ".join(allowed_rooms))
        with open(config_file,'wt') as f:
            config.write(f)
        subprocess.run(['/usr/bin/systemctl','restart','samba-printserver'])

elif printer['action'] == 'disable':
    config = configparser.ConfigParser(delimiters=('='), strict=False)
    config.read(config_file)
    allowed_rooms = config.get(printer['name'],'hosts allow').split()
    if printer['network'] in allowed_rooms:
        allowed_rooms.remove(printer['network'])
        config.set(printer['name'],'hosts allow'," ".join(allowed_rooms))
        with open(config_file,'wt') as f:
            config.write(f)
        subprocess.run(['/usr/bin/systemctl','restart','samba-printserver'])
