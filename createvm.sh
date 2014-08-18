#!/bin/bash 
 
###################
# Variables #
###################
 
conf="/opt/createvm/createvm.conf"
txtb='\e[0;34m' # Blue text
txtr='\e[1;31m' # Red Text 
txt='\e[0m' # This will reset text back to normal
EPOCH=`date +%s` # Date for DNS record updates 
 
###################
# Functions #
###################
 
checkrunning () {
# Check to see if another instance of the script is running. If it is exit. If not, write a lock file.
if [ -f /tmp/program.lock ] ; then 
# the lock file already exists, so what to do? 
if [ "$(ps -p `cat /tmp/program.lock` | wc -l)" -gt 1 ]; then 
# process is still running 
echo -e "$txtr$0: Another instance of createvm is already running, try again later$txt" 
ps -p `cat /tmp/program.lock` 
exit 0 
else 
# process not running, but lock file not deleted? 
rm -rf /tmp/program.lock 
fi 
fi 
echo $$ > /tmp/program.lock 
} 
 
getconf () {
# Source the config file to get the install dir location. It should be /opt/createvm/createvm.conf
if [ -f "$conf" ];then 
source $conf 
if [[ -n $1 ]];then 
clfile="$1/clusters.conf" 
prodfile="$1/products.conf" 
else 
clfile="$BASEDIR/clusters.conf" 
prodfile="$BASEDIR/products.conf" 
fi 
else 
echo -e $txtr"ERROR! $conf does not exist. You can run "createvm.sh -c" to create a blank configuration file to edit."$txt
exit 
fi 
} 
 
writeconf () {
# if -c is given as an arguement. Write a blank conf file. It checks to see if is there and asks for confirmation to overwrite if it is.
if [ -f "$conf" ];then 
while true 
do 
echo -e $txtr"$conf already exists! Do you want to overwrite it? y/n"$txt 
read -e overwrite 
if [ "$overwrite" == "y" ];then 
break 
elif [ "$overwrite" == "n" ];then 
exit 
fi 
done 
fi 
 
if [ ! -d /opt/createvm ];then
mkdir /opt/createvm 
fi 
echo "# Location of the createvm script and its config files" > $conf
echo "BASEDIR=/usr/local/bin/createvm" >> $conf 
echo "" >> $conf 
echo "# Where to store the error log files for newly created VMs" >> $conf
echo "LOG=/mnt/data/vmlogs/" >> $conf 
echo "" >> $conf 
echo "# Temporary location for the mac files" >> $conf 
echo "MACFILEDIR=/mnt/data/ipinfo/" >> $conf 
echo "" >> $conf 
echo "# Password to connect to the Master PowerDNS database." >> $conf 
echo "MYSQLPW=\"mysqlpasswdchangeme\"" >>$conf 
echo "$conf has been written. Please edit it with the appropriate information."
exit 
} 
 
getcluster () {
# Read the clusters.conf file in the basedir. Pull out all the clusters in the file. It will be any line that starts with a "[" to designate a valid cluster
parsefile=$clfile 
prompt="Select the the number for the corresponding cluster for this VM." 
clearlist 
parselist 
if [ -z "${list[1]}" ]; then 
echo -e $txtr"No valid clusters found in ${clfile}! Please check that the file exists and that they syntax is correct."$txt 
exit 1 
fi 
if [ -z "${list[2]}" ]; then 
findstr=${list[1]} 
else 
displaylist 
findstr=${list[$x]} 
fi 
sourcefile 
DGATEWAY=$GATEWAY 
} 
 
getnetapp () {
# THIS IS NOT USED RIGHT NOW
# This has been deprecated but I am leaving it in here in case I need it in the future.
# If there is more then 1 storage option, this will ask the user to choose where to put /mnt/data
if [ -n "${NETAPP[2]}" ];then 
while true 
do 
clear 
num=1 
until [ -z "${NETAPP[$num]}" ] 
do 
nip=`echo ${NETAPP[$num]}|cut -d , -f 1` 
ndesc=`echo ${NETAPP[$num]}|cut -d , -f 2` 
echo $num". ${nip}: $ndesc" 
(( num ++ )) 
done 
echo -e $txtr$errmsg$txt 
echo -e $txtb"Select which location to store /mnt/data."$txt 
read -e x 
if [ -z "${NETAPP[$x]}" ];then 
errmsg="Invalid Choice, choose again!" 
else 
break 
fi 
done 
else 
x=1 
fi 
 
NETAPPDESC=`echo ${NETAPP[$x]}|cut -d , -f 2`
clientvol=`echo ${NETAPP[$x]}|cut -d , -f 3` 
dbvol=`echo ${NETAPP[$x]}|cut -d , -f 4` 
sandev=`echo ${NETAPP[$x]}|cut -d , -f 8` 
if [ -z `echo ${NETAPP[$x]}|cut -d , -f 5` ];then
NETAPPDB=`echo ${NETAPP[$x]}|cut -d , -f 1` 
else 
NETAPPDB=`echo ${NETAPP[$x]}|cut -d , -f 5` 
fi 
if [ -z `echo ${NETAPP[$x]}|cut -d , -f 6` ];then
NETAPPAUTO=`echo ${NETAPP[$x]}|cut -d , -f 1` 
else 
NETAPPAUTO=`echo ${NETAPP[$x]}|cut -d , -f 6` 
fi 
if [ -z `echo ${NETAPP[$x]}|cut -d , -f 7` ];then
NETAPPDBAUTO=$NETAPPAUTO 
else 
NETAPPDBAUTO=`echo ${NETAPP[$x]}|cut -d , -f 7`
fi 
NETAPP=`echo ${NETAPP[$x]}|cut -d , -f 1` 
 
clearlist
} 
 
inputvm () {
# This will ask the user to input all the needed information for the VM
#while loop 
while true 
do 
#getnetapp 
getname 
getdescription 
getprod 
getlevel 
getips 
nfsndns 
until [ "$confirm" == "y" ] || [ "$confirm" == "n" ] 
do 
displayvm 
echo -e $txtr$errmsg$txt 
echo -e $txtb"Is this information correct? Confirming will start the creation process. y/n"$txt
read -e confirm 
errmsg="Invalid choice! Choose again." 
done 
if [ "$confirm" == "y" ];then 
GATEWAY=$DGATEWAY 
break 
else 
errmsg="" 
confirm="" 
DGATEWAY=$GATEWAY 
ETH2="" 
ETH2_NETMASK="" 
DDNS="" 
DNFS="" 
DNS="" 
NFS="" 
fi 
done 
 
 
displayvm
} 
 
displayvm () {
# Function to list the VM options.
clear 
echo "" 
echo " Cluster: $CLUSTER" 
echo " VM Name: $VMNAME" 
echo " Description: $DESC" 
echo " Product: $prodid" 
echo "Hosting Level: $LEVEL: $CORES cores, $DRAM MB memory"
echo " Private IP: $ETH0" 
echo " SAN IP: $ETH1" 
echo " Public IP: $ETH2 / $ETH2_NETMASK" 
echo " GATEWAY: $DGATEWAY" 
echo -e "Configure NFS: $txtr$DNFS$txt" 
echo " Storage: $netapp_export_ip $NETAPPDESC" 
echo -e " Update DNS: $txtr$DDNS$txt" 
echo "" 
} 
 
vm_exists () {
# Function to see if a vmname exists. This looks for subset names. So if you search for test, and a vm named test1 is there. This function will allow it not to pop as a false positive 
fail="" 
CHECKVM=`/usr/bin/curl -1 --silent -1 -S -k -X GET -H "Accept: application/xml" -u $RUID $RHEVM?search={$VMNAME}|grep "<name>"|cut -d ">" -f 2|cut -d "<" -f 1` 
for i in $(echo $CHECKVM);do 
if [[ $i = $VMNAME ]];then 
fail="yes" 
GETVM=$i 
break 
fi 
done 
if [[ -n $fail ]];then 
return 0 
else 
return 1 
fi 
} 
 
get_vmid () {
get_vmids=`/usr/bin/curl -1 --silent -S -k -X GET -H "Accept: application/xml" -u $RUID $RHEVM?search={$VMNAME}|grep "vm href"|cut -d \" -f 2|cut -d / -f 4`
for i in $(echo $get_vmids);do 
vmidtest=`/usr/bin/curl -1 --silent -1 -S -k -X GET -H "Accept: application/xml" -u $RUID $RHEVM$i|grep "<name>"|cut -d ">" -f 2|cut -d "<" -f 1` 
if [[ $vmidtest == "$VMNAME" ]];then 
VMID=$i 
fi 
done 
if [[ -z $VMID ]];then 
echo -e $txtr"Failed to get the vmid for $VMNAME"$txt 
exit 
fi 
} 
 
getname () {
# Get the VMNAME and make sure that VM doesn't exist already
errmsg="" 
while true 
do 
displayvm 
echo -e $txtr$errmsg$txt 
echo -e $txtb"Enter the VM name. For example: rl01-v0999"$txt
read -e VMNAME 
# Check to see if the vm is already in rhev manager 
if [[ $(echo $VMNAME|grep "^$vm_name_template") ]] || [[ -n $allow_name ]];then
if vm_exists; then 
errmsg="$VMNAME already exists! Please select another" 
else 
break 
fi 
else 
errmsg="The vm name needs to start with $vm_name_template" 
fi 
done 
errmsg="" 
} 
 
getdescription () {
# Get the description of the VM
displayvm 
echo -e $txtb"Enter the description of the VM. For example: example.domain.com "$txt
read -e DESC 
} 
 
getprod () {
# read the products.conf file and pull a list of products available.
parsefile=$prodfile 
prompt="Select the number for the corresponding product for this VM."
clearlist 
parselist 
displaylist 
prodid=${list[$x]} 
} 
 
getlevel () {
# Parse the products.conf file for the available levels inside the selected product
prompt="Select the number for the corresponding level for this VM." 
clearlist 
parsefile=$prodfile 
findstr=$prodid 
parsesublist 
displaylist 
LEVEL=${list[$x]} 
clearlist 
findsubstr=$LEVEL 
sourcesubfile 
DRAM=$(($RAM / 1048576)) 
DESC="$prodid-$LEVEL $DESC" 
} 
 
parselist () {
# This is a generic loop to parse the config files. It generates an array from which the selection is made from. 
# $parsefile must be set prior to calling this function. 
num=1 
exec 3< $parsefile 
while read line <&3 
do 
testline=`echo $line|grep '^\['` 
if [ -n "$testline" ];then 
list[$num]=`echo $testline|cut -d [ -f 2|cut -d ] -f 1` 
(( num++ )) 
fi 
done 
} 
 
clearlist () {
# Blanks out the array used for grabbing the lists to be displayed.
num=1 
until [ -z "${list[$num]}" ] 
do 
list[$num]="" 
(( num++ )) 
done 
} 
 
parsesublist () {
# This is a generic loop to parse the config files. It generates an array from which the selection is made from. 
# $parsefile must be set prior to calling this function. 
num=1 
foundit="" 
exec 3< $parsefile 
while read line <&3 
do 
startstanza=`echo $line|grep '^\['` 
startsubstanza=`echo $line|grep '^\{'` 
endstanza=`echo $line|grep '^\]'` 
searchstr=`echo $line|cut -d [ -f 2|cut -d ] -f 1` 
if [ -n "$foundit" ];then 
if [ -n "$startstanza" ];then 
break 
else 
if [ -n "$startsubstanza" ];then 
list[$num]=`echo $line|cut -d \{ -f 2|cut -d \} -f 1` 
(( num++ )) 
fi 
fi 
fi 
if [ -n "$startstanza" ] && [ "$searchstr" == "$findstr" ];then 
foundit=yes 
fi 
done 
} 
 
displaylist () {
# This will loop thru what array was snagged and display it on screen to offer a choice.
while true 
do 
clear 
num=1 
until [ -z "${list[$num]}" ] 
do 
echo $num". "${list[$num]} 
(( num ++ )) 
done 
echo -e $txtr$errmsg$txt 
echo -e $txtb$prompt$txt 
read -e x 
if [ -z "${list[$x]}" ];then 
errmsg="Invalid Choice, choose again!" 
else 
break 
fi 
done 
} 
 
sourcefile () {
foundit="" 
exec 3< $parsefile
while read line <&3
do 
startstanza=`echo $line|grep '^\['`
searchstr=`echo $line|cut -d [ -f 2|cut -d ] -f 1`
comment=`echo $line|grep '^\#'` 
if [ -n "$foundit" ];then 
if [ -n "$startstanza" ];then 
break 
else 
if [ -z "$comment" ];then 
echo $line >> /tmp/srcfile.out 
fi 
fi 
fi 
if [ -n "$startstanza" ] && [ "$searchstr" == "$findstr" ];then
foundit="yes" 
fi 
done 
source /tmp/srcfile.out 
rm -f /tmp/srcfile.out 
findstr="" 
} 
 
sourcesubfile () {
foundit="" 
founditsub="" 
exec 3< $parsefile
while read line <&3
do 
startstanza=`echo $line|grep '^\['`
startsubstanza=`echo $line|grep '^\{'`
searchstr=`echo $line|cut -d [ -f 2|cut -d ] -f 1`
searchsubstr=`echo $line|cut -d { -f 2|cut -d } -f 1`
comment=`echo $line|grep '^\#'` 
if [ -n "$foundit" ];then 
if [ -n "$founditsub" ];then 
if [ -n "$startstanza" ];then 
break 
fi 
if [ -n "$startsubstanza" ];then 
break 
else 
if [ -z "$comment" ];then 
echo $line >> /tmp/srcfile.out 
fi 
fi 
fi 
if [ -n "$startsubstanza" ] && [ "$searchsubstr" == "$findsubstr" ];then
founditsub="yes" 
fi 
fi 
if [ -n "$startstanza" ] && [ "$searchstr" == "$findstr" ];then 
foundit="yes" 
fi 
done 
source /tmp/srcfile.out 
rm -f /tmp/srcfile.out 
findstr="" 
findsubstr="" 
} 
 
getips () {
# Input the private and public IPs. It will automatically determine san IP
errmsg="" 
while true 
do 
displayvm 
echo -e $txtr$errmsg$txt 
echo -e $txtb"Enter the VMPrivate IP address. For example 10.$coct2.$coct3l.??."$txt
read -e ETH0 
OCT1=`echo $ETH0 | cut -d '.' -f 1` 
OCT2=`echo $ETH0 | cut -d '.' -f 2` 
OCT3=`echo $ETH0 | cut -d '.' -f 3` 
OCT4=`echo $ETH0 | cut -d '.' -f 4` 
if [ "$OCT1" != "10" ];then 
errmsg="The 1st octet must be 10." 
ETH0="" 
else 
if [ "$OCT2" != "$coct2" ];then 
errmsg="The 2nd octet must be $coct2." 
ETH0="" 
else 
if [ "$OCT3" -ge "$coct3l" ] && [ "$OCT3" -le "$coct3h" ];then 
if [ "$OCT4" -gt "255" ] || [ "$OCT4" == "" ];then 
errmsg="The 4th octet cannot be greater then 255!" 
ETH0="" 
else 
break 
fi 
else 
errmsg="The 3rd octet must be a range of $coct3l-$coct3h." 
ETH0="" 
fi 
fi 
fi 
done 
errmsg="" 
if [ "$coct2" == "50" ];then 
ETH1="10.52.$OCT3.$OCT4" 
else 
o=$(($OCT3 - 16)) 
ETH1="$ETH1$o.$OCT4" 
fi 
 
#Set the reverse DNS setting for the DNS update
RDNS="${OCT4}.${OCT3}${RDNS}" 
# Set the correct domain. This is an entry needed in the DNS database.
if [ "$OCT2" == "50" ]; then 
case $OCT3 in 
1) DOMAIN="3";; # 10.50.1.x 
2) DOMAIN="8";; # 10.50.2.x 
5) DOMAIN="2";; # 10.50.5.x 
6) DOMAIN="7";; # 10.50.6.x 
7) DOMAIN="5";; # 10.50.7.x 
20) DOMAIN="10";; # 10.50.20.x 
21) DOMAIN="11";; # 10.50.21.x 
22) DOMAIN="12";; # 10.50.22.x 
23) DOMAIN="13";; # 10.50.23.x 
24) DOMAIN="14";; # 10.50.24.x 
25) DOMAIN="15";; # 10.50.25.x 
*) echo "$IP is not valid." 
exit;; 
esac 
elif [ "$OCT2" == "55" ]; then 
DOMAIN="9" 
else 
echo -e $txtr"The 2nd octet of $OCT2 is invalid!$txt" 
exit 
fi 
 
displayvm
echo -e $txtb"Enter the public IP address if there should be one, otherwise hit enter."$txt
read -e ETH2 
if [ -n "$ETH2" ];then 
displayvm 
echo -e $txtb"Enter the Public IP NETMASK"$txt 
read -e ETH2_NETMASK 
displayvm 
echo -e $txtb"Enter the Public IP GATEWAY"$txt 
read -e DGATEWAY 
if [ -n "$NAT_IP" ];then 
displayvm 
echo -e $txtr"NOTICE! ${txtb}This server uses a NAT ip for the public ip. Please input the ip to be used in DNS"$txt
read -e NAT_ETH2 
fi 
fi 
} 
 
nfsndns () {
# if the force options is choosen at the command line, then the option to NOT create nfs mounts is forced.
if [ -z "$DNFS" ];then 
# until [ "$NFS" == "y" ] || [ "$NFS" == "n" ] 
while true 
do 
displayvm 
echo -e $txtr$errmsg$txt 
echo -e $txtb"Do you want to create the nfs shares? y/n"$txt 
read -e NFS 
errmsg="Invalid choice. Choose again." 
if [ "$NFS" == "y" ];then 
checkqtree 
if [ -z "$foundq" ];then 
DNFS="YES" 
break 
else 
echo -e ${txtr}${clienttreemsg}${txt} 
echo -e ${txtr}${dbtreemsg}${txt} 
echo "" 
echo -e $txtr"Press enter to continue or control-c to exit. If you continue, no new qtrees will be made and the vm will not configure the database upon startup."$txt 
read continue 
NFS="" 
DNFS="NO" 
break 
fi 
else 
NFS="" 
DNFS="NO" 
break 
fi 
done 
fi 
errmsg="" 
until [ "$DNS" == "y" ] || [ "$DNS" == "n" ] 
do 
displayvm 
echo -e $txtr$errmsg$txt 
echo -e $txtb"Do you want to add the DNS records for this VM? y/n"$txt 
read -e DNS 
errmsg="Invalid choice. Choose again." 
done 
if [ "$DNS" == "n" ];then 
DNS="" 
DDNS="NO" 
else 
DDNS="YES" 
fi 
errmsg="" 
} 
 
checkqtree () {
foundq="" 
vol=`echo $clientvol|cut -d "/" -f 3`
qcheck=`ssh $netapp_auto_ip qtree status $vol | grep -w $VMNAME | cut -d " " -f 2`
for q in $qcheck 
do 
if [ "$q" == "$VMNAME" ];then 
foundq="yes" 
clienttreemsg="$VMNAME has a qtree on $netapp_auto_ip for $vol" 
break 
fi 
done 
 
vol=`echo $dbvol|cut -d "/" -f 3`
qcheck=`ssh $netapp_auto_ip qtree status $vol | grep -w $VMNAME | cut -d " " -f 2`
for q in $qcheck 
do 
if [ "$q" == "$VMNAME" ];then 
foundq="yes" 
dbtreemsg="$VMNAME has a qtree on $netapp_auto_ip for $vol" 
break 
fi 
done 
 
vol=`echo $statevol|cut -d "/" -f 3`
qcheck=`ssh $netapp_auto_ip qtree status $vol | grep -w $VMNAME | cut -d " " -f 2`
for q in $qcheck 
do 
if [ "$q" == "$VMNAME" ];then 
foundq="yes" 
dbtreemsg="$VMNAME has a qtree on $netapp_auto_ip for $vol" 
break 
fi 
done 
 
}
 
addnic () {
#Function that adds a nic device to the VM. Must pass eth device name i.e. eth0 and the network name that is stored as a variable i.e. $eth0name
echo "" >> $LOG 
echo "" >> $LOG 
echo "Adding $1 for network $2 to $VMNAME" >> $LOG 
/usr/bin/curl -1 --silent -S -k -X POST -H "Accept: application/xml" -H "Content-Type: application/xml" -u $RUID -d "<nic><name>$1</name><network><name>$2</name></network></nic>" $RHEVM$VMID/nics >> $LOG 2>&1 
sleep 1 
} 
 
editnic () {
#Function that edits a nic device on the VM. Must pass eth device name i.e. eth0, the network name i.e vmprivate, the mac address, and the "nic href" of the nic device
# pass 3 variables 
#1. What to name the device. i.e. eth0 
#2. What network to use on the device. i.e. vmprivate or scalestorage 
#3. The ID number for the nic, so we know which we are changing. 
echo "" >> $LOG 
echo "Changing $1 to $2 and $3" >> $LOG 
# Old method. No longer need to change the mac address 
#/usr/bin/curl -1 --silent -S -k -X PUT -H "Accept: application/xml" -H "Content-Type: application/xml" -u $RUID -d "<nic><name>$1</name><network><name>$2</name></network><mac address=\"$3\"/></nic>" $RHEVM$VMID/nics/$4 >> $LOG 2>&1 
/usr/bin/curl -1 --silent -S -k -X PUT -H "Accept: application/xml" -H "Content-Type: application/xml" -u $RUID -d "<nic><name>$1</name><network><name>$2</name></network></nic>" $RHEVM$VMID/nics/$3 >> $LOG 2>&1 
sleep 1 
} 
 
createvm () {
LOG="$LOG$VMNAME.log"
if [ -a "$LOG" ];then
rm -f $LOG 
fi 
# Speaks to the REST / rhev API to add the new vm.
/usr/bin/curl -1 -silent -S -k -X POST -H "Accept: application/xml" -H "Content-Type: application/xml" -u $RUID -d "<vm><name>$VMNAME</name><description>$DESC</description><type>server</type><memory>$RAM</memory><memory_policy><guaranteed>$GUARANTEED</guaranteed></memory_policy><cpu><topology cores=\"$CORES\" sockets=\"$SOCKETS\"/></cpu><cluster><name>$CLUSTER</name></cluster><template><name>$IMAGENAME</name></template><disks><clone>true</clone></disks></vm>" $RHEVM >> $LOG 2>&1 
echo "/usr/bin/curl -1 -silent -S -k -X POST -H \"Accept: application/xml\" -H \"Content-Type: application/xml\" -u $RUID -d \"<vm><name>$VMNAME</name><description>$DESC</description><type>server</type><memory>$RAM</memory><memory_policy><guaranteed>$GUARANTEED</guaranteed></memory_policy><cpu><topology cores=\"$CORES\" sockets=\"$SOCKETS\"/></cpu><cluster><name>$CLUSTER</name></cluster><template><name>$IMAGENAME</name></template><disks><clone>true</clone></disks></vm>\" $RHEVM" >> $LOG 2>&1 
echo -n "Working." 
attempts=0 
while true;do 
echo -n "." 
sleep 5 
if vm_exists;then 
get_vmid 
echo 
break 
fi 
if [[ $attempts -gt 10 ]];then 
break 
fi 
(( attempts++ )) 
done 
 
if [ -n "$VMID" ];then 
echo -e $txtb"$VMNAME was created with a VMID of $VMID."$txt
else 
echo -e $txtr"The VM was not created, please check the $LOG file for errors!$txt"
exit 
fi 
 
echo ""
echo -e $txtb"The vm image is copying, this may take a few minutes. Please wait."$txt
#Waiting till the vm image is done copying so the nics can be added. 
until [ -n "$VMSTATE" ]; do 
printf . 
sleep 5 
VMSTATE=`/usr/bin/curl -1 --silent -S -k -X GET -H "Accept: application/xml" -u $RUID $RHEVM$VMID|grep "state" |grep "down"`
done 
echo "" 
 
echo -e $txtb"Configuring the network devices."$txt
#Add 3 network devices 
addnic eth00 $eth0name 
addnic eth10 $eth1name 
addnic eth20 $eth2name 
 
#Get a list of the mac addresses so we can sort them. The next serveral lines with network devices has to be done because rhev manager is horrible about picking out mac addresses. the eth0 device MUST be the lowest numerical device because the rhel client will pick the lowest as eth0. This has to be in place for networking to work properly for the firstboot script. 
maclist=`/usr/bin/curl -1 --silent -S -k -X GET -H "Accept: application/xml" -u $RUID $RHEVM$VMID/nics |grep mac|cut -d \" -f 2` 
sleep 1 
#Get a list of the <nic href> 
nicid=`/usr/bin/curl -1 --silent -S -k -X GET -H "Accept: application/xml" -u $RUID $RHEVM$VMID/nics | grep "nic href"| cut -d \" -f 4` 
 
#Now write the nic devices out in the proper order.
editnic eth0 $eth0name `echo $nicid|cut -d " " -f 1`
editnic eth1 $eth1name `echo $nicid|cut -d " " -f 2`
editnic eth2 $eth2name `echo $nicid|cut -d " " -f 3`
} 
 
createmacfile () {
# Collects the info for the firstboot script and uploads it to the satellite server.
# Need to get the mac address for eth0 so we can create the file with the correct name
# remove the : and make all the letters uppercase 
#MAC=`echo $MAC | sed 's/[^a-zA-Z0-9]//g' | tr '[:lower:]' '[:upper:]'` 
MAC=`echo $maclist|cut -d " " -f 1` 
MAC=`echo $MAC|sed s/://g| tr '[:lower:]' '[:upper:]'` 
NEWROOTHASH=`grep '^root:' /etc/shadow` 
 
# Mark satellite activation key as null if it is set to nothing in the configuration file
if [[ -z $register_sat ]];then 
ACTKEY="" 
fi 
 
MACFILE="$MACFILEDIR${MAC}.cfg"
cat <<EOF > $MACFILE 
VMNAME=$VMNAME 
VMHOSTNAME=${VMNAME}.rlem.net 
ETH0=$ETH0 
ETH0_NETMASK=$ETH0_NETMASK 
ETH1=$ETH1 
ETH1_NETMASK=$ETH1_NETMASK 
ETH2=$ETH2 
ETH2_NETMASK=$ETH2_NETMASK 
GW=$GATEWAY 
NFS=$NFS 
NETAPP=$netapp_export_ip 
NETAPPDB=$netapp_export_ip 
MNTBACK=$MNTBACK 
REMOTE_SYSLOG=$REMOTE_SYSLOG 
NS1=$NS1 
NS2=$NS2 
ACTKEY=$ACTKEY 
install_puppet=$install_puppet 
NEWROOTHASH='$NEWROOTHASH' 
clientvol=$clientvol 
dbvol=$dbvol 
varvol=$varvol 
statevol=$statevol 
BINDMOUNTS=$BINDMOUNTS 
SETTIME=$SETTIME 
HOSTINGLINK=$HOSTINGLINK 
RUNFIRSTBOOT=$RUNFIRSTBOOT 
NODB=$NODB 
DESC='$DESC' 
CLUSTER_VERS=$CLUSTER_VERS 
EOF 
 
echo 
echo -e $txtb"Uploading $MACFILE to the satellite server. If this fails, manually put the file in /var/www/html/ipinfo on the satellite server or the vm will not configure properly. \n"$txt 
 
if [ -n "$SSHKEYFILE" ];then
scp -i $SSHKEYFILE $MACFILE $SSHUSERID@${SAT}:$SATMACPATH
checkkeyfile=`ssh -i $SSHKEYFILE ${SSHUSERID}@${SAT} ls $SATMACPATH|grep ${MAC}.cfg`
else 
scp $MACFILE ${SAT}:$SATMACPATH 
checkkeyfile=`ssh $SAT ls $SATMACPATH|grep ${MAC}.cfg` 
fi 
if [ -z "$checkkeyfile" ];then 
echo -e $txtr"The macfile was not uploaded properly! Copy the file $MACFILE to ${SAT} in the ${SATMACPATH} dir before starting the VM! \n"$txt 
fi 
 
echo
if [ -n "$ERR" ]; then
cat $LOG 
echo 
echo -e $txtr"*******************************************************************************"$txt
echo -e $txtr"There was a problem with creating the VM, please check $LOG for errors \n"$txt 
fi 
} 
 
createdns () {
QUERY=`mysql -u pdns_intra -h $DNSDBHOST --password=$MYSQLPW pdns_intra -e "select content from pdns_intra.records where name='${VMNAME}.rhev.intra';"`
 
# Look to see if the rhev.intra record exists, if it doesn't, then add it.
if [ -z "$QUERY" ]; then 
echo "Updating rhev.intra" 
mysql -u pdns_intra -h $DNSDBHOST --password=$MYSQLPW pdns_intra -e "insert into records (domain_id,name,type,content,ttl,prio,change_date) values (1,'${VMNAME}.rhev.intra','A','${ETH0}',86400,0,${EPOCH});" 
echo 
else 
echo -e $txtr"The record for $VMNAME.rhev.intra already exists. Not updating!"$txt 
fi 
#update the query for reverse dns 
QUERY=`mysql -u pdns_intra -h $DNSDBHOST --password=$MYSQLPW pdns_intra -e "select content from pdns_intra.records where content='${VMNAME}.rhev.intra';"` 
 
# Look to see if the Reverse DNS record exists, if it doesn't, then add it.
if [ -z "$QUERY" ]; then 
echo "Updating Reverse DNS" 
mysql -u pdns_intra -h $DNSDBHOST --password=$MYSQLPW pdns_intra -e "insert into records (domain_id,name,type,content,ttl,prio,change_date) values ('${DOMAIN}','${RDNS}','PTR','${VMNAME}.rhev.intra',86400,0,${EPOCH});" 
echo 
else 
echo -e $txtr"The reverse record for $VMNAME.rhev.intra already exists. Not updating!"$txt 
fi 
 
# Update the query for rlem.net
QUERY=`mysql -u pdns_external -h $DNSDBHOST --password=$MYSQLPW pdns_external -e "select content from pdns_external.records where name='${VMNAME}.rlem.net';"`
 
# Check to see if there is a public record to update
if [ -n "$ETH2" ];then 
# Look to see if the rlem.net record exists, if it doesn't, then add it.
if [ -z "$QUERY" ]; then 
echo "Updating rlem.net" 
if [ -z "$NAT_IP" ];then 
mysql -u pdns_external -h $DNSDBHOST --password=$MYSQLPW pdns_external -e "insert into records (domain_id,name,type,content,ttl,prio,change_date) values (1,'${VMNAME}.rlem.net','A','${ETH2}',86400,0,${EPOCH});" 
else 
mysql -u pdns_external -h $DNSDBHOST --password=$MYSQLPW pdns_external -e "insert into records (domain_id,name,type,content,ttl,prio,change_date) values (1,'${VMNAME}.rlem.net','A','${NAT_ETH2}',86400,0,${EPOCH});" 
fi 
echo 
else 
echo -e $txtr"The record for $VMNAME.rhev.intra already exists. Not updating!"$txt 
fi 
fi 
} 
 
createsan () {
LOG="$LOG$VMNAME.log"
# Add the qtree's and exports to the netapp for the new VM.
 
# This must be done because the old rl01 netapp is on the rhevm network instead of the san network
#if [ "$sandev" == "eth0" ];then 
if [[ -n $no_san_network ]];then 
san_ip=$ETH0 
else 
san_ip=$ETH1 
fi 
 
addqtree $netapp_auto_ip $clientvol
addqtree $netapp_auto_ip $dbvol 
addexport $netapp_auto_ip $clientvol
addexport $netapp_auto_ip $dbvol 
if [[ -n $varvol ]];then # || [[ -n $statevol ]];then
addqtree $netapp_auto_ip $varvol 
addexport $netapp_auto_ip $varvol 
fi 
if [[ -n $statevol ]];then # || [[ -n $statevol ]];then
addqtree $netapp_auto_ip $statevol 
addexport $netapp_auto_ip $statevol 
fi 
} 
 
addqtree () {
#Speaks to the netapp to add a qtree. Must pass 2 variables. 1: netapp ip. 2: volume for the qtree. 
#$VMNAME is the name of the qtree that gets created. 
 
/usr/bin/ssh $1 qtree create $2/$VMNAME >> $LOG 2>&1
echo -e $txtb"Created the $2/$VMNAME qtree on $1."$txt
sleep 1 
} 
 
addexport () {
#Speaks to the netapp to add a nfs export. 
#Must pass 2 variables. 1: netapp ip. 2: volume for the qtree. 
#$VMNAME is the name of the qtree that gets created. 
 
count=1
while true
do 
if [ "$count" == "10" ];then
echo -e $txtr"Failed to create the export for $2/$VNAME on $1! Manually create this export BEFORE starting the vm or it will fail to build properly."$txt
break 
fi 
/usr/bin/ssh root@$1 "exportfs -p sec=sys,rw,root=$san_ip $2/$VMNAME" >> $LOG 2>&1 
checkit=`/usr/bin/ssh $1 "exportfs -q $2/$VMNAME"|grep $san_ip` 
sleep 1 
if [ -n "$checkit" ];then 
echo -e $txtb"Created the $2/$VMNAME export on $1."$txt 
break 
else 
printf . 
fi 
(( count++ )) 
done 
} 
 
checkmemory () {
RHEVMH=$(echo $RHEVM|sed s/vms/hosts/g)
clear 
echo -e $txtb"Checking the memory utilization on the cluster, please wait.."$txt
 
# These 4 values are the hash used to get statistics for memory from the rhev api
mem_total_stat="7816602b-c05c-3db7-a4da-3769f7ad8896" 
mem_used_stat="b7499508-c1c3-32f0-8174-c1783e57bb08" 
mem_free_stat="5a0fba9d-33d7-3cbf-addd-ba462040c946" 
mem_shared_stat="ffc0e1fd-fa34-3f85-9862-8a841c1658bc" 
 
most_mem=0 # this will be set to the memory amount of the node with the most memory
total_mem=0 # This will be total memory of all the systems 
sys_count=0 
for i in `/usr/bin/curl -1 --silent -S -k -X GET -H "Accept: application/xml" -u $RUID $RHEVMH|grep 'host href'|cut -d '"' -f 4`;do
# Only get mem stats for working hypervisors 
if [[ $(/usr/bin/curl -1 --silent -S -k -X GET -H "Accept: application/xml" -u $RUID $RHEVMH${i}|grep state|cut -d '>' -f 2|cut -d '<' -f 1) == "up" ]];then
# get memory for the host 
mem=`/usr/bin/curl -1 --silent -S -k -X GET -H "Accept: application/xml" -u $RUID $RHEVMH${i}/statistics/${mem_total_stat}|grep datum|cut -d '>' -f 2|cut -d '<' -f 1` 
# get free memory for the host 
fmem=`/usr/bin/curl -1 --silent -S -k -X GET -H "Accept: application/xml" -u $RUID $RHEVMH${i}/statistics/${mem_free_stat}|grep datum|cut -d '>' -f 2|cut -d '<' -f 1` 
# need to get the node with the most memory. That is the amount of memory we need free 
# to maintain n-1 for host redundancy 
if (( $mem > $most_mem )); then 
most_mem=$mem 
fi 
total_mem=$(( $total_mem + $mem )) 
free_mem=$(( $free_mem + $fmem )) 
(( sys_count ++ )) 
fi 
done 
 
if (( $most_mem > $free_mem ));then
echo -e $txtr"There is not enough memory on the cluster for more VMs. Please contact the operations group."$txt
exit 
fi 
 
# Set a warning at 80% of n-1 so we know we are getting close.
used_mem=$(( $total_mem - $free_mem )) 
warn_mem=`echo "scale=0; ($total_mem-$most_mem)*0.8"|bc` 
warn_mem=${warn_mem/\.*} 
if (( $used_mem > $warn_mem ));then 
echo $txtr"The cluster is at 80% memory utilization. Please alert operations. It is ok to continue making this vm"$txt
read memorywarning 
fi 
 
#echo "Total systems $sys_count"
#echo "Total memory: "$(( $total_mem / 1073741824 ))" GB"
#echo " Used memory: "$(( $used_mem / 1073741824 ))" GB" 
#echo " Free memory: "$(( $free_mem / 1073741824 ))" GB" 
#echo " Warn memory: "$(( $warn_mem / 1073741824 ))" GB If used mem is more then this then warn"
#echo " Large node: "$(( $most_mem / 1073741824 ))" GB" 
#read blah 
 
}
 
setopts () {
case $CLUSTER_VERS in
ovirt) vmid_opts='vm.href';
nic_opts='nic.href';
cut_opts='-d " -f 4';;
rhevm) vmid_opts='vm.href'; 
nic_opts='nic.href'; 
cut_opts='-d " -f 4';;
*) echo "Illegal cluster version";exit;;
esac 
}
 
########################
# Begin Main Logic #
########################
 
if [ "$1" == "-c" ];then
writeconf
fi
if [ "$1" == "-force" ];then
forceqtree="yes"
DNFS="NO"
fi
checkrunning #This looks to see if a createvm script is already running.
if [ "$1" == "-t" ];then
getconf $2 #Reads the config file in /opt/createvm for the appropriate variables.
else
getconf
fi
# Allows a vm to be created with a name other then the restricted format listed in the conf file
if [ "$1" == "-n" ];then
allow_name="true"
fi
 
getcluster #Asks which cluster the VM will be built on.
setopts
checkmemory #Make sure there is enough memory on the cluster for another vm
inputvm #Asks the usr to input the new vms details
createvm #Speaks with the rhev api to provision the new VM
createmacfile #Creates a firstboot config file using the MAC address of eth0
if [ -n "$DNS" ]; then #Only execute if the user chooses to
createdns #add the dns records to the master database on rl01-v0300.rlem.net
fi
if [ -n "$NFS" ]; then #Only execute if the user chooses to
createsan #This speaks with the netapp to create the shares for this vm
fi
 
