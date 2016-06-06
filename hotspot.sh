#!/bin/bash
#################################
#       Bekhterev Evgeniy       #
#       ver 0.1                 #
#       06.06.2016              #
#       www.bekhterev.me        #
#################################
# script connects via ssh to remote mikrotik listed in ./routerboards file
# and outputs data collectd
# output fields:
#hotspot mac, device mac, connection uptime/status, start time of connection, time of check

#Getting current date and time in seconds and in human readable formats
CurrentCalc=`date +%s`
CurrentTime=`date +%Y-%m-%d:%H:%M:%S`

#Getting ip of routerboard from list and gathering data
#Doing that for every ip, one ip per line
cat routerboards | while read -r line ; do

#If there are no known macs list - create empty file
[[ -f mac ]] || touch mac

#If we have entry in known mac list for current ip, get it from file, if not older then 24h
if grep -q $line "mac"; then
    ssh admin@$line ip hot host pr > hosts
    ssh admin@$line ip hot active pr > active
    HotspotIntMAC=`grep $line "mac" | awk '{print($2)}'`
    MACDate=`grep $line "mac" | awk '{print($3)}'`
    MACSecs=`grep $line "mac" | awk '{print($4)}'`
    if (( "$CurrentCalc - $MACSecs" > 86400 )); then
        ssh admin@$line ip hot print > hotspot
        ssh admin@$line inter pri deta > interfaces
        HotspotIntName=`cat hotspot | grep m | awk '{print($3)}'`
        HotspotIntMAC=`cat interfaces | grep -A 1 $HotspotIntName | awk '{print($1)}' | cut -d= -f2`
        HotspotIntMAC=( $HotspotIntMAC )
        HotspotIntMAC=${HotspotIntMAC[1]}
        sed -i -e "/$line/d" ./mac
        echo "$line $HotspotIntMAC $CurrentTime $CurrentCalc" >> mac
    fi
#Otherwise get all data, including hostpot mac
else
    ssh admin@$line ip hot host pr > hosts
    ssh admin@$line ip hot active pr > active
    ssh admin@$line ip hot print > hotspot
    ssh admin@$line inter pri deta > interfaces

    HotspotIntName=`cat hotspot | grep m | awk '{print($3)}'`
    HotspotIntMAC=`cat interfaces | grep -A 1 $HotspotIntName | awk '{print($1)}' | cut -d= -f2`
    HotspotIntMAC=( $HotspotIntMAC )
    HotspotIntMAC=${HotspotIntMAC[1]}
    echo "$line $HotspotIntMAC $CurrentTime $CurrentCalc" >> mac
fi


cat active | grep h | while read -r line ; do
    DeviceIP=`echo $line | awk '{print($4)}'`
    DeviceUptime=`echo $line | awk '{print($5)}'`

    if [[ $DeviceUptime == *"h"* ]];
    then
        UptimeH=`echo $DeviceUptime | cut -d 'h' -f 1`
    else
        UptimeH=0
        DeviceUptime=`echo "0h$DeviceUptime"`
    fi

    if [[ $DeviceUptime == *"s"* ]];
    then
        if [[ $DeviceUptime == *"m"* ]];
        then
            UptimeS=`echo $DeviceUptime | awk -F'[s]' '{print $1}'| awk -F'[m]' '{print $2}'`
        else
            UptimeS=`echo $DeviceUptime | awk -F'[s]' '{print $1}'| awk -F'[h]' '{print $2}'`
        fi
    else
        UptimeS=0
        DeviceUptime=`echo $DeviceUptime'0s'`
    fi

    if [[ $DeviceUptime == *"m"* ]];
    then
        UptimeM=`echo $DeviceUptime | grep -o -P '(?<=h).*(?=m)'`
    else
        UptimeM=0
    fi
    let UptimeCalc="$UptimeH * 3600 + $UptimeM * 60 + $UptimeS"
    let ConnCalc="$CurrentCalc - $UptimeCalc"
    ConnTime=`date -u -d @${ConnCalc} +%Y-%m-%d:%H:%M:%S`
    DeviceMAC=`cat hosts | grep "$DeviceIP " | awk '{print($3)}'`
    echo "$HotspotIntMAC,$DeviceMAC,$DeviceUptime,$ConnTime,$CurrentTime" >> output
done

cat hosts | grep 5m | while read -r line ; do
    DeviceMAC=`echo $line | awk '{print($3)}'`
    ConnStatus=`echo $line | awk '{print($2)}'`
    echo "$HotspotIntMAC,$DeviceMAC,$ConnStatus,unauthorised,$CurrentTime" >> output
done
done

#Delete all temporary files
rm -f interfaces
rm -f hotspot
rm -f active
rm -f hosts
