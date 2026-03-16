#!/usr/bin/python3
#
# Copyright (c) Peter Varkoly <peter@varkoly.de> Nuremberg, Germany.  All rights reserved.
#

import os
import sys
import re
import json

printers=[]
printer={}
name=""
for line in os.popen('LANG=en_EN lpc status').readlines():
  match = re.search(r"([\-\w]+):", line)
  if match:
     if "name" in printer:
       printers.append(printer)
     name =  match.group(1)
     printer = { "name": name }
     if os.path.isfile("/var/lib/printserver/drivers/x64/3/"+name+".ppd"):
       printer["windowsDriver"] = True
     else:
       printer["windowsDriver"] = False
     next
  #Eval queuing
  match = re.search(r"queuing is (\w+)", line)
  if match:
     if match.group(1) == "enabled":
       printer["acceptingJobs"] = True
     else:
       printer["acceptingJobs"] = False
     next

  #Eval printing
  match = re.search(r"printing is (\w+)", line)
  if match:
     printer["status"] = match.group(1)
     next

  #Eval jobs
  match = re.search(r"(\w+) entries", line)
  if match:
     if match.group(1) == "no":
       printer["activeJobs"] = 0
     else:
       printer["activeJobs"] = match.group(1)
     next
printers.append(printer)

print(json.dumps(printers))
