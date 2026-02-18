#!/usr/bin/python3
import glob
import configparser
import json
import os
import os.path
import re
import sys
import cranixconfig
import time
from configobj import ConfigObj

#Declare variables
samba_config_file='/etc/samba/smb.conf'
files_config_file='/etc/samba/smb-fileserver.conf'

files_config_global = """
[global]
workgroup = {0}
realm = {1}
netbios name = fileserver
security = ADS
bind interfaces only = yes
interfaces = {2}
pid   directory = /run/sambafileserver
ncalrpc dir = /run/sambafileserver/ncalrpc
cache directory = /var/lib/fileserver
lock  directory = /var/lib/fileserver/lock
state directory = /var/lib/fileserver
private directory = /var/lib/fileserver/private
wide links = Yes
unix extensions = No
min domain uid = 0
#disable printing
load printers = no
printcap name = /dev/null
disable spoolss = yes
"""

modify_ldif = """{0}
changetype: modify
replace: profilePath
profilePath: \\\\fileserver\\profiles\\{1}
-
replace: homeDirectory
homeDirectory: \\\\fileserver\\{1}
"""

#Get password of user register
api_config  = ConfigObj("/opt/cranix-java/conf/cranix-api.properties")
register_pw = api_config['de.cranix.dao.User.Register.Password']

#Create backup directory
backup_dir = '/var/adm/cranix/backup/{0}'.format(os.popen('/usr/share/cranix/tools/crx_date.sh').read()).strip()
os.system('mkdir -p {0}'.format(backup_dir))
os.system('cp {0} {1}'.format(samba_config_file,backup_dir))
modify_ldif_file = "{0}/modify_ldif_fileserver-{1}.ldif"

#Get internal device
device_files = os.popen('grep -l {0} /etc/sysconfig/network/ifcfg-*'.format(cranixconfig.CRANIX_SERVER)).readlines()
if len(device_files) > 1:
    print("Can not determine internal device")
    print("There is more then one device configuration with the server ip address")
    print(device_files)
    sys.exit(1)
device_file=device_files[0].strip()
device=""
match = re.search("ifcfg-(.*)",device_file)
if match:
    device = match.group(1)
else:
    print("Can not determine internal device")
    sys.exit(1)
os.system('cp {0} {1}'.format(device_file,backup_dir))

#Get and setup new IP-Address
next_ip = os.popen('echo  "select IP from Devices where name=\'fileserver\'"  | mariadb CRX | tail -n1').read().strip()
if not next_ip:
    next_ip_json = json.load(os.popen('/usr/sbin/crx_api.sh GET rooms/1/availableIPAddresses'))
    next_ip      = next_ip_json[0]
    os.system("echo \"INSERT INTO Devices VALUES(NULL,1,1,NULL,'fileserver','{0}',NULL,'','',0,0,'','','',0);\" | mariadb CRX".format(next_ip))
    os.system('/usr/bin/systemctl restart cranix-api.service')

print('Activate the new IP-Address')
print('ip addr add {0}/{1} dev {2}'.format( next_ip,cranixconfig.CRANIX_NETMASK,device ))
os.system('ip addr add {0}/{1} dev {2}'.format( next_ip,cranixconfig.CRANIX_NETMASK,device ))

print('Write new IP-Address int device config file if not already there')
print("grep '{0}/{1}' {2}".format(next_ip,cranixconfig.CRANIX_NETMASK,device_file))
if not os.popen("grep '{0}/{1}' {2}".format(next_ip,cranixconfig.CRANIX_NETMASK,device_file)).read().strip():
    with open(device_file,'a') as f:
        f.write("IPADDR_files='{0}/{1}'\nLABEL_files='files'\n".format(next_ip,cranixconfig.CRANIX_NETMASK))

print('Create new dns entry')
print('/usr/sbin/crx_add_host.sh {0} {1}'.format('fileserver',next_ip))
os.system('/usr/sbin/crx_add_host.sh {0} {1}'.format('fileserver',next_ip))

#Remove with spaces from the keys.
os.system("sed -i -E 's/^[[:space:]]+//g' {0}".format(samba_config_file))
config = configparser.ConfigParser(delimiters=('='), interpolation=None, strict=False)
config.read(samba_config_file)
filesc = configparser.ConfigParser(delimiters=('='), interpolation=None, strict=False)
if os.path.exists(files_config_file):
    filesc.read(files_config_file)
else:
    print('Create new configuration')
    filesc.read_string(files_config_global.format(
        config.get("global","workgroup"),
        config.get("global","realm"),
        next_ip))

print("Take over all non printable sections except of 'global','sysvol','netlogon' and remove all printable sections in the original configuration.")
for section in config.sections():
    if section in ('global','sysvol','netlogon'):
        continue
    printable=config.get(section,'printable', fallback="no").lower()
    if printable == "yes" or printable == "on":
        config.remove_section(section)
        continue
    filesc.add_section(section)
    for option in config.options(section):
        filesc.set(section,option,config.get(section,option))
    config.remove_section(section)

print('Write the new configuration files')
with open(samba_config_file,'w') as f:
    config.write(f)
with open(files_config_file,'w') as f:
    filesc.write(f)

print('Now the new server is joining the domain')
os.system('/usr/bin/systemctl restart samba-ad')
time.sleep(3)
os.system('mkdir -p /var/log/samba/fileserver/')
os.system('mkdir -p /var/lib/fileserver/{drivers,lock,printing,private}')
os.system('net ADS JOIN -s {0} -U register%{1}'.format(files_config_file,register_pw))
os.system('/usr/bin/systemctl enable samba-fileserver')
os.system('/usr/bin/systemctl start samba-fileserver')

print('Adapt the login templates')
for i in glob.glob('/usr/share/cranix/templates/login*bat'):
    os.system("sed -i 's#\\\\admin\\\\#\\\\fileserver\\\\#g' {0}".format(i))
os.system("sed -i 's#\\\\admin\\\\#\\\\fileserver\\\\#g' /usr/share/cranix/templates/copy_and_run_rem_printers")

print('Adapt the accounts')
for line in os.popen('ldbsearch -H /var/lib/samba/private/sam.ldb  profilePath=* dn').readlines():
    if line.startswith('dn: '):
        match = re.search("CN=([^,]*),",line)
        if match:
            user = match.group(1)
            print("Proceeding user: {0}".format(user))
            with open(modify_ldif_file.format(backup_dir,user),'w') as f:
                f.write(modify_ldif.format(line.strip(),user))
            os.system('ldbmodify  -H /var/lib/samba/private/sam.ldb {0}'.format(modify_ldif_file.format(backup_dir,user)))

print('Adapt new cranix config file')
crx_config  = ConfigObj("/etc/sysconfig/cranix",list_values=False,encoding='utf-8',unrepr=True)
crx_config['CRANIX_FILESERVER'] = next_ip
crx_config['CRANIX_FILESERVER_NETBIOSNAME'] = 'fileserver'
crx_config.write()

