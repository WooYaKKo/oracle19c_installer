#!/bin/sh

CurDir=$(cd $(dirname $0); pwd)
_FuncDir=$(cd ${CurDir}/Functions; pwd)
_LogDir=/tmp/Automation

. ${_FuncDir}/basicFunc.lib

checkOS

_LogFile=${_LogDir}/${_LogTime}.oraUserGroup.log

echo "[$(basename $0)] output will be logged in ${_LogFile}"
historyMenu " * [$(basename $0)] output was logged in ${_LogFile}"

fn_beginMessage "- db User & Group Creation"

case ${_OS} in
    AIX)
        if [ `cat /etc/group |grep -c dba` = 0 ]; then
            mkgroup -'A' id='101' dba
            consoleLog " * [ dba ] Group was successfully created.\n"
        else
            consoleLog " * [ dba ]Group already exists. [OK]" 
        fi

        if [ `cat /etc/passwd|grep -v ^"*"|grep -wc ^oracle` = 0 ]; then
            if [ `cat /etc/passwd|awk -F: '{print $3}'|grep -wc 101` = 0 ]; then
                mkuser -a id=101 pgrp=dba oracle
                consoleLog " * [ oracle ] User was successfully created.\n"
                echo "
                    PS1=\$(whoami)@\$(hostname):'\$PWD >'
                    
                    export ORACLE_SID=
                    export ORACLE_BASE=/oracle/app/oracle
                    export ORACLE_HOME=\$ORACLE_BASE/product/190
                    export PATH=\$PATH:\$ORACLE_HOME/bin:\$ORACLE_HOME/OPatch
                    export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$ORACLE_HOME/lib
                    export LIBPATH=\$LIBPATH:\$ORACLE_HOME/lib
                    export ORA_NLS33=\$ORACLE_HOME/ocommon/nls/admin/data
                    export TMPDIR=\$ORACLE_BASE/tmp
                    export TMP=\$ORACLE_BASE/tmp
                    export TNS_ADMIN=\$HOME/network/admin
                    export NLS_LANG=American_america.KO16MSWIN949
                    export DISPLAY=:0.0
                    
                    umask 022
                    set -o vi
                    
                    alias ss='sqlplus \"/as sysdba\"'
                " | sed 's/^ *//g'>> /home/oracle/.profile

            else
                consoleLog " * id=101 have already been exist."
                consoleLog " * You need to create User manually.\n"
                consoleLog "   mkuser -a id=??? pgrp=dba oracle\n"
            fi
        else
            consoleLog " [ oracle ] User alreay exist. [OK]"
        fi
        ;;
    Linux)
        if [ `cat /etc/group |grep -c dba` = 0 ]; then
            groupadd -g 101 dba
            consoleLog " * [ dba ] Group was successfully created.\n" 
        else
            consoleLog " [ dba ] Group already exist. [OK]" 
        fi

        if [ `cat /etc/passwd|grep -v ^"*"|grep -wc ^oracle` = 0 ]; then
            if [ `cat /etc/passwd|awk -F: '{print $3}'|grep -wc 101` = 0 ]; then
                useradd -u 101 -g dba oracle
                consoleLog " * [ oracle ] User was successfully created.\n"
                echo "
                    PS1=`whoami`@`hostname`:'\$PWD >'
                    
                    export ORACLE_SID=
                    export ORACLE_BASE=/oracle/app/oracle
                    export ORACLE_HOME=\$ORACLE_BASE/product/190
                    export PATH=\$PATH:\$ORACLE_HOME/bin:\$ORACLE_HOME/OPatch
                    export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$ORACLE_HOME/lib
                    export LIBPATH=\$LIBPATH:\$ORACLE_HOME/lib
                    export ORA_NLS33=\$ORACLE_HOME/ocommon/nls/admin/data
                    export TMPDIR=\$ORACLE_BASE/tmp
                    export TMP=\$ORACLE_BASE/tmp
                    export TNS_ADMIN=\$HOME/network/admin
                    export NLS_LANG=American_america.KO16MSWIN949
                    export DISPLAY=:0.0
                    
                    umask 022
                    set -o vi
                    
                    alias ss='sqlplus \"/as sysdba\"'
                " |sed 's/^ *//g' >> /home/oracle/.bash_profile

            else
                consoleLog " * [id=101] have already been exist."
                consoleLog " * You need to create User manually.\n"
                consoleLog "   useradd -u=??? -g=dba oracle\n"
            fi
        else
            consoleLog " [ oracle ] User already exists. [OK]"
        fi
        ;;
esac

fn_endMessage

