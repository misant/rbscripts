#!/usr/bin/env python
# -*- coding: utf-8 -*-

from paramiko import SSHClient, AutoAddPolicy
from shutil import copyfile, move
import os
import time
import datetime
# import re
import hashlib
#import logging
#logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')
#logging.debug('This is a log message.')

ssh = SSHClient()

def get_data(device_ip):
    """Connects to remote RouterOS with device_ip using keys and runs runs "export verbose" to
    get actual configuration. Determines hostname and saves configuration to actual folder as work_dir/actual/hostname.cfg
    and to archive folder as workdir/cfg/hostname/timestamp.cfg
    If new config is same as already archived it is deleted.
    Also all files stored on RouterOS device are copied to workdir/files/hostname/
    """
    host = device_ip
    user = 'admin'
    port = 22

    ssh.set_missing_host_key_policy(AutoAddPolicy())
    remote_cmd = 'export verbose'

    try:
        time_stamp = time.strftime("%Y.%m.%d.%H-%M-%S")
        print datetime.datetime.now(), "Connecting.. " + host
        try:
            ssh.connect(hostname=host, username=user, timeout=3)
            ssh.get_transport().window_size = 3 * 1024 * 1024
            print datetime.datetime.now(), "Connected"

        except:
            print datetime.datetime.now(), "SSH connection failed"
        stdin, stdout, stderr = ssh.exec_command(remote_cmd, timeout=15)
        data = stdout.read() + stderr.read()


        if "user aaa" in data:
            print datetime.datetime.now(), "Config is OK!"
            file_tmp = open(work_dir + 'config.tmp', 'w')
            file_tmp.write(data)
            file_tmp.close()

            file_tmp = open(work_dir + 'config.tmp', 'r+')
            data = file_tmp.readlines()
            file_tmp.seek(0)
            for i in data:
                if not 'by RouterOS' in i:
                    file_tmp.write(i)
                    if 'set name=' in i:
                        hostname = i.split('=')
                        hostname = hostname[1]
#                       hostname = re.sub("[^a-zA-Z0-9-_.]", "", hostname)  # Unsure if below method is better in all cases
                        hostname = hostname.rstrip()
                        print datetime.datetime.now(), "Device name from config = " + hostname
            file_tmp.truncate()
            file_tmp.close()
            copyfile (work_dir + 'config.tmp', actual_dir + hostname + '.cfg' )


            device_dir = work_dir + 'cfg/' + hostname + '/'
            if not os.path.exists(device_dir):
                os.makedirs(device_dir)
            move (work_dir + 'config.tmp', device_dir + time_stamp + '.cfg' )

            print datetime.datetime.now(), "Deduplicating configuration files"
            try:
                check_for_duplicates(device_dir)
                print datetime.datetime.now(), "Deduplication SUCCEED"
            except:
                print datetime.datetime.now(), "Deduplication FAILED"


            files_dir = work_dir + 'files/' + hostname + "/"
            if not os.path.exists(files_dir):
                os.makedirs(files_dir)

            print datetime.datetime.now(), "Transfering files..."


            try:
                ssh_copy_files (files_dir)
                print datetime.datetime.now(), "Transfering files SUCCESS"
            except:
                print datetime.datetime.now(), "Tanssfering files FAIL"



        else:
            print datetime.datetime.now(), "Config broken!"


        ssh.close()

    except:
        print datetime.datetime.now(), "Error connecting to host", host
    print datetime.datetime.now(), device_ip + " done.\n"
    return



def ssh_copy_files(files_dir, remote_dir="/"):
    """Recursive copy of all files from remote_dir to files_dir"""
    sftp = ssh.open_sftp()
    remote_dirlist = []


    for i in sftp.listdir(remote_dir):
        lstatout=str(sftp.lstat(remote_dir + '/' + i)).split()[0]
        if 'd' in lstatout:
            remote_dirlist.append([i])

        else:
            sftp.get(remote_dir + i, files_dir + i)


    for found_dir in remote_dirlist:
        nfound_dir=''.join(found_dir)
        nfiles_dir = files_dir + nfound_dir + "/"
        if not os.path.exists(files_dir + nfound_dir):
            os.makedirs(files_dir + nfound_dir)
        ssh_copy_files (nfiles_dir, "/" + nfound_dir + "/")

    sftp.close
    return


def chunk_reader(fobj, chunk_size=1024):
    """Generator that reads a file in chunks of bytes"""
    while True:
        chunk = fobj.read(chunk_size)
        if not chunk:
            return
        yield chunk

def check_for_duplicates(dpath, hash=hashlib.sha1):
    """Delete duplicate files in folder
    Copy pasted from http://stackoverflow.com/a/748908/6221971
    And changed to parse only one argument as path
    """
    hashes = {}
    for dirpath, dirnames, filenames in os.walk(dpath):
        for filename in filenames:
            full_path = os.path.join(dirpath, filename)
            hashobj = hash()
            for chunk in chunk_reader(open(full_path, 'rb')):
                hashobj.update(chunk)
            file_id = (hashobj.digest(), os.path.getsize(full_path))
            duplicate = hashes.get(file_id, None)
            if duplicate:
                os.remove(full_path)
            else:
                hashes[file_id] = full_path
    return


work_dir = "/srv/rb_backup/"
actual_dir = work_dir + "actual/"

if not os.path.exists(actual_dir):
    os.makedirs(actual_dir)


ip_file = open(work_dir + 'rb', 'r')
ip_list = ip_file.readlines()
for ip in ip_list:
    ip = ip.rstrip()
    get_data(ip)
ip_file.close()

"""
ToDO:
1. Recursive SFTP with unlimitied levels
2. Multithreading
"""
