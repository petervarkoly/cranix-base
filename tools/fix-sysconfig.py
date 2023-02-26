#!/usr/bin/python3

import os
import os.path
from configobj import ConfigObj

# new services to add
new_services = (
        'chronyd',
        'samba-ad',
        'samba-fileserver',
        'samba-printserver',
        'cranix-api',
        'crx_salt_event_watcher'
        )
# old services to remove
old_services = (
        'ntpd',
        'samba',
        'oss-api',
        'oss_salt_event_watcher'
        )

#Create backup directory
backup_dir = '/var/adm/cranix/backup/{0}'.format(os.popen('/usr/share/cranix/tools/crx_date.sh').read()).strip()
os.system('mkdir -p {0}'.format(backup_dir))
os.system('cp {0} {1}'.format('/etc/sysconfig/cranix',backup_dir))

if os.path.exists("/usr/share/cranix/templates/radius/RADIUS-SETTINGS"):
    os.system('/usr/bin/fillup /usr/share/fillup-templates/sysconfig.cranix /usr/share/cranix/templates/radius/RADIUS-SETTINGS /usr/share/fillup-templates/sysconfig.cranix')

fillup_template = ConfigObj('/usr/share/fillup-templates/sysconfig.cranix',list_values=False,encoding='utf-8')
cranix_conf = ConfigObj('/etc/sysconfig/cranix',list_values=False,encoding='utf-8')

for key in fillup_template:
    if key in cranix_conf:
        fillup_template[key] = cranix_conf[key]
services=cranix_conf['CRANIX_MONITOR_SERVICES'].strip('"').strip("'").split()
for i in old_services:
    if i in services:
        services.remove(i)
for i in new_services:
    if i not in services:
        services.append(i)
services.sort()
fillup_template['CRANIX_MONITOR_SERVICES']="'" + ' '.join(services) + "'"

if 'CRANIX_FILESERVER_NETBIOSNAME' in cranix_conf and ( cranix_conf['CRANIX_FILESERVER_NETBIOSNAME'] == '' or  cranix_conf['CRANIX_FILESERVER_NETBIOSNAME'] == '""' ):
    fillup_template['CRANIX_FILESERVER'] = ""

fillup_template.filename = '/etc/sysconfig/cranix'
fillup_template.write()

