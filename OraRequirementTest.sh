#!/bin/sh

# This script is to check the Oracle Requirements

# LOG:
#       /tmp/Automation/$_LogTime.oracleRequirement.log

CurDir=$(cd $(dirname $0); pwd)
_FuncDir=$(cd ${CurDir}/Functions; pwd)
_LogDir=/tmp/Automation

. ${_FuncDir}/basicFunc.lib

checkOS Linux
_LogFile=${_LogDir}/${_LogTime}.oraRequire.log

echo "[$(basename $0)] output will be logged in ${_LogFile}\n"
historyMenu " * [$(basename $0)] output was logged in ${_LogFile}"

_OSN=$(cat /etc/redhat-release | head -n 1 | cut -d . -f 1 | awk '{print $NF}' )

#####################################
# check the Hardware Requirements
#####################################

#-- Memory Requirement (least 2GB)
ram=$(($(grep MemTotal /proc/meminfo | awk '{print $2}') / 1048576))
[ $ram -ge 2 ] &&
    consoleLog " [ Memory ] Requirement (${ram}GB) is good. [OK]" ||
    consoleLog " * [ Memory ] Size is less than 2GB.\n"

#-- Swap space Requirement
swap=$(($(grep SwapTotal /proc/meminfo | awk '{print $2}') / 1048576))
if [ $ram -lt 16 ]; then
    [ $swap -ge $ram ] &&
        consoleLog " [ Swap ] space Requirement (${swap}GB) is good. [OK]" ||
       	consoleLog "* [ Swap ] space(${swap}GB) is lower than RAM size (${ram}GB - Recommand Size).\n"
else
    if [ $swap -ge 16 ]; then
        consoleLog " [ Swap ] space Requirement (${swap}GB) is good. [OK]"
    else
        consoleLog " * [ Swap ] space(${swap}GB) is lower than 16GB."
        consoleLog " * You have to Increase Swap space to the above 16GB.\n"
    fi
fi

#-- System Architecture
bitm=`uname -m`
if [ $bitm == "x86_64" ]; then
    consoleLog " [System] Architecture (64-bit) is good. [OK]"
else
    consoleLog " * [System] Architcture is not 64-bit mode."
    consoleLog " * You cannot install the software on this system.\n"
fi

#-- Package Requirements
yum install -y https://yum.oracle.com/repo/OracleLinux/OL7/latest/x86_64/getPackage/oracle-database-preinstall-19c-1.0-1.el7.x86_64.rpm
yum install -y http://mirror.centos.org/centos/7/os/x86_64/Packages/compat-libstdc++-33-3.2.3-72.el7.x86_64.rpm
yum install -y http://mirror.centos.org/centos/7/os/x86_64/Packages/compat-libcap1-1.10-7.el7.x86_64.rpm
yum install -y unzip binutils compat-libcap1 compat-libstdc++ gcc gcc-c++ glibc glibc-devel ksh libaio libaio-devel libgcc libstdc++ libstdc++-devel libXi libXtst libX11 libXau libxcb libXext libXtst libXrender make sysstat unixODBC unixODBC-devel libnsl

#-- Checking the Kernel Parameter
function param_chg {
    flag=0
    change=$1
    case $1 in
        kernel.sem )
            semmsl=`/sbin/sysctl -a | grep $1 | head -n1 | awk '{print $3}'`
            semmns=`/sbin/sysctl -a | grep $1 | head -n1 | awk '{print $4}'`
            semopm=`/sbin/sysctl -a | grep $1 | head -n1 | awk '{print $5}'`
            semmni=`/sbin/sysctl -a | grep $1 | head -n1 | awk '{print $6}'`
            if [ $semmsl -lt $2 ]; then
                flag=1
                change="$2"
            else
                change="$semmsl"
            fi
            if [ $semmns -lt $3 ]; then
                flag=1
                change="$change $3"
            else
                change="$change $semmns"
            fi
            if [ $semopm -lt $4 ]; then
                flag=1
                change="$change $4"
            else
                change="$change $semopm"
            fi
            if [ $semmni -lt $5 ]; then
                flag=1
                change="$change $5"
            else
                change="$change $semmni"
            fi
            ;;
        net.ipv4.ip_local_port_range)
            portmin=`/sbin/sysctl -a | grep $1 | awk '{print $3}'`
            portmax=`/sbin/sysctl -a | grep $1 | awk '{print $4}'`
            if [ $portmin -gt $2 ]; then
                flag=1
                change="$2"
            else
                change="$portmin"
            fi
            if [ $portmax -lt $3 ]; then
                flag=1
                change="$change $3"
            else
                change="$change $portmax"
            fi
            ;;
        *)
            value=`/sbin/sysctl -a | grep $1 | awk '{print $3}'`
            if [ $value -lt $2 ]; then
                flag=1
                change="$2"
            else
                change="$value"
            fi
            ;;
    esac

    org=$(/sbin/sysctl -a | grep $1)
    if [ $flag -eq 1 ]; then
        /sbin/sysctl -w $1 $change
        echo "$1 = $change" >> /etc/sysctl.conf
        consoleLog " * [ $1 ] Parameter was successfully changed value."
        consoleLog "   - OLD : ($org)"
        consoleLog "   - NEW : ($1 = $change)\n"
    else
        consoleLog " [ $1 ] Parameter value is good (Value : ${org}. [OK]"
    fi
}

backupFile /etc/sysctl.conf

[ $(which fuser 2>/dev/null) ] || yum -y install psmisc

param_chg fs.aio-max-nr 1048576
param_chg fs.file-max 6815744
#param_chg kernel.shmall 2097152
#param_chg kernel.shmmax 536870912
#param_chg kernel.shmmni 4096
param_chg kernel.sem 250 32000 100 128
param_chg net.ipv4.ip_local_port_range 9000 65500
param_chg net.core.rmem_default 262144
param_chg net.core.rmem_max 4194304
param_chg net.core.wmem_default 262144
param_chg net.core.wmem_max 1048576
