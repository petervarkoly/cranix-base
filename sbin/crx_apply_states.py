#!/usr/bin/python3
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.

import yaml
import sys
import os

minion = sys.argv[1]
client = minion.split('.')[0]

states = yaml.load(open('/srv/salt/crx_device_{0}.sls'.format(client),'r'),Loader=yaml.FullLoader)
os.system('/usr/bin/salt "{0}" saltutil.kill_all_jobs'.format(minion))
os.system('/usr/bin/salt "{0}" system.set_computer_name "{1}"'.format(minion,client))
for state in states['include']:
   os.system('/usr/bin/salt "{0}" state.apply "{1}"'.format(minion,state))

