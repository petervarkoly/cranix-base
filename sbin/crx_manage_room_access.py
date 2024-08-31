#!/usr/bin/python3
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.

import configparser
import json
import os
import re
import sys
import cranixconfig
import inspect
from datetime import datetime
from argparse import ArgumentParser

#Parse arguments
parser = ArgumentParser()
parser.add_argument("--id",            help="The room id.")
parser.add_argument("--all",           action="store_true", help="Get or set the values of all rooms.")
parser.add_argument("--get",           action="store_true", help="Gets the actuall access in a room.")
parser.add_argument("--deny_printing", action="store_true", help="Allow the printing access in a room.")
parser.add_argument("--deny_login",    action="store_true", help="Allow the login access in a room.")
parser.add_argument("--deny_portal",   action="store_true", help="Allow the portal access in a room.")
parser.add_argument("--deny_direct",   action="store_true", help="Allow the direct internet access in a room.")
parser.add_argument("--let_direct",    action="store_true", help="Do not change the direct internet setting.")
parser.add_argument("--deny_proxy",    action="store_true", help="Allow the proxy access in a room.")
parser.add_argument("--set_defaults",  action="store_true", help="Set the default access state in the room(s).")
args = parser.parse_args()

#Read CRANIX-Firewall
CRANIX_FW_CONFIG="/etc/cranix-firewall.conf"
config = json.load(open(CRANIX_FW_CONFIG))

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
rooms   = {}
default_access = {}
ext_dev = config['devices']['external']
int_dev = config['devices']['internal']
server_net = cranixconfig.CRANIX_SERVER_NET
proxy  = cranixconfig.CRANIX_PROXY
portal = cranixconfig.CRANIX_MAILSERVER
debug  = cranixconfig.CRANIX_DEBUG == "yes"
ext_ip = cranixconfig.CRANIX_SERVER_EXT_IP
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
            log.write('DEBUG {0} Caller: {1} {2}\n'.format(datetime.now().strftime("%Y-%m-%d %H:%M:%S"),inspect.stack()[1][3],msg))

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

def is_printing_allowed(room):
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

def enable_printing(room):
    global printc, printc_changed
    for printer in room['printers']:
        if not printc.has_section(printer):
            log_error('There is no section for printer {} in smb.conf'.format(printer))
            continue
        allowed_nets = get_allowed_nets(printer)
        if room['network'] not in allowed_nets:
            allowed_nets.append(room['network'])
            printc.set(printer,'hosts allow'," ".join(allowed_nets))
            printc_changed = True

def disable_printing(room):
    global printc, printc_changed
    for printer in room['printers']:
        allowed_nets = get_allowed_nets(printer)
        if room['network'] in allowed_nets:
            allowed_nets.remove(room['network'])
            printc.set(printer,'hosts allow'," ".join(allowed_nets))
            printc_changed = True

def set_state(room):
    global allow_printing, allow_login, allow_portal, allow_direct, allow_proxy
    global args, login_denied_rooms, rooms
    global proxy, portal, smb_reload, printc_changed
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
        enable_printing(room)
    else:
        disable_printing(room)

    if allow_login:
        if network in login_denied_rooms:
            smb_reload = True
            login_denied_rooms.remove(network)
    elif network not in login_denied_rooms:
        smb_reload = True
        login_denied_rooms.append(network)

    if allow_portal and not room['portal']:
        while os.system(f"/usr/sbin/iptables -D INPUT -s {network} -d {portal} -j DROP &> /dev/null") == 0:
            pass
        log_debug(f"/usr/sbin/iptables -D INPUT -s {network} -d {portal} -j DROP")
    if not allow_portal and room['portal']:
        os.system(f"/usr/sbin/iptables -I INPUT -s {network} -d {portal} -j DROP &> /dev/null")
        log_debug(f"/usr/sbin/iptables -I INPUT -s {network} -d {portal} -j DROP")

    if allow_proxy and not room['proxy']:
        while os.system(f"/usr/sbin/iptables -D INPUT -s {network} -d {proxy} -j DROP &> /dev/null") == 0:
            pass
        log_debug(f"/usr/sbin/iptables -D INPUT -s {network} -d {proxy} -j DROP")
    if not allow_proxy and room['proxy']:
        os.system(f"/usr/sbin/iptables -I INPUT -s {network} -d {proxy} -j DROP &> /dev/null")
        log_debug(f"/usr/sbin/iptables -I INPUT -s {network} -d {proxy} -j DROP")
    log_debug(room)
    if not args.let_direct:
        mask_address=network
        if no_masquerade != "":
            mask_address=f"{network} ! -d {no_masquerade}"
        if allow_direct and not room['direct']:
            os.system(f"/usr/sbin/iptables -t nat -I POSTROUTING -s {network} -o {ext_dev} -j SNAT --to-source {ext_ip} &> /dev/null")
            log_debug(f"/usr/sbin/iptables -t nat -I POSTROUTING -s {network} -o {ext_dev} -j SNAT --to-source {ext_ip}")
            os.system(f"/usr/sbin/iptables -I FORWARD -s {network} -o {ext_dev} -j ACCEPT &> /dev/null")
            log_debug(f"/usr/sbin/iptables -I FORWARD -s {network} -o {ext_dev} -j ACCEPT")

        if not allow_direct and  room['direct']:
            while os.system(f"/usr/sbin/iptables -t nat -D POSTROUTING -s {network} -o {ext_dev} -j SNAT --to-source {ext_ip} &> /dev/null") == 0:
                pass
            log_debug(f"/usr/sbin/iptables -t nat -D POSTROUTING -s {network} -o {ext_dev} -j SNAT --to-source {ext_ip}")
            while os.system(f"/usr/sbin/iptables -D FORWARD -s {network} -o {ext_dev} -j ACCEPT &> /dev/null") == 0:
                pass
            log_debug(f"/usr/sbin/iptables -D FORWARD -s {network} -o {ext_dev} -j ACCEPT &> /dev/null")

def get_state(room):
    global login_denied_rooms
    return {
        'accessType': 'FW',
        'roomId':    room['id'],
        'roomName':  room['name'],
        'login':     room['network'] not in login_denied_rooms,
        'printing':  is_printing_allowed(room) and ( room['network'] not in login_denied_rooms ),
        'proxy':     room['proxy'],
        'portal':    room['portal'],
        'direct':    room['direct']
    }

def prepare_room(room):
    room['name'] = room['name'].strip()[0:17].encode("ascii","ignore").decode("ascii","ignore")
    room['network']='{0}/{1}'.format(room['startIP'],room['netMask'])
    room['printers'] = []
    if room['defaultPrinter']:
        room['printers'].append(room['defaultPrinter']['name'])
    for printer in room['availablePrinters']:
        room['printers'].append(printer['name'])
    room['direct'] = False
    room['login']  = True
    room['portal'] = True
    room['printing'] = True
    room['proxy'] = True
    return room

def read_data():
    config.read('/etc/samba/smb.conf')
    printc.read(print_config_file)

    if 'hosts deny' in config['global']:
        login_denied_rooms    = config.get('global','hosts deny').split()

    if args.id:
        room = json.load(os.popen('/usr/sbin/crx_api.sh GET rooms/{0}'.format(args.id)))
        if 'roomControl' in room and room['roomControl'] == 'no':
            print("This room '{0}' can not be dynamical controlled".format(room['name']))
            sys.exit(-1)
        if 'startIP' in room:
            tmp = prepare_room(room)
            rooms[f"{room['startIP']}/{room['netMask']}"] = tmp
        else:
            print("Can not find the room with id {0}".format(args.id))
            sys.exit(-2)
    elif args.all:
        for room in json.load(os.popen('/usr/sbin/crx_api.sh GET rooms/allWithControl')):
            tmp = prepare_room(room)
            rooms[f"{room['startIP']}/{room['netMask']}"] = tmp
    else:
        print("You have to define a room")
        sys.exit(-1)
    for line in os.popen("/usr/sbin/iptables  -nL -t nat").readlines():
        tmp = line.split()
        if len(tmp) > 0 and ((tmp[0] == "SNAT" or tmp[0] == "MASQUERADE") and tmp[3] in rooms):
            rooms[tmp[3]]['direct'] = True
    log_debug(rooms)
#main
read_data()
# Now we can send the state if this was the question

if args.get:
    if args.all:
        status = []
        for roomNetwork, room in rooms.items():
            if room['roomControl'] == 'no' or 'startIP' not in room:
                continue
            status.append(get_state(room))
        print(json.dumps(status))
    else:
        for roomNetwork, room in rooms.items():
            print(json.dumps(get_state(room)))
else:
    if args.all:
        status = []
        for access in json.load(os.popen('/usr/sbin/crx_api.sh GET rooms/accessList')):
            if access['accessType'] == 'DEF':
                default_access[access['roomId']] = access
        for roomNetwork, room in rooms.items():
            if room['roomControl'] == 'no' or 'startIP' not in room:
                continue
            set_state(prepare_room(room))
    else:
        for roomNetwork, room in rooms.items():
            default_access[room['id']] = json.load(os.popen('/usr/sbin/crx_api.sh GET rooms/{0}/defaultAccess'.format(room['id'])))
            set_state(room)

    if smb_reload:
        if len(login_denied_rooms) == 0:
            config.remove_option('global','hosts deny')
        else:
            config.set('global','hosts deny'," ".join(login_denied_rooms))
        with open('/etc/samba/smb.conf','wt') as f:
            config.write(f)
        os.system("/usr/bin/systemctl reload samba-ad.service &> /dev/null")
    if printc_changed:
        with open(print_config_file,'wt') as f:
            printc.write(f)

