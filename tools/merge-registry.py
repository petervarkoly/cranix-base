#!/usr/bin/python3
import configparser
import os

#{
#key(56) = "HKLM\5CSOFTWARE\5CMICROSOFT\5CWINDOWS\5CCURRENTVERSION\5CPOLICIES\00"
#data(4) = "\00\00\00\00"
#}

#Add printserver settings to admins smb.conf
config = configparser.ConfigParser(delimiters=('='))
config.read('/etc/samba/smb.conf')
config.set('global','printing','CUPS')
config.set('global','rpc_server:spoolss','external')
config.set('global','rpc_daemon:spoolssd','fork')
config.add_section('print$')
config.set('print$','browseable','yes')
config.set('print$','comment','Printer Drivers')
config.set('print$','create mask','0664')
config.set('print$','directory mask','0775')
config.set('print$','force group','SYSADMINS')
config.set('print$','guest ok','no')
config.set('print$','path','/var/lib/samba/drivers')
config.set('print$','printable','no')
config.set('print$','write list','@SYSADMINS root')
config.set('print$','read only','no')
config.add_section('printers')
config.set('printers','browseable','yes')
config.set('printers','comment','All Printers')
config.set('printers','create mask','0600')
config.set('printers','path','/var/tmp')
config.set('printers','printable','yes')
with open('/etc/samba/smb.conf','wt') as f:
    config.write(f)

#Merge the registries
registry={}
key=""
for line in os.popen("tdbdump /var/lib/samba/registry.tdb").readlines():
    if line.startswith("key"):
        key=line.split(" = ")[1].rstrip()
        registry[key] = {}
        registry[key]['key']  = line.split(" = ")[0]
    if key != "" and line.startswith('data'):
        registry[key]['data'] = line.split(" = ")[1].rstrip()
        registry[key]['datakey'] = line.split(" = ")[0]
        key=""

#print(registry)

pregistry={}
key=""
for line in os.popen("tdbdump /var/lib/printserver/registry.tdb").readlines():
    if line.startswith("key"):
        key=line.split(" = ")[1].rstrip()
        pregistry[key] = {}
        pregistry[key]['key']  = line.split(" = ")[0]
    if key != "" and line.startswith('data'):
        pregistry[key]['data'] = line.split(" = ")[1].rstrip()
        pregistry[key]['datakey'] = line.split(" = ")[0]
        key=""
#print(pregistry)

for key in pregistry:
    if key not in registry:
        print('{')
        print(pregistry[key]['key'],' = ',key)
        print(pregistry[key]['datakey'],' = ',pregistry[key]['data'])
        print('}')
    else:
        print('{')
        print(registry[key]['key'],' = ',key)
        print(registry[key]['datakey'],' = ',registry[key]['data'])
        print('}')

