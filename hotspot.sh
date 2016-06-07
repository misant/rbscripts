#!/bin/bash
#################################
#       Bekhterev Evgeniy       #
#       ver 1.0                 #
#       07.06.2016              #
#       www.bekhterev.me        #
#################################
# script connects via ssh to remote mikrotik listed in ./rb file
# and outputs data collected
# output fields:
#hotspot mac, device mac, connection uptime/status, start time of connection, time of check

function get_hotspot_mac {
    #If there are no known macs list - create empty file
    [[ -f mac ]] || touch mac

    if grep -q "$1 " "mac"; then
        echo "Known IP $1, lets check how its old"
        HotspotIntMAC=`grep -m 1 "$1 " "mac" | awk '{print($3)}'`
        MACDate=`grep -m 1 "$1 " "mac" | awk '{print($4)}'`
        MACSecs=`grep -m 1 "$1 " "mac" | awk '{print($5)}'`
        if (( "$CurrentCalc - $MACSecs" > "86400" )); then
            ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no admin@$1 ip hot print > hotspot
            ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no admin@$1 inter pri deta > interfaces
            cat hotspot | grep m | awk '{print($3)}' | while read -r line; do
                HotspotIntName=$line
                HotspotIntMAC=`cat interfaces | grep -A 1 $HotspotIntName | awk '{print($1)}' | cut -d= -f2`
                HotspotIntMAC=( $HotspotIntMAC )
                HotspotIntMAC=${HotspotIntMAC[1]}
                HotspotSrv=`cat hotspot | grep $line | awk '{print($2)}'`
                sed -i -e "/$1 $HotspotSrv/d" ./mac
                echo "MAC is old, need to update"
                echo "$1 $HotspotSrv $HotspotIntMAC $CurrentTime $CurrentCalc" >> mac
            done
        else
            echo "MAC is ok, no need to update"
        fi
    else
        ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no admin@$1 ip hot print > hotspot
        ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no admin@$1 inter pri deta > interfaces
        cat hotspot | grep m | awk '{print($3)}' | while read -r line; do
            HotspotIntName=$line
            HotspotIntMAC=`cat interfaces | grep -A 1 $HotspotIntName | awk '{print($1)}' | cut -d= -f2`
            HotspotIntMAC=( $HotspotIntMAC )
            HotspotIntMAC=${HotspotIntMAC[1]}
            HotspotSrv=`cat hotspot | grep $line | awk '{print($2)}'`
            echo "Unknow IP $1, adding to base"
            echo "$1 $HotspotSrv $HotspotIntMAC $CurrentTime $CurrentCalc" >> mac
        done
    fi
}

function get_data {
    echo "Getting $1 hotspot active devices"
    ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no admin@$1 ip hot active pr > active
    echo "Getiing $1 hotspot hosts details"
    ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no admin@$1 ip hot host pr > hosts
}

function proc_active {
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
        DeviceSrv=`cat hosts | grep "$DeviceIP " | awk '{print($6)}'`
        HotspotIntMAC=`grep "$1 "  "mac" | grep $DeviceSrv  | awk '{print($3)}'`
        echo "$HotspotIntMAC,$DeviceMAC,$DeviceUptime,$ConnTime,$CurrentTime" >> output
    done
}

function proc_hosts {
    cat hosts | grep 5m | while read -r line ; do
        DeviceIP=`echo $line | awk '{print($4)}'`
        DeviceSrv=`cat hosts | grep "$DeviceIP " | awk '{print($6)}'`
        HotspotIntMAC=`grep "$1 "  "mac" | grep $DeviceSrv  | awk '{print($3)}'`
        DeviceMAC=`echo $line | awk '{print($3)}'`
        ConnStatus=`echo $line | awk '{print($2)}'`
        echo "$HotspotIntMAC,$DeviceMAC,$ConnStatus,unauthorised,$CurrentTime" >> output
    done
}

for RBIP in $(cat rb); do

    echo "Processing $RBIP"

    #Getting current date and time in seconds and in human readable formats
    CurrentCalc=`date +%s`
    CurrentTime=`date +%Y-%m-%d:%H:%M:%S`
    echo $CurrentTime

    #Get hotpost mac
    get_hotspot_mac $RBIP

    #Get data into active and hosts files
    get_data $RBIP

    #Process active and hosts files
    proc_active $RBIP
    proc_hosts $RBIP

done

#Delete temp files
rm -f hotspot
rm -f interfaces
rm -f active
rm -f hosts
