#!/usr/bin/python3
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.

import configparser
import json
import os
import re
import sys
import cranixconfig
from datetime import datetime
from argparse import ArgumentParser

#Parse arguments
parser = ArgumentParser()
parser.add_argument("--id",   dest="id",   default="", help="The room id.")
parser.add_argument("--all",  dest="all",  default=False, action="store_true", help="Get or set the values of all rooms.")
parser.add_argument("--get", dest="get", default=False, action="store_true",
                    help="Gets the actuall access in a room.")
parser.add_argument("--deny_printing",  dest="deny_printing",   default=False, action="store_true",
                    help="Allow the printing access in a room.")
parser.add_argument("--deny_login",  dest="deny_login",   default=False, action="store_true",
                    help="Allow the login access in a room.")
parser.add_argument("--deny_portal",  dest="deny_portal",   default=False, action="store_true",
                    help="Allow the portal access in a room.")
parser.add_argument("--deny_direct",  dest="deny_direct",   default=False, action="store_true",
                    help="Allow the direct internet access in a room.")
parser.add_argument("--let_direct",  dest="let_direct",   default=False, action="store_true",
                    help="Do not change the direct internet setting.")
parser.add_argument("--deny_proxy",  dest="deny_proxy",   default=False, action="store_true",
                    help="Allow the proxy access in a room.")
parser.add_argument("--set_defaults",  dest="set_defaults",   default=False, action="store_true",
                    help="Set the default access state in the room(s).")
parser.set_defaults(allow=True)
args = parser.parse_args()

#Global variables
if args.deny_login:
    args.deny_printing = True
allow_printing = not args.deny_printing
allow_login    = not args.deny_login
allow_portal   = not args.deny_portal
allow_direct   = not args.deny_direct
allow_proxy    = not args.deny_proxy
login_denied_rooms   =[]
room    = {}
rooms   = []
zones   = {}
default_access = {}
server_net = cranixconfig.CRANIX_SERVER_NET
proxy  = cranixconfig.CRANIX_PROXY
portal = cranixconfig.CRANIX_MAILSERVER
debug  = cranixconfig.CRANIX_DEBUG == "yes"
config = configparser.ConfigParser(delimiters=('='), strict=False)
printc = configparser.ConfigParser(delimiters=('='), strict=False)
printc_changed = False #Rewrite of samba is required
smb_reload  = False #Reload of samba is required
debug_file  = '/var/log/cranix-manage-room.log'
try:
    print_config_file = cranixconfig.CRANIX_PRINTSERVER_CONFIG
except AttributeError:
    print_config_file = "/etc/samba/smb-printserver.conf"
try:
    no_masquerade = cranixconfig.CRANIX_NO_MASQUERADE_NET
except AttributeError:
    no_masquerade = ""


def log_debug(msg):
    global debug
    if debug:
        with open(debug_file,"a") as log:
            log.write('DEBUG {0} {1}\n'.format(datetime.now().strftime("%Y-%m-%d %H:%M:%S"),msg))

def log_error(msg):
    with open(debug_file,"a") as log:
        log.write('ERROR {0} {1}\n'.format(datetime.now().strftime("%Y-%m-%d %H:%M:%S"),msg))

def is_printer_allowed(printer,network):
    global printc
    if printer in printc:
        if 'hosts allow' in printc[printer]:
            return network in printc.get(printer,'hosts allow').split()
        else:
            return True
    else:
        return False

def is_printing_allowed():
    global room
    for printer in room['printers']:
        if is_printer_allowed(printer,room['network']):
            return True
    return False

def get_allowed_nets(printer):
    allowed_nets = []
    if 'hosts allow' in printc[printer]:
        allowed_nets = printc.get(printer,'hosts allow').split()
    if server_net not in allowed_nets:
        allowed_nets.append(server_net)
    return allowed_nets

def enable_printing():
    global room, printc, printc_changed
    for printer in room['printers']:
        if not printc.has_section(printer):
            log_error('There is no section for printer {} in smb.conf'.format(printer))
            continue
        allowed_nets = get_allowed_nets(printer)
        if room['network'] not in allowed_nets:
            allowed_nets.append(room['network'])
            printc.set(printer,'hosts allow'," ".join(allowed_nets))
            printc_changed = True

def disable_printing():
    global room, printc, printc_changed
    for printer in room['printers']:
        allowed_nets = get_allowed_nets(printer)
        if room['network'] in allowed_nets:
            allowed_nets.remove(room['network'])
            printc.set(printer,'hosts allow'," ".join(allowed_nets))
            printc_changed = True

def set_state():
    global allow_printing, allow_login, allow_portal, allow_direct, allow_proxy
    global args, login_denied_rooms, rooms, zones, room
    global proxy, portal, smb_reload, printc_changed
    try:
        name    = room['name']
        network = room['network']
        if args.set_defaults:
            access = default_access[room['id']]
            log_debug(access)
            if 'printing' in access:
                allow_printing = access['printing']
                allow_login    = access['login']
                allow_portal   = access['portal']
                allow_proxy    = access['proxy']
                allow_direct   = access['direct']
            else:
                log_debug("No default access for room {0}".format(name))
                return

        if allow_printing:
            enable_printing()
        else:
            disable_printing()

        if allow_login:
            if network in login_denied_rooms:
                smb_reload = True
                login_denied_rooms.remove(network)
        elif network not in login_denied_rooms:
            smb_reload = True
            login_denied_rooms.append(network)

        if name in zones and 'rule' in zones[name]:
          if allow_portal and portal in zones[name]['rule']:
              #fw_changed = True
              os.system('/usr/bin/firewall-cmd --zone={0} --remove-rich-rule="rule family=ipv4 destination address={1} drop" &>/dev/null'.format(name,portal))
              log_debug('/usr/bin/firewall-cmd --zone={0} --remove-rich-rule="rule family=ipv4 destination address={1} drop" &>/dev/null'.format(name,portal))
          if not allow_portal and portal not in zones[name]['rule']:
              #fw_changed = True
              os.system('/usr/bin/firewall-cmd --zone={0} --add-rich-rule="rule family=ipv4 destination address={1} drop" &>/dev/null'.format(name,portal))
              log_debug('/usr/bin/firewall-cmd --zone={0} --add-rich-rule="rule family=ipv4 destination address={1} drop" &>/dev/null'.format(name,portal))

          if allow_proxy and proxy in zones[name]['rule']:
              #fw_changed = True
              os.system('/usr/bin/firewall-cmd --zone={0} --remove-rich-rule="rule family=ipv4 destination address={1} drop" &>/dev/null'.format(name,proxy))
              log_debug('/usr/bin/firewall-cmd --zone={0} --remove-rich-rule="rule family=ipv4 destination address={1} drop" &>/dev/null'.format(name,proxy))
          if not allow_proxy and proxy not in zones[name]['rule']:
              #fw_changed = True
              os.system('/usr/bin/firewall-cmd --zone={0} --add-rich-rule="rule family=ipv4 destination address={1} drop" &>/dev/null'.format(name,proxy))
              log_debug('/usr/bin/firewall-cmd --zone={0} --add-rich-rule="rule family=ipv4 destination address={1} drop" &>/dev/null'.format(name,proxy))

        if not args.let_direct:
            mask_address=network
            if no_masquerade != "":
                mask_address="{0} destination NOT address={1}".format(network,no_masquerade)
            if allow_direct and network not in zones['external']['rule']:
                #fw_changed = True
                for rule in zones[key]['richRules']:
                    os.system('/usr/bin/firewall-cmd --zone="external" --remove-rich-rule="{0}" &>/dev/null'.format(rule))
                os.system('/usr/bin/firewall-cmd --zone="external" --add-rich-rule="rule family=ipv4 source address={0} masquerade" &>/dev/null'.format(mask_address))
                log_debug('/usr/bin/firewall-cmd --zone="external" --add-rich-rule="rule family=ipv4 source address={0} masquerade" &>/dev/null'.format(mask_address))
            if not allow_direct and  network in zones['external']['rule']:
                #fw_changed = True
                os.system('/usr/bin/firewall-cmd --zone="external" --remove-rich-rule="rule family=ipv4 source address={0} masquerade" &>/dev/null'.format(mask_address))
                log_debug('/usr/bin/firewall-cmd --zone="external" --remove-rich-rule="rule family=ipv4 source address={0} masquerade" &>/dev/null'.format(mask_address))
    except KeyError:
        os.system('/usr/share/cranix/tools/sync-rooms-to-firewalld.py &>/dev/null')

def get_state():
    global login_denied_rooms, zones, room
    global proxy, portal
    try:
        return {
            'accessType': 'FW',
            'roomId':    room['id'],
            'roomName':  room['name'],
            'login':     room['network'] not in login_denied_rooms,
            'printing':  is_printing_allowed() and ( room['network'] not in login_denied_rooms ),
            'proxy':     proxy   not in zones[room['name']]['rule'],
            'portal':    portal  not in zones[room['name']]['rule'],
            'direct':    room['network'] in  zones['external']['rule']
        }
    except KeyError:
        os.system('/usr/share/cranix/tools/sync-rooms-to-firewalld.py &>/dev/null')
        return {
            'accessType': 'FW',
            'roomId':    0,
            'roomName':  'FWERROR',
            'login':     False,
            'printing':  False,
            'proxy':     False,
            'portal':    False,
            'direct':    False
        }

def prepare_room():
    global room
    room['name'] = room['name'].strip()[0:17].encode("ascii","ignore").decode("ascii","ignore")
    room['network']='{0}/{1}'.format(room['startIP'],room['netMask'])
    room['printers'] = []
    if room['defaultPrinter']:
        room['printers'].append(room['defaultPrinter']['name'])
    for printer in room['availablePrinters']:
        room['printers'].append(printer['name'])

#Start collecting datas
config.read('/etc/samba/smb.conf')
printc.read(print_config_file)

if 'hosts deny' in config['global']:
    login_denied_rooms    = config.get('global','hosts deny').split()

if args.id != "":
    room = json.load(os.popen('/usr/sbin/crx_api.sh GET rooms/{0}'.format(args.id)))
    if room['roomControl'] == 'no':
        print("This room '{0}' can not be dynamical controlled".format(room['name']))
        sys.exit(-1)
    if 'startIP' in room:
        prepare_room()
    else:
        print("Can not find the room with id {0}".format(args.id))
        sys.exit(-2)
elif args.all:
    rooms = json.load(os.popen('/usr/sbin/crx_api.sh GET rooms/allWithControl'))
else:
    print("You have to define a room")
    sys.exit(-1)

rule = False
for line in os.popen('/usr/bin/firewall-cmd --list-all-zones').readlines():
    match1 = re.search("^(\S+)",line)
    match2 = re.search("\s+rich rules:",line)
    match3 = re.search("\s+(\S+): (\S+)",line)
    if match1:
        key = match1.group(1)
        zones[key] = {}
        zones[key]['rule'] = []
        zones[key]['richRules'] = []
        rule = False
    elif match2:
        rule = True
    elif match3:
        zones[key][match3.group(1)] = match3.group(2)
    elif rule:
        match4 = re.search('(rule.*destination address=.*)',line)
        if match4:
            zones[key]['richRules'].append(match4.group(1))
        match4 = re.search('address="([0-9\./]+)"',line)
        if match4:
            zones[key]['rule'].append(match4.group(1))

# Now we can send the state if this was the question
if args.get:
    if args.all:
        status = []
        for room in rooms:
            if room['roomControl'] == 'no' or 'startIP' not in room:
                continue
            prepare_room()
            status.append(get_state())
        print(json.dumps(status))
    else:
        print(json.dumps(get_state()))
else:
    if args.all:
        status = []
        for access in json.load(os.popen('/usr/sbin/crx_api.sh GET rooms/accessList')):
            if access['accessType'] == 'DEF':
                default_access[access['roomId']] = access
        for room in rooms:
            if room['roomControl'] == 'no' or 'startIP' not in room:
                continue
            prepare_room()
            set_state()
    else:
        default_access[room['id']] = json.load(os.popen('/usr/sbin/crx_api.sh GET rooms/{0}/defaultAccess'.format(room['id'])))
        set_state()

    if smb_reload:
        if len(login_denied_rooms) == 0:
            config.remove_option('global','hosts deny')
        else:
            config.set('global','hosts deny'," ".join(login_denied_rooms))
        with open('/etc/samba/smb.conf','wt') as f:
            config.write(f)
        os.system("/usr/bin/systemctl reload samba-ad.service")
    if printc_changed:
        with open(print_config_file,'wt') as f:
            printc.write(f)

