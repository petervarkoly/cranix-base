# -*- coding: utf-8 -*-

# Copyright (c) Peter Varkoly <peter@varkoly.de> All rights reserved.

"""Some python modules for OSS/CRANIX
Works with Python versions from 3.6.
"""
import json
import os
import sys
import time
import csv
from configobj import ConfigObj

from . import _vars
from ._vars import attr_ext_name
from ._vars import user_attributes

from . import _functions
from ._functions import read_birthday
from ._functions import create_secure_pw
from ._functions import print_error
from ._functions import print_msg

# Internal debug only
init_debug = False

# Define some global variables
required_classes = []
existing_classes = []
all_groups       = []
all_users   = {}
import_list = {}
new_user_count  = 1
new_group_count = 1
lockfile = '/run/oss_import_user'

date = time.strftime("%Y-%m-%d.%H-%M-%S")
# read and set some default values
config    = ConfigObj("/opt/oss-java/conf/oss-api.properties")
passwd    = config['de.openschoolserver.dao.User.Register.Password']
domain    = os.popen('oss_api_text.sh GET system/configuration/DOMAIN').read()
home_base = os.popen('oss_api_text.sh GET system/configuration/HOME_BASE').read()
check_pw  = os.popen('oss_api_text.sh GET system/configuration/CHECK_PASSWORD_QUALITY').read().lower() == 'yes'
roles  = []
for role in os.popen('oss_api_text.sh GET groups/text/byType/primary').readlines():
  roles.append(role.strip())

def init(args):
    global output, input_file, role, password, identifier, full, test, debug, mustchange
    global resetPassword, allClasses, cleanClassDirs, appendBirthdayToPassword
    global import_dir, required_classes, existing_classes, all_users, import_list
    global fsQuota, fsTeacherQuota, msQuota, msTeacherQuota
    fsQuota        = int(os.popen('oss_api_text.sh GET system/configuration/FILE_QUOTA').read())
    fsTeacherQuota = int(os.popen('oss_api_text.sh GET system/configuration/FILE_TEACHER_QUOTA').read())
    msQuota        = int(os.popen('oss_api_text.sh GET system/configuration/MAIL_QUOTA').read())
    msTeacherQuota = int(os.popen('oss_api_text.sh GET system/configuration/MAIL_TEACHER_QUOTA').read())
    os.system("oss_api.sh PUT system/configuration/CHECK_PASSWORD_QUALITY/no")
    import_dir = home_base + "/groups/SYSADMINS/userimports/" + date
    os.system('mkdir -pm 770 ' + import_dir + '/tmp' )
    #open the output file
    output     = open(import_dir + '/import.log','w')
    #create lock file
    with open(lockfile,'w') as f:
        f.write(date)
    #write the parameter
    args_dict=args.__dict__
    args_dict["startTime"] = date
    with open(import_dir +'/parameters.json','w') as f:
        json.dump(args_dict,f,ensure_ascii=False)
    input_file = args.input
    role       = args.role
    password   = args.password
    identifier = args.identifier
    full       = args.full
    test       = args.test
    debug      = args.debug
    mustchange = args.mustchange
    resetPassword   = args.resetPassword
    allClasses      = args.allClasses
    cleanClassDirs = args.cleanClassDirs
    appendBirthdayToPassword = args.appendBirthdayToPassword

    read_classes()
    read_groups()
    read_users()
    read_csv()

def read_classes():
    global existing_classes
    for group in os.popen('/usr/sbin/oss_api_text.sh GET groups/text/byType/class').readlines():
        existing_classes.append(group.strip())

def read_groups():
    global existing_groups
    for group in os.popen('/usr/sbin/oss_api_text.sh GET groups/text/byType/workgroups').readlines():
        all_groups.append(group.strip())

def read_users():
    global all_users
    for user in json.load(os.popen('/usr/sbin/oss_api.sh GET users/byRole/' + role )):
        user_id = ""
        user['birthDay'] = time.strftime("%Y-%m-%d",time.localtime(user['birthDay']/1000))
        if identifier == "sn-gn-bd":
            user_id = user['surName'].upper() + '-' + user['givenName'].upper() + '-' + user['birthDay']
        else:
            user_id = user[identifier]
        user_id = user_id.replace(' ','_')
        all_users[user_id]={}
        for key in user:
            all_users[user_id][key] = user[key]
    if(debug):
        print("All existing user:")
        print(all_users)

def read_csv():
    global import_list
    #Copy the import file into the import directory
    if input_file != import_dir + '/userlist.txt':
        os.system('cp ' + input_file + ' ' + import_dir + '/userlist.txt')
    # fix some dos stuff
    os.system("/usr/bin/dos2unix " + input_file)
    with open(input_file) as csvfile:
        #Detect the type of the csv file
        dialect = ""
        try:
            dialect = csv.Sniffer().sniff(csvfile.readline())
        except UnicodeDecodeError:
            close_on_error('CVS file is not UTF-8')
        csvfile.seek(0)
        #Create an array of dicts from it
        csv.register_dialect('oss',dialect)
        reader = csv.DictReader(csvfile,dialect='oss')
        if init_debug:
            print(reader.fieldnames)
        for row in reader:
            user = {}
            user_id = ''
            for key in row:
                if key == '':
                    continue
                if init_debug:
                    print(attr_ext_name[key.upper()] + " " + row[key])
                user[attr_ext_name[key.upper()]] = row[key]
            try:
                user['birthDay'] = read_birthday(user['birthDay'])
            except SyntaxError:
                user['birthDay'] = ''
            #uid must be in lower case
            if 'uid' in user:
                user['uid'] = user['uid'].lower()
            if identifier == "sn-gn-bd":
                user_id = user['surName'].upper() + '-' + user['givenName'].upper() + '-' + user['birthDay']
            else:
                if not identifier in user:
                    close_on_error("Import file does not contains the identifier:" + identifier)
                user_id = user[identifier]
            if not 'classes' in user:
                user['classes'] = ''
            user_id = user_id.replace(' ','_')
            import_list[user_id] = user
    if(debug):
        print("All user in the list:")
        print(import_list)

def log_debug(text,obj):
    if debug:
        print(text)
        print(obj)


def close():
    if check_pw:
        os.system("oss_api.sh PUT system/configuration/CHECK_PASSWORD_QUALITY/yes")
    else:
        os.system("oss_api.sh PUT system/configuration/CHECK_PASSWORD_QUALITY/no")
    os.remove(lockfile)
    output.write(print_msg("Import finished","OK"))
    output.close()

def close_on_error(msg):
    if check_pw:
        os.system("oss_api.sh PUT system/configuration/CHECK_PASSWORD_QUALITY/yes")
    else:
        os.system("oss_api.sh PUT system/configuration/CHECK_PASSWORD_QUALITY/no")
    os.remove(lockfile)
    output.write(print_error(msg))
    output.close()
    sys.exit(1)

def log_error(msg):
    output.write(print_error(msg))
    output.flush()

def log_msg(title,msg):
    output.write(print_msg(title,msg))
    output.flush()

def add_group(name):
    global new_group_count
    group = {}
    group['name'] = name.upper()
    group['groupType'] = 'workgroup'
    group['description'] = name
    file_name = '{0}/tmp/group_add.{1}'.format(import_dir,new_group_count)
    with open(file_name, 'w') as fp:
        json.dump(group, fp, ensure_ascii=False)
    result = json.load(os.popen('oss_api_post_file.sh groups/add ' + file_name))
    new_group_count = new_group_count + 1
    if debug:
        print(add_group)
        print(result)
    if result['code'] == 'OK':
        return True
    else:
        log_error(result['value'])
        return False

def add_class(name):
    global new_group_count
    global existing_classes
    group = {}
    group['name'] = name.upper()
    group['groupType'] = 'class'
    #TODO translation
    group['description'] ='Klasse ' + name
    file_name = '{0}/tmp/group_add.{1}'.format(import_dir,new_group_count)
    with open(file_name, 'w') as fp:
        json.dump(group, fp, ensure_ascii=False)
    result = json.load(os.popen('oss_api_post_file.sh groups/add ' + file_name))
    existing_classes.append(name)
    new_group_count = new_group_count + 1
    if debug:
        print(result)
    if result['code'] == 'OK':
        return True
    else:
        log_error(result['value'])
        return False

def add_user(user,ident):
    global new_user_count
    global import_list
    if mustchange:
        user['mustChange'] = True
    if password != "":
        user['password'] = password
    if appendBirthdayToPassword:
        user['password'] = password + user['birthDay']
    #if 'class' in user:
    #    user['classes'] = user['class']
    #    del user['class']
    #Set default file system quota 
    if not 'fsQuota' in user:
        if role == 'teachers':
            user['fsQuota'] = fsTeacherQuota
        elif role == 'sysadmins':
            user['fsQuota'] = 0
        else:
            user['fsQuota'] = fsQuota
    #Set default mail system quota 
    if not 'msQuota' in user:
        if role == 'teachers':
            user['msQuota'] = msTeacherQuota
        elif role == 'sysadmins':
            user['msQuota'] = -1
        else:
            user['msQuota'] = msQuota
    file_name = '{0}/tmp/user_add.{1}'.format(import_dir,new_user_count)
    with open(file_name, 'w') as fp:
        json.dump(user, fp, ensure_ascii=False)
    result = json.load(os.popen('oss_api_post_file.sh users/insert ' + file_name))
    if debug:
        print(result)
    if result['code'] == 'OK':
        import_list[ident]['id']       = result['objectId']
        import_list[ident]['uid']      = result['parameters'][0]
        import_list[ident]['password'] = result['parameters'][3]
        new_user_count = new_user_count + 1
        return True
    else:
        log_error(result['value'])
        return False

def modify_user(user,ident):
    if identifier != 'sn-gn-bd':
        user['givenName'] = import_list[ident]['givenName']
        user['surName']   = import_list[ident]['surName']
        user['birthDay']  = import_list[ident]['birthDay']
    file_name = '{0}/tmp/user_modify.{1}'.format(import_dir,user['uid'])
    with open(file_name, 'w') as fp:
        json.dump(user, fp, ensure_ascii=False)
    result = json.load(os.popen('oss_api_post_file.sh users/{0} {1} '.format(user['id'],file_name)))
    if debug:
        print(result)
    if result['code'] == 'ERROR':
        log_error(result['value'])

def move_user(uid,old_classes,new_classes):
    for g in old_classes:
       if g == '' or g.isspace():
            continue
       if not g in new_classes:
           cmd = '/usr/sbin/oss_api_text.sh DELETE users/text/{0}/groups/{1}'.format(uid,g)
           if debug:
               print(cmd)
           result = os.popen(cmd).read()
           if debug:
               print(result)
    for g in new_classes:
       if g == '' or g.isspace():
            continue
       if not g in old_classes:
           cmd = '/usr/sbin/oss_api_text.sh PUT users/text/{0}/groups/{1}'.format(uid,g)
           if debug:
               print(cmd)
           result = os.popen(cmd).read()
           if debug:
               print(result)

def delete_user(uid):
    cmd = '/usr/sbin/oss_api_text.sh DELETE users/text/{0}'.format(uid)
    if debug:
        print(cmd)
    result = os.popen(cmd).read()
    if debug:
        print(result)

def delete_class(group):
    cmd = '/usr/sbin/oss_api_text.sh DELETE groups/text/{0}'.format(group)
    if debug:
        print(cmd)
    result = os.popen(cmd).read()
    if debug:
        print(result)

def write_user_list():
    file_name = '{0}/all-{1}.txt'.format(import_dir,role)
    with open(file_name, 'w') as fp:
        #TODO Translate header
        fp.write(';'.join(user_attributes)+"\n")
        for ident in import_list:
            line = []
            for attr in user_attributes:
                line.append(import_list[ident].get(attr,""))
            fp.write(';'.join(map(str,line))+"\n")
    if role == 'students':
        class_files = {}
        for cl in existing_classes:
            try:
                class_files[cl] = open('{0}/class-{1}.txt'.format(import_dir,cl),'w')
                class_files[cl].write(';'.join(user_attributes)+"\n")
            except:
                log_error("Can not open:" + '{0}/class-{1}.txt'.format(import_dir,cl))
        for ident in import_list:
            user = import_list[ident]
            line = []
            for attr in user_attributes:
                line.append(user.get(attr,""))
            for user_class in user['classes'].split():
                if user_class in class_files:
                    class_files[user_class].write(';'.join(map(str,line))+"\n")
        for cl in class_files:
            class_files[cl].close()
    #Now we start to write the password files
    os.system('/usr/share/oss/tools/create_password_files.py {0} {1}'.format(import_dir,role))


