#!/usr/bin/python3
import json
import os
import subprocess

room_format = """
id: {0}
name: {1}
"""

for room in json.load(os.popen('crx_api.sh GET rooms/all')):
    result = subprocess.run(
        "/usr/share/cranix/plugins/add_room/110-create-dhcp-class.sh",
        input = room_format.format(room['id'], room['name']),  # Übergibt den String als STDIN
        encoding='utf-8',
        check=True             # Löst eine Ausnahme aus, wenn der Befehl fehlschlägt
    )
    print(ergebnis.stdout)

