# -*- coding: utf-8 -*-

# Copyright (c) 2021 Peter Varkoly <pvarkoly@cephalix.eu> All rights reserved.
from random import *
from subprocess import run, PIPE
import datetime
import re

valid_uid = re.compile(r"^[a-zA-Z0-9]+[a-zA-Z0-9\.\-\_]*[a-zA-Z0-9]$")

def read_birthday(bd):
    i_bd = bd.replace('.','-')
    l_bd = i_bd.replace(':','-').split('-')
    y=""
    m=""
    d=""
    if( len(l_bd) != 3 ):
        lbd=len(bd)
        if lbd == 8:
            y=bd[:4]
            m=bd[4:6]
            d=bd[6:]
        else:
            raise SyntaxError("Bad birthday format:" + bd)
    elif(len(l_bd[0]) == 4 ):
        y=l_bd[0]
        m=l_bd[1]
        d=l_bd[2]
    elif(len(l_bd[2]) == 4 ):
        y=l_bd[2]
        m=l_bd[1]
        d=l_bd[0]
    else:
        raise SyntaxError("Bad birthday format:" + bd)
    try:
        datetime.datetime(year=int(y),month=int(m),day=int(d))
    except ValueError:
        raise SyntaxError("Bad birthday format:" + bd)
    return "{:4s}-{:0>2s}-{:0>2s}".format(y,m,d)

def create_secure_pw(l):
    lenght= l-2
    pw    = ""
    signs = ['#', '+', '$']
    start = int(randint(2,lenght/2+2))
    for i in range(0,start):
        if( randint(0,1) == 1 ):
            pw = pw + chr(randint(0,25)+97)
        else:
            pw = pw + chr(randint(0,25)+65)
    pw = pw + signs[randint(0,2)]
    pw = pw + signs[randint(0,2)]
    for i in range(0,lenght-start):
        if( randint(0,1) == 1 ):
            pw = pw + chr(randint(0,25)+97)
        else:
            pw = pw + chr(randint(0,25)+65)
    pw.replace('I','G')
    pw.replace('l','g')
    return pw

def print_error(msg):
    return '<tr><td colspan="2"><font color="red">{0}</font></td></tr>\n'.format(msg)

def print_msg(title, msg):
    return '<tr><td>{0}</td><td>{1}</td></tr>\n'.format(title,msg)

def check_uid(uid: str):
    if len(uid) < 2:
        return "UID must contains at last 2 characters"
    if len(uid) > 32:
        return "UID must not contains more then 32 characters"
    if not valid_uid.match(uid):
        return "UID contains invalid chracter."
    p = run(["/usr/bin/id",uid], stdout=PIPE, stderr=PIPE)
    if p.returncode == 0:
        return "uid '{}' is not unique".format(uid)
    return ""

def check_password(password):
    try:
        p = run("/usr/share/cranix/tools/check_password_complexity.sh", stdout=PIPE,  stderr=PIPE, input=password, encoding='ascii')
    except UnicodeEncodeError:
        print("Password not ascii")
    else:
        if p.stdout != "":
            (a,b) = p.stdout.split("##")
            return a.replace('%s','{}').format(b.strip())
    return ""

