#!/usr/bin/python3

import cranixconfig
import json
import os

def netzwerk_zuordnen_netifaces():
    """Ermittelt die Netzwerke, zu denen jede Netzwerkschnittstelle gehört, mit netifaces."""

    ergebnisse = {}

    # 1. Liste aller Schnittstellennamen abrufen
    schnittstellen = netifaces.interfaces()

    for iface in schnittstellen:
        # 2. Adressen für die aktuelle Schnittstelle abrufen
        adressen = netifaces.ifaddresses(iface)

        # 3. Nur die Adressen der Familie AF_INET (IPv4) betrachten
        if netifaces.AF_INET in adressen:
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

                    except (ValueError, NetmaskValueError, IPv4Address) as e:
                        # Fehlerbehandlung für ungültige IP/Masken
                        ergebnisse[f"{iface}"] = f"Fehler bei IPv4-Berechnung: {e}"

    return ergebnisse

net_cards = netzwerk_zuordnen_netifaces()

network = f"{cranixconfig.CRANIX_NETWORK}/{cranixconfig.CRANIX_NETMASK}"
network_counter = 1
networks = {
    network: network_counter
}
network_counter++
#Read all networks in system
try:
    for net in json.load(os.popen('crx_api.sh GET system/enumerates/network')):
        if not net in networks:
            networks[network] = network_counter
            network_counter++
except Error:
    pass

dhcp_devices = []

for net in net_cards:
    if net in networks:
        dhcp_devices.puss(net_cards[net][dev])

kea_conf = {
    "Dhcp4": {
        "interfaces-config": {
            "interfaces": [ dhcp_devices ]
        },
        "control-socket": {
            "socket-type": "unix",
            "socket-name": "kea4-ctrl-socket"
        },
        "lease-database": {
            "type": "mysql",
            "name": "kea_dhcp4",
            "user": "keauser",
            "password": "Bartok12#34",
            "host": "localhost",
            "port": 3306
        },
        "hosts-database": {
            "type": "mysql",
            "name": "kea_dhcp4",
            "user": "keauser",
            "password": "Bartok12#34",
            "host": "localhost",
            "port": 3306
        },
        "client-classes": [
            {
                "name": "pxe-bios",
                "test": "option[vendor-class-identifier].text == 'PXEClient:Arch:00000:UNDI:002001'",
                "next-server": "172.18.0.2",
                "boot-file-name": "pxelinux.0"
            }
        ],
        "hooks-libraries": [ 
                { "library": "/usr/lib64/kea/hooks/libdhcp_mysql.so" },
                { "library": "/usr/lib64/kea/hooks/libdhcp_host_cmds.so" },
                { "library": "/usr/lib64/kea/hooks/libdhcp_class_cmds.so" }
            ]
        }
        "subnet4": []
}

for net in networks:
    subnet = {
        "id": networks[net],
        "subnet": net,
        "valid-lifetime": 300,
        "max-valid-lifetime": 600,
        "next-server": net_cards[net][ip],
        "boot-file-name": "efi/bootx64.efi"
    }
    if networks[net] == 1:
        subnet["pools"] = [ { "pool": cranixconfig.CRANIX_ANON_DHCP_RANGE.replace(" "," - ") } ]
    kea_conf["Dhcp4"]["subnet4"].push(subnet)
