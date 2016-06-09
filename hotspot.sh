#!/bin/bash
#################################
#       Bekhterev Evgeniy       #
#       ver 1.2                 #
#       09.06.2016              #
#       www.bekhterev.me        #
#################################
# script connects via ssh to remote mikrotik listed in .//srv/hotspot/rb file
# and outputs data collected
# output fields:
#hotspot mac, device mac, connection uptime/status, start time of connection, time of check

function get_hotspot_mac {
    #If there are no known macs list - create empty file
    [[ -f /srv/hotspot/mac ]] || /bin/touch /srv/hotspot/mac

    if /bin/grep -q "$1 " "/srv/hotspot/mac"; then
        /bin/echo "Known IP $1, lets check how its old"
        HotspotIntMAC=`/bin/grep -m 1 "$1 " "/srv/hotspot/mac" | /usr/bin/awk '{print($3)}'`
        MACDate=`/bin/grep -m 1 "$1 " "/srv/hotspot/mac" | /usr/bin/awk '{print($4)}'`
        MACSecs=`/bin/grep -m 1 "$1 " "/srv/hotspot/mac" | /usr/bin/awk '{print($5)}'`
        if (( "$CurrentCalc - $MACSecs" > "86400" )); then
            /usr/bin/ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no admin@$1 ip hot print > /srv/hotspot/hotspot
            /usr/bin/ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no admin@$1 inter pri deta > /srv/hotspot/interfaces
            /bin/cat /srv/hotspot/hotspot | /bin/grep m | /usr/bin/awk '{print($3)}' | while read -r line; do
                HotspotIntName=$line
                HotspotIntMAC=`/bin/cat /srv/hotspot/interfaces | /bin/grep -A 1 $HotspotIntName | /usr/bin/awk '{print($1)}' | cut -d= -f2`
                HotspotIntMAC=( $HotspotIntMAC )
                HotspotIntMAC=${HotspotIntMAC[1]}
                HotspotSrv=`/bin/cat /srv/hotspot/hotspot | /bin/grep $line | /usr/bin/awk '{print($2)}'`
                /bin/sed -i -e "/$1 $HotspotSrv/d" /srv/hotspot/mac
                /bin/echo "MAC is old, need to update"

                if [[ ! $HotspotIntMAC ]]; then
                    /bin/echo "Error getting $1 MAC"
                fi

                if [[ $HotspotIntMAC ]]; then
                    /bin/echo "$1 $HotspotSrv $HotspotIntMAC $CurrentTime $CurrentCalc" >> /srv/hotspot/mac
                fi



            done
        else
            /bin/echo "MAC is ok, no need to update"
        fi
    else
        /usr/bin/ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no admin@$1 ip hot print > /srv/hotspot/hotspot
        /usr/bin/ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no admin@$1 inter pri deta > /srv/hotspot/interfaces
        /bin/cat /srv/hotspot/hotspot | /bin/grep m | /usr/bin/awk '{print($3)}' | while read -r line; do
            HotspotIntName=$line
            HotspotIntMAC=`/bin/cat /srv/hotspot/interfaces | /bin/grep -A 1 $HotspotIntName | /usr/bin/awk '{print($1)}' | cut -d= -f2`
            HotspotIntMAC=( $HotspotIntMAC )
            HotspotIntMAC=${HotspotIntMAC[1]}
            HotspotSrv=`/bin/cat /srv/hotspot/hotspot | /bin/grep $line | /usr/bin/awk '{print($2)}'`
            /bin/echo "Unknow IP $1, adding to base"
            if [[ ! $HotspotIntMAC ]]; then
                /bin/echo "Error getting $1 MAC"
            fi

            if [[ $HotspotIntMAC ]]; then
                /bin/echo "$1 $HotspotSrv $HotspotIntMAC $CurrentTime $CurrentCalc" >> /srv/hotspot/mac
            fi



        done
    fi
    /bin/rm -f /srv/hotspot/hotspot
    /bin/rm -f /srv/hotspot/interfaces
}

function get_data {
    /usr/bin/ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no admin@$1 "ip hot host pr; ip hot active pr" > /srv/hotspot/devices
    sed -n -e '1,/Flags: R - radius, B - blocked/w /srv/hotspot/hosts
    /Flags: R - radius, B - blocked/,$w /srv/hotspot/active' /srv/hotspot/devices
    /bin/rm -f /srv/hotspot/devices

}

function proc_active {
    /bin/cat /srv/hotspot/active | /bin/grep 'h\|45m\|30m' | while read -r line ; do
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
        DeviceMAC=`/bin/cat /srv/hotspot/hosts | /bin/grep "$DeviceIP " | /usr/bin/awk '{print($3)}'`
        DeviceSrv=`/bin/cat /srv/hotspot/hosts | /bin/grep "$DeviceIP " | /usr/bin/awk '{print($6)}'`
        HotspotIntMAC=`/bin/grep "$1 "  "/srv/hotspot/mac" | /bin/grep $DeviceSrv  | /usr/bin/awk '{print($3)}'`
        if [[ ! $DeviceMAC ]] ; then
            echo "Error getting $DeviceIP MAC or something went wrong, active device"
        fi
        if [[ ! $HotspotIntMAC ]] ; then
            echo "Error getting $1 MAC or something went wrong, active device"
        fi
        if [[ $DeviceMAC ]] || [[ $HotspotIntMAC ]]; then
            /bin/echo "$HotspotIntMAC,$DeviceMAC,$DeviceUptime,$ConnTime,$CurrentTime" >> /srv/hotspot/$OutputName.txt
        fi

    done
}

function proc_hosts {
    /bin/cat /srv/hotspot/hosts | /bin/grep ' 5m' | while read -r line ; do
        DeviceIP=`/bin/echo $line | /usr/bin/awk '{print($5)}'`
        DeviceSrv=`/bin/cat /srv/hotspot/hosts | /bin/grep "$DeviceIP " | /usr/bin/awk '{print($6)}'`
        HotspotIntMAC=`/bin/grep "$1 "  "/srv/hotspot/mac" | /bin/grep $DeviceSrv  | /usr/bin/awk '{print($3)}'`
        DeviceMAC=`/bin/echo $line | /usr/bin/awk '{print($3)}'`
        ConnStatus=`/bin/echo $line | /usr/bin/awk '{print($2)}'`
        if [[ ! $DeviceMAC ]] ; then
            echo "Error getting $DeviceIP MAC or something went wrong, nonactive device"
        fi
        if [[ ! $HotspotIntMAC ]] ; then
            echo "Error getting $1 MAC or something went wrong, nonactive device"
        fi
        if [[  $DeviceMAC ]] || [[ $HotspotIntMAC ]]; then
            /bin/echo "$HotspotIntMAC,$DeviceMAC,$ConnStatus,unauthorised,$CurrentTime" >> /srv/hotspot/$OutputName.txt
        fi

    done
    /bin/rm -f /srv/hotspot/active
    /bin/rm -f /srv/hotspot/hosts
}

echo "--------------STARTING-CHECK-------------------"

PingResult=`/bin/ping -c 5 10.0.0.1 | /bin/grep loss | /usr/bin/awk '{print $4}'`
if [ $PingResult -le 2 ]
   then
        echo "$PingResult of 5 pings returned and its not ok, restarting pptp"
        /usr/bin/poff
        /usr/bin/pon hotspot
        /sbin/route add -net 10.0.0.0/8 ppp0
    /bin/sleep 5
    else
        echo "$PingResult of 5 pings returned and that is ok"
fi


for RBIP in $(/bin/cat /srv/hotspot/rb); do


    #Getting current date and time in seconds and in human readable formats
    CurrentCalc=`date +%s`
    CurrentTime=`date +%Y-%m-%d:%H:%M:%S`
    FileName=`date +%Y.%m.%d.%H.%M.%S`
    OutputName=`date +%Y-%m-%d`
    /bin/echo "-----Start processing $RBIP-----$CurrentTime"

    #Get hotpost mac
    get_hotspot_mac $RBIP

    #Get data into active and hosts files
    get_data $RBIP

    #Process active and hosts files
    proc_active $RBIP
    proc_hosts $RBIP
    /bin/echo "-----Finish processing $RBIP-----"
done

echo "--------------END-OF-CHECK-------------------"

