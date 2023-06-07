#!/usr/bin/python3
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.
#
# Copyright (c) Peter Varkoly <peter@varkoly.de> Nuremberg, Germany.  All rights reserved.
#
import fnmatch
import subprocess
import threading
import salt.config
import salt.utils.event

def event_handler(ret):
    if event_log_level == "debug":
       print(ret)
    if fnmatch.fnmatch(ret['tag'], 'salt/minion/*/start'):
       print("Client started: " + ret['data']['id'])
       #Start the plugins
       subprocess.call(["/usr/share/cranix/plugins/client_plugin_handler.sh","start", ret['data']['id']])
    if fnmatch.fnmatch(ret['tag'], 'salt/presence/change'):
       print("Client lost: " + ','.join(ret['data']['lost']))
       subprocess.call(["/usr/share/cranix/plugins/client_plugin_handler.sh","lost", ','.join(ret['data']['lost'])])
    if fnmatch.fnmatch(ret['tag'], 'salt/presence/present'):
       subprocess.call(["/usr/share/cranix/plugins/client_plugin_handler.sh","present", ','.join(ret['data']['present'])])


opts = salt.config.client_config('/etc/salt/master')

sevent = salt.utils.event.get_event(
        'master',
        sock_dir=opts['sock_dir'],
        transport=opts['transport'],
        opts=opts)

event_log_level="warning"
if 'crx_event_log_level' in opts:
   event_log_level = opts['crx_event_log_level']

while True:
    ret = sevent.get_event(full=True)
    if ret is None:
        continue

    if fnmatch.fnmatch(ret['tag'], 'salt/event/exit'):
        continue

    t = threading.Thread(target=event_handler,args=(ret,))
    t.start()


