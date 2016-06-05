#!/bin/sh

CurrentCalc=`date +%s`
CurrentTime=`date +%Y-%m-%d:%H:%M:%S`

echo $CurrentCalc
HotspotIntName=`cat hotspot | grep m | awk '{print($3)}'`
echo "Hotspot interface name = $HotspotIntName"
HotspotIntMAC=`cat interfaces | grep -A 1 $HotspotIntName | awk '{print($1)}' | cut -d= -f2`
HotspotIntMAC=( $HotspotIntMAC )
HotspotIntMAC=${HotspotIntMAC[1]}
#echo "Hotspot interface mac = $HotspotIntMAC" >> output
echo "Active connections" >> output
cat active | grep h | while read -r line ; do
    DeviceIP=`echo $line | awk '{print($4)}'`
    DeviceUptime=`echo $line | awk '{print($5)}'`
    UptimeH=`echo $DeviceUptime | awk -F'[h]' '{print $1}'`
    if [ "$UptimeH" == "$DeviceUptime" ]; then
        let UptimeH=0
        UptimeM=`echo $DeviceUptime | awk -F'[m]' '{print $1}'`
        UptimeS=`echo $DeviceUptime | awk -F'[s]' '{print $1}'| awk -F'[m]' '{print $2}'`
    else
        UptimeM=`echo $DeviceUptime | awk -F'[m]' '{print $1}'| awk -F'[h]' '{print $2}'`
        UptimeS=`echo $DeviceUptime | awk -F'[s]' '{print $1}'| awk -F'[m]' '{print $2}'`
    fi
    let UptimeCalc="$UptimeH * 3600 + $UptimeM * 60 + $UptimeS"
    let ConnCalc="$CurrentCalc - $UptimeCalc"
    ConnTime=`date -u -d @${ConnCalc}`
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
    echo "$HotspotIntMAC,$DeviceMAC,$ConnStatus,unautharised,$CurrentTime" >> output
done
