#!/usr/bin/env python
# -*- coding: utf-8 -*-

# for SSH
from paramiko import SSHClient
from paramiko import AutoAddPolicy
from shutil import copyfile
from shutil import move
# for versioning
import os
# for sleep
import time
import re
import md5
import hashlib

def getData( IP ):
    host = IP
    user = 'admin'
    port = 22

    sshCli = SSHClient()
    sshCli.set_missing_host_key_policy(AutoAddPolicy())
    remoteCmd = 'export verbose'

    try:
        timeStamp = time.strftime("%Y.%m.%d.%H-%M-%S")
        print "Connecting.. " + host
        try:
            sshCli.connect(hostname=host, username=user, timeout=3)
            print "Connected"
        except:
            print "SSH connection failed"
        stdin, stdout, stderr = sshCli.exec_command(remoteCmd, timeout=15)
        data = stdout.read() + stderr.read()
        sshCli.close()
        if "user aaa" in data:
            print "Config is OK!"
            fileTmp = open(workDir + 'config.tmp', 'w')
            fileTmp.write(data)
            fileTmp.close()

            fileTmp = open(workDir + 'config.tmp', 'r+')
            data = fileTmp.readlines()
            fileTmp.seek(0)
            for i in data:
                if not 'by RouterOS' in i:
                    fileTmp.write(i)
                    if 'set name=' in i:
                        ID = i.split('=')
                        ID = ID[1]
                        ID = re.sub("[^a-zA-Z0-9-_.]", "", ID)
                        print "Device name from config = " + ID
            fileTmp.truncate()
            fileTmp.close()
            copyfile (workDir + 'config.tmp', actDir + ID + '.cfg' )


            devDir = workDir + 'cfg/' + ID + '/'
            if not os.path.exists(devDir):
                os.makedirs(devDir)
            move (workDir + 'config.tmp', devDir + timeStamp + '.cfg' )


        else:
            print "Config broken!"

    except:
        print "Error connecting to host", host
    print IP + " done.\n"
    return

#def rm_duplicates(dir):



workDir = "/srv/py_backup/"
actDir = workDir + "actual/"

if not os.path.exists(actDir):
    os.makedirs(actDir)


fileIP = open(workDir + 'rb', 'r')
listIP = fileIP.readlines()
for line in listIP:
    line = re.sub("[^0-9.]", "", line)
    getData(line)
fileIP.close()
