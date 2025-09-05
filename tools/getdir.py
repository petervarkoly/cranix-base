#!/usr/bin/python3

import os
import sys
import json
import pwd
from datetime import datetime



def get_username_from_uid(uid):
    try:
        user_info = pwd.getpwuid(uid)
        return user_info.pw_name
    except KeyError:
        return None  # UID nicht gefunden

def format_permissions(mode):
    permissions = ''
    # Owner
    permissions += 'r' if mode & 0o400 else '-'
    permissions += 'w' if mode & 0o200 else '-'
    permissions += 'x' if mode & 0o100 else '-'
    # Group
    permissions += 'r' if mode & 0o40 else '-'
    permissions += 'w' if mode & 0o20 else '-'
    permissions += 'x' if mode & 0o10 else '-'
    # Others
    permissions += 'r' if mode & 0o4 else '-'
    permissions += 'w' if mode & 0o2 else '-'
    permissions += 'x' if mode & 0o1 else '-'

    return permissions

def get_directory_contents(dir_path):
    entries = []

    # Das Parent-Verzeichnis ".." hinzufügen, falls möglich
    parent_dir = os.path.abspath(os.path.join(dir_path, os.pardir))
    if os.path.exists(parent_dir):
        entries.append({
            "name": "..",
            "path": parent_dir,
            "last_modified": None,
            "type": "d",
            "perm": None,
            "size": None,
            "owner": None
        })

    # Alle Einträge im Verzeichnis auflisten
    try:
        with os.scandir(dir_path) as it:
            for entry in it:
                name = entry.name
                try:
                    stat_info = entry.stat()
                    last_modified = datetime.fromtimestamp(stat_info.st_mtime).isoformat()[0:19]
                    if entry.is_dir():
                        entry_type = "d"
                        size = None
                    elif entry.is_file():
                        entry_type = "f"
                        size = stat_info.st_size
                    else:
                        # Für andere Typen (z.B. Symlinks), hier als 'other' markieren
                        entry_type = "o"
                        size = None
        
                    entries.append({
                        "name": name,
                        "path": os.path.join(dir_path, name),
                        "last_modified": last_modified,
                        "type": entry_type,
                        "owner": get_username_from_uid(stat_info.st_uid),
                        "perm": format_permissions(stat_info.st_mode),
                        "size": size
                    })
                except Exception as e:
                    pass
    except Exception as e:
        entries.append({
            "name": "You have no permission in this directory",
            "last_modified": None,
            "type": "d",
            "owner": None,
            "perm": None,
            "size": None
        })
    # Sortieren: Verzeichnisse zuerst, dann Dateien, beide alphabetisch
    def sort_key(entry):
        if entry["name"] == "..":
            return (0,)
        elif entry["type"] == "d":
            return (1, entry["name"].lower())
        elif entry["type"] == "f":
            return (2, entry["name"].lower())
        else:
            return (3, entry["name"].lower())

    entries.sort(key=sort_key)
    return entries

if __name__ == "__main__":
    directory_path = ""
    if len(sys.argv) != 2 or sys.argv[1] == "":
        directory_path = pwd.getpwuid(os.getuid()).pw_dir
        
    else:
        directory_path = sys.argv[1]

    if not os.path.isdir(directory_path):
        print(f"Das Verzeichnis '{directory_path}' existiert nicht.")
        sys.exit(1)
    result = get_directory_contents(directory_path)
    print(json.dumps(result, indent=4))
