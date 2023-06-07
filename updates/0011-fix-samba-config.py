#!/usr/bin/python3
import configparser
import os
import os.path

samba_config_file='/etc/samba/smb.conf'
files_config_file='/etc/samba/smb-fileserver.conf'
print_config_file='/etc/samba/smb-printserver.conf'

os.system("sed -i -E 's/^[[:space:]]+//g' {0}".format(samba_config_file))
config = configparser.ConfigParser(delimiters=('='), interpolation=None, strict=False)
config.read(samba_config_file)
config.set('global','load printers','no')
config.set('global','printcap name','/dev/null')
config.set('global','disable spoolss','yes')
with open(samba_config_file,'w') as f:
    config.write(f)
os.system('/usr/bin/systemctl restart samba-ad')

if os.path.exists(print_config_file):
    config = configparser.ConfigParser(delimiters=('='), interpolation=None, strict=False)
    config.read(print_config_file)
    config.set('global','ncalrpc dir','/run/sambaprintserver/ncalrpc')
    with open(print_config_file,'w') as f:
        config.write(f)
    os.system('/usr/bin/systemctl restart samba-printserver')

if os.path.exists(files_config_file):
    config = configparser.ConfigParser(delimiters=('='), interpolation=None, strict=False)
    config.read(files_config_file)
    config.set('global','ncalrpc dir','/run/sambafileserver/ncalrpc')
    config.set('global','load printers','no')
    config.set('global','printcap name','/dev/null')
    config.set('global','disable spoolss','yes')
    with open(files_config_file,'w') as f:
        config.write(f)
    os.system('/usr/bin/systemctl restart samba-fileserver')


