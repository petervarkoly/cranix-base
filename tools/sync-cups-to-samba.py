#!/usr/bin/python3
#
# Copyright (c) Peter Varkoly <peter@varkoly.de> Nuremberg, Germany.  All rights reserved.
#
import configparser
import os
import sys
import re
import json
import cranixconfig
from configobj import ConfigObj

try:
    print_config_file = cranixconfig.CRANIX_PRINTSERVER_CONFIG
except AttributeError:
    print_config_file = "/etc/samba/smb-printserver.conf"

server_net = cranixconfig.CRANIX_SERVER_NET
config = ConfigObj("/opt/cranix-java/conf/cranix-api.properties")
passwd = config['de.cranix.dao.User.Register.Password']

os.system('chgrp -R "SYSADMINS" /var/lib/printserver/drivers')
os.system('chmod -R 2775 /var/lib/printserver/drivers')
os.system('net rpc rights grant "BUILTIN\Administrators" SePrintOperatorPrivilege -U "register%{0}"'.format(passwd))
os.system('net rpc rights grant "SYSADMINS" SePrintOperatorPrivilege -U "register%{0}"'.format(passwd))
config = configparser.ConfigParser(delimiters=('='), strict=False)
config.read(print_config_file)

config.set('global','printing','CUPS')
config.set('global','load printers','no')
config.set('global','min domain uid','0')
config.set('global','rpc_server:spoolss','external')
config.set('global','rpc_daemon:spoolssd','fork')

if 'printers' in config:
    config.remove_section('printers')
if 'print$' in config:
    config.remove_section('print$')
config.add_section('print$')
config.set('print$','comment','Printer Drivers')
config.set('print$','path','/var/lib/printserver/drivers')
config.set('print$','read only','No')

#Remove all printer sections
for section in config.sections():
    printable=config.get(section,'printable', fallback="no").lower()
    if printable == "yes" or printable == "on":
        config.remove_section(section)

#Add printer sections
for line in os.popen('LANG=en_EN lpc status').readlines():
    match = re.search("([\-\w]+):", line)
    if match:
        name =  match.group(1)
        if not name in config:
            config.add_section(name)
        config.set(name,'path','/var/tmp/')
        config.set(name,'printable','yes')
        config.set(name,'printer name',name)
        if 'hosts allow' not in config[name]:
            config.set(name,'hosts allow',server_net)

with open(print_config_file,'wt') as f:
    config.write(f)

