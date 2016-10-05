#!/bin/bash

date
find /srv/hotspot/*.txt -mtime +7 -type f -delete

HOST=ftp.welikewifi.com  #This is the FTP servers host or IP address.
USER=hotspot@welikewifi.com           #This is the FTP user that has access to the server.
PASS=somepass          #This is the password for the FTP user.

# Call 1. Uses the ftp command with the -inv switches.
#-i turns off interactive prompting.
#-n Restrains FTP from attempting the auto-login feature.
#-v enables verbose and progress.

cd /srv/hotspot/
ftp -invp $HOST << EOF

user $USER $PASS
cd  /
mput *.txt
bye

EOF
