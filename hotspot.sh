#!/bin/bash
#################################
#       Bekhterev Evgeniy       #
#       ver 1.1                 #
#       07.06.2016              #
#       www.bekhterev.me        #
#################################
# script connects via ssh to remote mikrotik listed in .//root/script/rb file
# and outputs data collected
# output fields:
#hotspot mac, device mac, connection uptime/status, start time of connection, time of check

function get_hotspot_mac {
    #If there are no known macs list - create empty file
    [[ -f /root/script/mac ]] || /bin/touch /root/script/mac

    if /bin/grep -q "$1 " "/root/script/mac"; then
        /bin/echo "Known IP $1, lets check how its old"
        HotspotIntMAC=`/bin/grep -m 1 "$1 " "/root/script/mac" | /usr/bin/awk '{print($3)}'`
        MACDate=`/bin/grep -m 1 "$1 " "/root/script/mac" | /usr/bin/awk '{print($4)}'`
        MACSecs=`/bin/grep -m 1 "$1 " "/root/script/mac" | /usr/bin/awk '{print($5)}'`
        if (( "$CurrentCalc - $MACSecs" > "86400" )); then
            /usr/bin/ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no admin@$1 ip hot print > /root/script/hotspot
            /usr/bin/ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no admin@$1 inter pri deta > /root/script/interfaces
            /bin/cat /root/script/hotspot | /bin/grep m | /usr/bin/awk '{print($3)}' | while read -r line; do
                HotspotIntName=$line
                HotspotIntMAC=`/bin/cat /root/script/interfaces | /bin/grep -A 1 $HotspotIntName | /usr/bin/awk '{print($1)}' | cut -d= -f2`
                HotspotIntMAC=( $HotspotIntMAC )
                HotspotIntMAC=${HotspotIntOCMAC[1]}
                HotspotSrv=`/bin/cat /root/script/hotspot | /bin/grep $line | /usr/bin/awk '{print($2)}'`
                /bin/sed -i -e "/$1 $HotspotSrv/d" /root/script/mac
                /bin/echo "MAC is old, need to update"
                /bin/echo "$1 $HotspotSrv $HotspotIntMAC $CurrentTime $CurrentCalc" >> /root/script/mac
            done
        else
            /bin/echo "MAC is ok, no need to update"
        fi
    else
        /usr/bin/ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no admin@$1 ip hot print > /root/script/hotspot
        /usr/bin/ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no admin@$1 inter pri deta > /root/script/interfaces
        /bin/cat /root/script/hotspot | /bin/grep m | /usr/bin/awk '{print($3)}' | while read -r line; do
            HotspotIntName=$line
            HotspotIntMAC=`/bin/cat /root/script/interfaces | /bin/grep -A 1 $HotspotIntName | /usr/bin/awk '{print($1)}' | cut -d= -f2`
            HotspotIntMAC=( $HotspotIntMAC )
            HotspotIntMAC=${HotspotIntMAC[1]}
            HotspotSrv=`/bin/cat /root/script/hotspot | /bin/grep $line | /usr/bin/awk '{print($2)}'`
            /bin/echo "Unknow IP $1, adding to base"
            /bin/echo "$1 $HotspotSrv $HotspotIntMAC $CurrentTime $CurrentCalc" >> /root/script/mac
        done
    fi
}

function get_data {
    /bin/echo "Getting $1 hotspot active devices"
    /usr/bin/ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no admin@$1 ip hot active pr > /root/script/active
    /bin/echo "Getiing $1 /root/script/hotspot hosts details"
    /usr/bin/ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no admin@$1 ip hot host pr > /root/script/hosts
}

function proc_active {
    /bin/cat /root/script/active | /bin/grep h | while read -r line ; do
        DeviceIP=`/bin/echo $line | /usr/bin/awk '{print($4)}'`
        DeviceUptime=`/bin/echo $line | /usr/bin/awk '{print($5)}'`

        if [[ $DeviceUptime == *"h"* ]]; then
            UptimeH=`/bin/echo $DeviceUptime | cut -d 'h' -f 1`
        else
            UptimeH=0
            DeviceUptime=`/bin/echo "0h$DeviceUptime"`
        fi

        if [[ $DeviceUptime == *"s"* ]];  then
            if [[ $DeviceUptime == *"m"* ]]; then
                UptimeS=`/bin/echo $DeviceUptime | /usr/bin/awk -F'[s]' '{print $1}'| /usr/bin/awk -F'[m]' '{print $2}'`
            else
                UptimeS=`/bin/echo $DeviceUptime | /usr/bin/awk -F'[s]' '{print $1}'| /usr/bin/awk -F'[h]' '{print $2}'`
            fi
        else
            UptimeS=0
            DeviceUptime=`/bin/echo $DeviceUptime'0s'`
        fi

        if [[ $DeviceUptime == *"m"* ]]; then
            UptimeM=`/bin/echo $DeviceUptime | /bin/grep -o -P '(?<=h).*(?=m)'`
        else
            UptimeM=0
        fi

        let UptimeCalc="$UptimeH * 3600 + $UptimeM * 60 + $UptimeS"
        let ConnCalc="$CurrentCalc - $UptimeCalc"
        ConnTime=`date -u -d @${ConnCalc} +%Y-%m-%d:%H:%M:%S`
        DeviceMAC=`/bin/cat /root/script/hosts | /bin/grep "$DeviceIP " | /usr/bin/awk '{print($3)}'`
        DeviceSrv=`/bin/cat /root/script/hosts | /bin/grep "$DeviceIP " | /usr/bin/awk '{print($6)}'`
        HotspotIntMAC=`/bin/grep "$1 "  "/root/script/mac" | /bin/grep $DeviceSrv  | /usr/bin/awk '{print($3)}'`
        /bin/echo "$HotspotIntMAC,$DeviceMAC,$DeviceUptime,$ConnTime,$CurrentTime" >> /root/script/output
    done
}

function proc_hosts {
    /bin/cat /root/script/hosts | /bin/grep 5m | while read -r line ; do
        DeviceIP=`/bin/echo $line | /usr/bin/awk '{print($4)}'`
        DeviceSrv=`/bin/cat /root/script/hosts | /bin/grep "$DeviceIP " | /usr/bin/awk '{print($6)}'`
        HotspotIntMAC=`/bin/grep "$1 "  "/root/script/mac" | /bin/grep $DeviceSrv  | /usr/bin/awk '{print($3)}'`
        DeviceMAC=`/bin/echo $line | /usr/bin/awk '{print($3)}'`
        ConnStatus=`/bin/echo $line | /usr/bin/awk '{print($2)}'`
        /bin/echo "$HotspotIntMAC,$DeviceMAC,$ConnStatus,unauthorised,$CurrentTime" >> /root/script/output
    done
}

PingResult=`/bin/ping -c 5 10.0.0.1 | /bin/grep loss | /usr/bin/awk '{print $4}'`
if [ $PingResult -le 2 ]
   then
        /usr/bin/poff hotspot
        /usr/bin/pon hotspot
        /sbin/route add -net 10.0.0.0/8 ppp0
    sleep 5
fi


for RBIP in $(/bin/cat /root/script/rb); do

    /bin/echo "Processing $RBIP"

    #Getting current date and time in seconds and in human readable formats
    CurrentCalc=`date +%s`
    CurrentTime=`date +%Y-%m-%d:%H:%M:%S`
    /bin/echo $CurrentTime

    #Get hotpost mac
    get_hotspot_mac $RBIP

    #Get data into active and hosts files
    get_data $RBIP

    #Process active and hosts files
    proc_active $RBIP
    proc_hosts $RBIP

done

#Delete temp files
rm -f /root/script/hotspot
rm -f /root/script/interfaces
rm -f /root/script/active
rm -f /root/script/hosts
