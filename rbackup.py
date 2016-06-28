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

sshCli = SSHClient()

def getData( IP ):
    host = IP
    user = 'admin'
    port = 22

#    sshCli = SSHClient()
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


#        sshCli.close()
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


            fileDir = workDir + 'files/' + ID + "/"
            if not os.path.exists(fileDir):
                os.makedirs(fileDir)

            print "Tranfering files..."


            try:
                copyFiles (fileDir)
                print "Tranfering files success"
            except:
                print "Tansfering files FAIL"



        else:
            print "Config broken!"


        sshCli.close()

    except:
        print "Error connecting to host", host
    print IP + " done.\n"
    return



def copyFiles(fileDir, Dir="/"):
    sftp = sshCli.open_sftp()
    dirlist = []


    for i in sftp.listdir(Dir):
        lstatout=str(sftp.lstat(Dir + '/' + i)).split()[0]
        if 'd' in lstatout:
            dirlist.append([i])

        else:
            sftp.get(Dir + i, fileDir + i)


    for ed in dirlist:
        ned=''.join(ed)
        nfileDir = fileDir + ned + "/"
        if not os.path.exists(fileDir + ned):
            os.makedirs(fileDir + ned)
        copyFiles (nfileDir, "/" + ned + "/")

    sftp.close
    return


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



#Need to implement duplicats deletion
#rm_duplicates("/srv/py_backup/cfg/gwdf/")
#LS = os.listdir(workDir + "cfg/gwdf/")
#print LS
