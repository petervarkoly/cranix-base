# -*- coding: utf-8 -*-

# Copyright (c) 2021 Peter Varkoly <pvarkoly@cephalix.eu> All rights reserved.
from random import *
import datetime
import json
import os


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
            d=bd[7:]
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
    return '<font color="red">{0}</font></br>\n'.format(msg)

def print_msg(title,msg):
    return '<b>{0}</b>{1}</br>\n'.format(title,msg)

