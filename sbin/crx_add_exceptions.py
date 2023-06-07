#!/usr/bin/python3
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.
import socket
import json
import os
from argparse import ArgumentParser

#Parse arguments
parser = ArgumentParser()
parser.add_argument("--id",   dest="id",   default="", help="The room id.")
parser.add_argument("--dest", nargs="+", help="List of the allowed domains")
args = parser.parse_args()

room    = json.load(os.popen('/usr/sbin/crx_api.sh GET rooms/{0}'.format(args.id)))
network = '{0}/{1}'.format(room['startIP'],room['netMask'])

for i in args.dest:
    for ip in socket.gethostbyname_ex(i)[2]:
        os.system('/usr/bin/firewall-cmd --zone="external" --add-rich-rule="rule family=ipv4 source address={0} destination address={1} masquerade" &>/dev/null'.format(network,ip))

