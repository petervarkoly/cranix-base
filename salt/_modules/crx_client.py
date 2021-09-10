#
# Copyright (c) Peter Varkoly <peter@varkoly.de> Nuremberg, Germany.  All rights reserved.
#
import salt
import os

#Delivers the grains of the client
def get_grains():
  return __grains__

#Sets the controller ip adress
def set_controller_ip(ip):
  if __grains__['os_family'] == 'Windows':
    text_file = open('c:\Windows\ClientControl\secret', 'w')
  else:
    text_file = open('/usr/share/crx_client/','w')

  text_file.write("%s" % ip)
  text_file.close()
  return True

#Reads the controller ip adress
def get_controller_ip():
  if __grains__['os_family'] == 'Windows':
    text_file = open('c:\Windows\ClientControl\secret', 'r')
  else:
    text_file = open('/usr/share/crx_client/','r')

  controller = text_file.read()
  text_file.close()
  return controller

#Locks the client
def lockClient():
  if __grains__['os_family'] == 'Windows':
    os.system('C:\Windows\ClientControl\ClientControl.exe lockClient')
  else:
    return True

  return True

#Unlocks the client
def unLockClient():
  if __grains__['os_family'] == 'Windows':
    os.system("taskkill /IM lockClient.exe /F")
    os.system("taskkill /IM blockInput.exe /F")
  else:
    return True
  return True

#Locks the input devices
def blockInput():
  if __grains__['os_family'] == 'Windows':
    os.system('C:\Windows\ClientControl\ClientControl.exe blockInput')
  else:
    return True

  return True

#Unlocks the input devices
def unBlockInput():
  if __grains__['os_family'] == 'Windows':
    os.system("taskkill /IM blockInput.exe /F")
  else:
    return True

  return True

#LogOff the current user
def logOff():
  if __grains__['os_family'] == 'Windows':
    processes = os.popen('QWINSTA').readlines()
    for p in processes:
      l = p.split()
      if l[0] == 'console' and len(l) > 3:
        os.system('LOGOFF '+l[2])
  else:
    return True

  return True


#Gets the uid of the current user
def loggedIn():
  if __grains__['os_family'] == 'Windows':
    processes = os.popen('QWINSTA').readlines()
    for p in processes:
      l = p.split()
      if l[0] == 'console' and len(l) > 3:
        return l[1]
  else:
    return ""

  return ""

#Apply the registries which were copied from the server
#This function makes only sence on Windows clients
def applyRegs():
  if __grains__['os_family'] == 'Windows':
    for r, d, f in os.walk("C:\\salt\\var\\regs\\"):
      for entry in f:
        os.system("regedit /s C:\\salt\\var\\regs\\" + entry)
        print(os.path.join(r,entry))
  return True

#Execute the commands which was copied from the server
def executeCommands():
  if __grains__['os_family'] == 'Windows':
    for r, d, f in os.walk("C:\\salt\\var\\commands\\"):
      for entry in f:
        os.system("C:\\salt\\var\\commands\\" + entry)
        print(os.path.join(r,entry))
  return True

def disableUpdates():
  if __grains__['os_family'] == 'Windows':
    os.system("sc config wuauserv start= disabled")
    os.system("net stop wuauserv")
  return True

def enableUpdates():
  if __grains__['os_family'] == 'Windows':
    os.system("sc config wuauserv start= auto")
    os.system("net start wuauserv")
  return True

