#!/usr/bin/python3
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.
#
# Copyright (c) Peter Varkoly <peter@varkoly.de> Nuremberg, Germany.  All rights reserved.
#

import json
import os

rooms=json.load(os.popen('crx_api.sh GET rooms/all'))
roomIdToName = {}
for room in rooms:
    roomIdToName[room['id']] = room['name']

users=json.load(os.popen('crx_api.sh GET users/all'))
userIdToName = {}
for user in users:
    userIdToName[user['id']] = user['uid']

hwconfs=json.load(os.popen('crx_api.sh GET hwconfs/all'))
hwconfIdToName = {}
for hwconf in hwconfs:
    hwconfIdToName[hwconf['id']] = hwconf['name']

devices=json.load(os.popen('crx_api.sh GET devices/all'))

with open("devices.csv", 'w') as fp:
    fp.write("room;name;ip;mac;wlanIp;wlanMac;owner;hwconf;place;row;serial;inventary\n")
    for device in devices:
        fp.write("{};{};{};{};{};{};{};{};{};{};{};{}\n".format(
            roomIdToName[device['roomId']],
            device['name'],
            device['ip'],
            device['mac'],
            device['wlanIp'],
            device['wlanMac'],
            userIdToName.get(device['ownerId'],""),
            hwconfIdToName.get(device['hwconfId'],""),
            device['place'],
            device['row'],
            device['serial'],
            device['inventary']
            ))


