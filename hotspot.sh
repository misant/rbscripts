#!/bin/bash

CurrentCalc=`date +%s`
CurrentTime=`date +%Y-%m-%d:%H:%M:%S`

cat list.txt | while read -r line ; do
[[ -f mac ]] || touch mac

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
        echo "Too old!"
        HotspotIntMAC=`cat interfaces | grep -A 1 $HotspotIntName | awk '{print($1)}' | cut -d= -f2`
        HotspotIntMAC=( $HotspotIntMAC )
        HotspotIntMAC=${HotspotIntMAC[1]}
        sed -i -e "/$line/d" ./mac
        echo "$line $HotspotIntMAC $CurrentTime $CurrentCalc" >> mac

    else
        echo "Mac is already known, $HotspotIntMAC was written $MACDate"
    fi
else
    ssh admin@$line ip hot host pr > hosts
    ssh admin@$line ip hot active pr > active
    ssh admin@$line ip hot print > hotspot
    ssh admin@$line inter pri deta > interfaces

    HotspotIntName=`cat hotspot | grep m | awk '{print($3)}'`
    echo "Hotspot interface name = $HotspotIntName"
    HotspotIntMAC=`cat interfaces | grep -A 1 $HotspotIntName | awk '{print($1)}' | cut -d= -f2`
    HotspotIntMAC=( $HotspotIntMAC )
    HotspotIntMAC=${HotspotIntMAC[1]}
    echo "$line $HotspotIntMAC $CurrentTime $CurrentCalc" >> mac
    echo "Mac is uknown"

fi

echo "Active connections" >> output
cat active | grep h | while read -r line ; do
    DeviceIP=`echo $line | awk '{print($4)}'`
    DeviceUptime=`echo $line | awk '{print($5)}'`
    echo "DeviceUptime = $DeviceUptime"



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
    echo $ConnTime
    DeviceMAC=`cat hosts | grep "$DeviceIP " | awk '{print($3)}'`
    echo "Device IP = $DeviceIP"
    echo "Device uptime = $DeviceUptime"
    echo "Device MAC = $DeviceMAC"
    echo "$HotspotIntMAC,$DeviceMAC,$DeviceUptime,$ConnTime,$CurrentTime" >> output
done
echo "Not authenticated" >> output
cat hosts | grep 5m | while read -r line ; do
    DeviceMAC=`echo $line | awk '{print($3)}'`
    ConnStatus=`echo $line | awk '{print($2)}'`
    echo "Device MAC = $DeviceMAC"
    echo "Device MAC = $ConnStatus"
    echo "$HotspotIntMAC,$DeviceMAC,$ConnStatus,unautharized,$CurrentTime" >> output
done
done

rm -f interfaces
rm -f hotspot
rm -f active
rm -f hosts
