#!/usr/bin/python3

import os

#{
#key(56) = "HKLM\5CSOFTWARE\5CMICROSOFT\5CWINDOWS\5CCURRENTVERSION\5CPOLICIES\00"
#data(4) = "\00\00\00\00"
#}

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

