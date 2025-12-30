#!/usr/bin/python3.13

import cranixconfig
import json
import netifaces
import os
import subprocess
import time
from ipaddress import IPv4Interface

room_format = """
id: {0}
name: {1}
"""

device_format = """
id: {0}
name: {1}
ip: {2}
mac: {3}
nwlanip: {4}
wlanmac: {5}
roomname: {6}
"""

def netzwerk_zuordnen_netifaces():
    """Ermittelt die Netzwerke, zu denen jede Netzwerkschnittstelle gehört, mit netifaces."""

    ergebnisse = {}

    # 1. Liste aller Schnittstellennamen abrufen
    schnittstellen = netifaces.interfaces()
    for iface in schnittstellen:
        # 2. Adressen für die aktuelle Schnittstelle abrufen
        adressen = netifaces.ifaddresses(iface)
        # 3. Nur die Adressen der Familie AF_INET (IPv4) betrachten
        if iface.find(":") == -1 and netifaces.AF_INET in adressen:

            # Eine Schnittstelle kann mehrere IPv4-Adressen haben.
            for adr_info in adressen[netifaces.AF_INET]:
                # Wir benötigen 'addr' (IP) und 'netmask' (Subnetzmaske)
                ip_adresse = adr_info.get('addr')
                subnet_maske = adr_info.get('netmask')

                # Sicherstellen, dass beide Werte vorhanden sind
                if ip_adresse and subnet_maske:
                    try:
                        # IP und Maske im CIDR-Format zusammenfügen
                        cidr_notation = f"{ip_adresse}/{subnet_maske}"

                        # IPv4Interface-Objekt erstellen, das die Netzwerkadresse berechnet
                        interface_obj = IPv4Interface(cidr_notation)

                        # Netzwerkadresse im CIDR-Format extrahieren
                        netzwerk = str(interface_obj.network)

                        # Ergebnis speichern (ggf. mit Index, falls mehrere IPs pro NIC)
                        ergebnisse[netzwerk] = {}
                        ergebnisse[netzwerk]['dev'] = f"{iface}"
                        ergebnisse[netzwerk]['ip'] = f"{ip_adresse}"

                    except Exception as e:
                        # Fehlerbehandlung für ungültige IP/Masken
                        ergebnisse[f"{iface}"] = f"Fehler bei IPv4-Berechnung: {e}"

    return ergebnisse


network = f"{cranixconfig.CRANIX_NETWORK}/{cranixconfig.CRANIX_NETMASK}"
network_counter = 1
networks = {
    network: network_counter
}
network_counter = network_counter + 1
#Read all networks in system
try:
    for net in json.load(os.popen('crx_api.sh GET system/enumerates/network')):
        if not net in networks:
            networks[network] = network_counter
            network_counter = network_counter + 1
except Exception:
    pass

dhcp_devices = []
net_cards = netzwerk_zuordnen_netifaces()
print(net_cards)
for net in net_cards:
    if net in networks:
        dhcp_devices.append(net_cards[net]['dev'])

password = os.popen("mktemp -u XXXXXXXXXXX").read().strip()
kea_conf = {
    "Dhcp4": {
        "interfaces-config": {
            "interfaces": dhcp_devices
        },
        "control-socket": {
            "socket-type": "unix",
            "socket-name": "kea4-ctrl-socket"
        },
        "lease-database": {
            "type": "mysql",
            "name": "kea_dhcp4",
            "user": "keauser",
            "password": f"{password}",
            "host": "localhost",
            "port": 3306
        },
        "hosts-database": {
            "type": "mysql",
            "name": "kea_dhcp4",
            "user": "keauser",
            "password": f"{password}",
            "host": "localhost",
            "port": 3306
        },
        "client-classes": [
            {
                "name": "pxe-bios",
                "test": "option[vendor-class-identifier].text == 'PXEClient:Arch:00000:UNDI:002001'",
                "next-server": cranixconfig.CRANIX_SERVER,
                "boot-file-name": "pxelinux.0"
            },
            {
                "name": "known-devices-class",
                "test": "'a' == 'a'",
                "max-valid-lifetime": 172800,
                "valid-lifetime": 86400
            }
        ],
        "hooks-libraries": [ 
                { "library": "/usr/lib64/kea/hooks/libdhcp_mysql.so" },
                { "library": "/usr/lib64/kea/hooks/libdhcp_host_cmds.so" },
                { "library": "/usr/lib64/kea/hooks/libdhcp_class_cmds.so" }
        ],
        "option-data": [
                {
                   "name": "domain-name-servers",
                   "data": cranixconfig.CRANIX_SERVER
                },
                {
                   "name": "domain-name",
                   "data": cranixconfig.CRANIX_DOMAIN
                },
                {
                   "name": "domain-search",
                   "data": cranixconfig.CRANIX_DOMAIN
                },
                {
                   "name": "time-servers",
                   "data": cranixconfig.CRANIX_SERVER
                }
        ],
        "subnet4": []
    }
}

for net in networks:
    subnet = {
        "id": networks[net],
        "subnet": net,
        "valid-lifetime": 300,
        "max-valid-lifetime": 600,
        "next-server": net_cards[net]['ip'],
        "boot-file-name": "efi/bootx64.efi",
        "option-data": [ { "name": "routers", "data": net_cards[net]['ip'] } ]
    }
    if networks[net] == 1:
        subnet["pools"] = [ { "pool": cranixconfig.CRANIX_ANON_DHCP_RANGE.replace(" "," - ") } ]
    kea_conf["Dhcp4"]["subnet4"].append(subnet)

with open("/etc/kea/kea-dhcp4.conf","w") as cf:
    cf.write(json.dumps(kea_conf, indent=4, sort_keys=True, ensure_ascii=False))
os.system("echo 'DROP DATABASE IF EXISTS kea_dhcp4'| mariadb")
os.system("echo 'CREATE DATABASE kea_dhcp4'| mariadb")
os.system(f"echo 'GRANT ALL ON kea_dhcp4.* TO \"keauser\"@\"localhost\" IDENTIFIED BY \"{password}\"'| mariadb")
os.system("/usr/bin/systemctl enable kea-dhcp4.service")
os.system("/usr/bin/systemctl restart kea-dhcp4.service")
time.sleep(5)
rooms = {}
for room in json.load(os.popen('crx_api.sh GET rooms/all')):
    rooms[room['id']] = room['name']
    ergebnis = subprocess.run(
        "/usr/share/cranix/plugins/add_room/110-create-dhcp-class.sh",
        input = room_format.format(room['id'], room['name']),  # Übergibt den String als STDIN
        encoding='utf-8',
        check=True             # Löst eine Ausnahme aus, wenn der Befehl fehlschlägt
    )
    print(ergebnis.stdout)
for device in json.load(os.popen('crx_api.sh GET devices/all')):
    tmp = device_format.format(device['id'], device['name'], device['ip'], device['mac'], device['wlanIp'], device['wlanMac'], rooms[device['roomId']])
    print(tmp)
    if device['mac'] != "":
        ergebnis = subprocess.run(
            "/usr/share/cranix/plugins/add_device/110-add-device-to-dhcp.py",
            input = tmp, 
            encoding='utf-8',
            check=True             # Löst eine Ausnahme aus, wenn der Befehl fehlschlägt
        )
        print(ergebnis.stdout)
