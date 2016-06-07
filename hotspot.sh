#!/bin/bash
#################################
#       Bekhterev Evgeniy       #
#       ver 0.2                 #
#       07.06.2016              #
#       www.bekhterev.me        #
#################################
# script connects via ssh to remote mikrotik listed in ./rb file
# and outputs data collected
# output fields:
#hotspot mac, device mac, connection uptime/status, start time of connection, time of check

#If there are no known macs list - create empty file
[[ -f mac ]] || touch mac

#Getting ip of routerboard from list and gathering data
#Doing that for every ip, one ip per line
for RBIP in $(cat rb); do

    echo "Processing $RBIP"


#Getting current date and time in seconds and in human readable formats
    CurrentCalc=`date +%s`
    CurrentTime=`date +%Y-%m-%d:%H:%M:%S`
    echo $CurrentTime

#If we have entry in known mac list for current ip, get it from file, if not older then 24h
    if grep -q $RBIP "mac"; then
        echo "IP is known"
        ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no admin@$RBIP ip hot host pr > hosts
#        if [ $(echo $?) == 0 ]; then
                echo "SSH success grab devices MACs"
                ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no admin@$RBIP ip hot active pr > active
                HotspotIntMAC=`grep $RBIP "mac" | awk '{print($2)}'`
                MACDate=`grep $RBIP "mac" | awk '{print($3)}'`
                MACSecs=`grep $RBIP "mac" | awk '{print($4)}'`
                if (( "$CurrentCalc - $MACSecs" > 86400 )); then
                    echo "MAC is old"
                    ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no admin@$RBIP ip hot print > hotspot
                    ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no admin@$RBIP inter pri deta > interfaces
                    HotspotIntName=`cat hotspot | grep m | awk '{print($3)}'`
                    HotspotIntMAC=`cat interfaces | grep -A 1 $HotspotIntName | awk '{print($1)}' | cut -d= -f2`
                    HotspotIntMAC=( $HotspotIntMAC )
                    HotspotIntMAC=${HotspotIntMAC[1]}
                    sed -i -e "/$RBIP/d" ./mac
                    echo "$RBIP $HotspotIntMAC $CurrentTime $CurrentCalc" >> mac
                fi
#       fi
#Otherwise get all data, including hostpot mac
    else
        echo "New IP"
        ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no admin@$RBIP ip hot host pr > hosts
#        SSHStat=$?
#       echo "ssh status = $SSHStat"
#       if [ $SSHStat == 0 ]; then
            echo "SSH success grab other data"
            ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no admin@$RBIP ip hot active pr > active
            ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no admin@$RBIP ip hot print > hotspot
            ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no admin@$RBIP inter pri deta > interfaces

            HotspotIntName=`cat hotspot | grep m | awk '{print($3)}'`
            HotspotIntMAC=`cat interfaces | grep -A 1 $HotspotIntName | awk '{print($1)}' | cut -d= -f2`
            HotspotIntMAC=( $HotspotIntMAC )
            HotspotIntMAC=${HotspotIntMAC[1]}
            echo "$RBIP $HotspotIntMAC $CurrentTime $CurrentCalc" >> mac

#       fi
    fi

#       if [ $SSHStat == 0 ]; then
            echo "SSH success, processing files"
            cat active | grep h | while read -r line ; do
                DeviceIP=`echo $line | awk '{print($4)}'`
                DeviceUptime=`echo $line | awk '{print($5)}'`

                if [[ $DeviceUptime == *"h"* ]]; then
                    UptimeH=`echo $DeviceUptime | cut -d 'h' -f 1`
                else
                    UptimeH=0
                    DeviceUptime=`echo "0h$DeviceUptime"`
                fi

                if [[ $DeviceUptime == *"s"* ]];  then
                    if [[ $DeviceUptime == *"m"* ]]; then
                        UptimeS=`echo $DeviceUptime | awk -F'[s]' '{print $1}'| awk -F'[m]' '{print $2}'`
                    else
                        UptimeS=`echo $DeviceUptime | awk -F'[s]' '{print $1}'| awk -F'[h]' '{print $2}'`
                    fi
                else
                    UptimeS=0
                    DeviceUptime=`echo $DeviceUptime'0s'`
                fi

                if [[ $DeviceUptime == *"m"* ]]; then
                    UptimeM=`echo $DeviceUptime | grep -o -P '(?<=h).*(?=m)'`
                else
                    UptimeM=0
                fi

                let UptimeCalc="$UptimeH * 3600 + $UptimeM * 60 + $UptimeS"
                let ConnCalc="$CurrentCalc - $UptimeCalc"
                ConnTime=`date -u -d @${ConnCalc} +%Y-%m-%d:%H:%M:%S`
                DeviceMAC=`cat hosts | grep "$DeviceIP " | awk '{print($3)}'`
                echo "Writing active"
                echo "$HotspotIntMAC,$DeviceMAC,$DeviceUptime,$ConnTime,$CurrentTime" >> output
            done

            cat hosts | grep 5m | while read -r line ; do
                DeviceMAC=`echo $line | awk '{print($3)}'`
                ConnStatus=`echo $line | awk '{print($2)}'`
                echo "Writing not active"
                echo "$HotspotIntMAC,$DeviceMAC,$ConnStatus,unauthorised,$CurrentTime" >> output
            done
#       fi
echo "done"
echo "------------------------------"
done


#Delete all temporary files
rm -f interfaces
rm -f hotspot
rm -f active
rm -f hosts
