#!/usr/bin/python3
#
# Copyright (c) Peter Varkoly <peter@varkoly.de> Nuremberg, Germany.  All rights reserved.
#
import ipaddress
import json
import os
import re
import subprocess
import sys
import cranixconfig

# Nur das Format AA:BB:CC:DD:EE:FF (groß-/klein/universal)
_mac_regex = re.compile(r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$')

kea_config_file = "/etc/kea/kea-dhcp4.conf"
name = ""
roomname = ""
dev_id = ""
ip = ""
mac = ""
wlanip = ""
wlanmac = ""
net_id = 1

#Some helper functions
def is_valid_ipv4(addr: str) -> bool:
    try:
        ip = ipaddress.IPv4Address(addr)
        return True
    except ipaddress.AddressValueError:
        return False
def is_valid_mac_macaddress(addr: str) -> bool:
    return bool(_mac_regex.fullmatch(addr))

def ip_in_network(ip: str, network: str) -> bool:
    ip_addr = ipaddress.ip_address(ip)
    net = ipaddress.ip_network(network, strict=False)  # strict=False erlaubt Hosts, Netzadresse oder Broadcast
    return ip_addr in net

#Read parameters from input
for line in sys.stdin:
    kv  = line.rstrip().split(": ",1)
    key = kv[0].lower()
    if key == "id":
        dev_id = kv[1]
    elif key == "ip":
        ip = kv[1]
    elif key == "name":
        name = kv[1]
    elif key == "mac":
        mac = kv[1]
    elif key == "roomname":
        roomname = kv[1]
    elif key == "wlanip":
        wlanip = kv[1]
    elif key == "wlanmac":
        wlanmac = kv[1]

#Read kea config file
with open(kea_config_file) as tmp:
    kea_config = json.load(tmp)

#Find the network id
for net in kea_config["Dhcp4"]["subnet4"]:
    if ip_in_network(ip, net["subnet"]):
        net_id = net["id"]
        break

dhcp_command = {
    "command": "reservation-update",
    "arguments": {
        "reservation": {
            "subnet-id": net_id,
            "hw-address": mac,
            "ip-address": ip,
            "hostname": f"{name}.{cranixconfig.CRANIX_DOMAIN}",
            "client-classes": [roomname]
        }
     }
}

result = subprocess.run(
        ['/usr/bin/socat', 'UNIX:/run/kea/kea4-ctrl-socket', '-,ignoreeof'],
        input=json.dumps(dhcp_command),
        encoding='utf-8',
        check=True
    )
if result['result'] != 0:
    with open(f"/var/adm/cranix/opentasks/110-modify-device-in-dhcp-{dev_id}.json","w") as f:
        json.dump(dhcp_command, f, ensure_ascii=False, indent=4)

print(result.stdout)

if is_valid_ipv4(wlanip) and is_valid_mac_macaddress(wlanmac):
    dhcp_command["arguments"]["reservation"]["hw-address"] = wlanmac
    dhcp_command["arguments"]["reservation"]["ip-address"] = wlanip
    dhcp_command["arguments"]["reservation"]["hostname"] = f"{name}-wlan.{cranixconfig.CRANIX_DOMAIN}"
    result = subprocess.run(
            ['/usr/bin/socat', 'UNIX:/run/kea/kea4-ctrl-socket', '-,ignoreeof'],
            input=json.dumps(dhcp_command),
            encoding='utf-8',
            check=True
        )
    if result['result'] != 0:
        with open(f"/var/adm/cranix/opentasks/110-modify-device-in-dhcp-wlan-{dev_id}.json","w") as f:
            json.dump(dhcp_command, f, ensure_ascii=False, indent=4)
