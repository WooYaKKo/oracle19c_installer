#!/bin/sh

# This script is to install the Oracle 19c

# oracle19c Not supported os RHEL8 
CV_ASSUME_DISTID=OEL8

CurDir=$(cd $(dirname $0); pwd)
_FuncDir=$(cd ${CurDir}/Functions; pwd)
_LogDir=/tmp/Automation

. ${_FuncDir}/basicFunc.lib

checkOS
_LogFile=${_LogDir}/${_LogTime}.installOracle_19c.log

echo "[$(basename $0)] output will be logged in ${_LogFile}\n"
historyMenu " * [$(basename $0)] output was logged in ${_LogFile}"

_VER=19c
_DBA=dba
_INSTALL_OPTION=INSTALL_DB_SWONLY
_FALSE=false
_TRUE=true

_UserName=oracle
_Profile=/home/{_UserName}/.profile
[ ${_OS} = "Linux" ] && _Profile=~oracle/.bash_profile

_ORACLE_BASE=$(grep -w ORACLE_BASE= ${_Profile}|grep -v "#"|awk -F= '{print $2}')
_ORACLE_HOME=${_ORACLE_BASE}$(grep -w ORACLE_HOME= ${_Profile}|grep -v "#"|awk -F= '{print $2}'|sed -e 's/$ORACLE_BASE//')
_FROM_BASE=${_SwDir}/Oracle/Oracle_${_VER}_${_OS}

f_checkIocp () {
    [ $(lsdev -Cc iocp|grep -c Defined) -eq 1 ] && {
        chdev -l iocp0 -P -a autoconfig='available'
        consoleLog " * [iocp0] chdev was successfully availabled.\n\n"
        consoleLog " ** You should reboot to install & start installing Oracle .\n"
        exit
    }
}

f_getRspInfo () {
    echo " Oracle Edition (19.3.0)"
    echo "   1. EE      2. SE      C. Cancel"

    print -n "\n - Oracle Edition Choice [1] ? "; read echc ; echo

    case $echc in
        1|"")
            _EDITION=EE ;;
        2)
            _EDITION=SE ;;
        c|C)
            echo "   * You canceled installing Oracle.\n"
            exit ;;
        *)
            echo "   ** Please check your input. Retry...\n"
            exit ;;
    esac

    print -n " - Oracle BASE Directory [${_ORACLE_BASE}] ? "; read bchc; echo
    if [ $bchc ]; then
        _ORACLE_BASE=$bchc
        _ORACLE_HOME=${_ORACLE_BASE}/product/190
    fi
    echo "   # ORACLE Edition => ${_EDITION}"
    echo "   # ORACLE Home Dirctory => ${_ORACLE_HOME}"
}

f_checkOracleHome () {
    if [ ! -d ${_ORACLE_BASE} ]; then
        mkdir -p ${_ORACLE_HOME}
        chown -R oracle:dba ${_ORACLE_BASE}
        chown oracle:dba ${_ORACLE_BASE}/../
        echo "\n\n   * There is not exist ORACLE BASE Dirctory."
        echo "     Directory was successfully created in ${_ORACLE_BASE}.\n"
    else
        [ -e ${_ORACLE_HOME}/bin/oracle ] &&
            if [ $(wc -c ${_ORACLE_HOME}/bin/oracle|awk '{print $1}') -gt 0 -a $(du -sm ${_ORACLE_HOME}|awk '{print $1}') -ge 10000 ]; then
                echo "\n * Oracle have already been to install.[OK]\n"
                exit
            fi
    fi
    checkDir ${_ORACLE_HOME}
    chown oracle.dba ${_ORACLE_HOME}
}

f_checkUnzip () {
    case ${_OS} in
        AIX)
            [ $(rpm -qa|grep -c unzip-6) -eq 0 ] &&
                rpm -ivh ${_SwDir}/AixTools/unzip-6.0-3.aix6.1.ppc.rpm &&
                consoleLog "  * [unzip 6.0] was successfully installed.\n" ;;
        Linux)
            [ $(which unzip) ] || {
                yum install unzip -y &&
                consoleLog "  * [unzip] was successfully copied.\n"
            } ;;
        *)
            conoleLog "  ** OS Unkown...${_OS}\n" ;;
    esac
}

f_unzipInstallFile () {
    [ -e ${_ORACLE_HOME}/runInstaller -a $(du -sm ${_ORACLE_HOME}|awk '{print $1}') -ge 7000 ] &&
        echo "\n  * Oracle InstallFileSet exist already. [OK]" ||
        if [ -d ${_ORACLE_HOME} ]; then
#            cp -rp ${_SwDir}/Oracle/Oracle_19c_AIX/*_193000_db_home.zip
            su - oracle -c "cd ${_ORACLE_HOME}; unzip /usr/local/*_193000_db_home.zip"
        else
            echo "\n  ** [${_ORACLE_HOME}] Directory does not exist.\n"
            print -n " - Do you want to create ORACLE_HOME Directory ? (y/n) "; read yn; echo
            [ $yn == "Y" -o $yn == "y" ] &&
                mkdir -p ${_ORACLE_HOME} && chown oracle.dba ${_ORACLE_HOME} &&
                consoleLog " * [${_ORACLE_HOME}] Directory was successfully created.\n"
            exit
        fi
}

f_genRsp () {
export RSP
    RSP="oracle.install.option=${_INSTALL_OPTION} \
        UNIX_GROUP_NAME=${_DBA} \
        INVENTORY_LOCATION=${_InventoryDir}/oraInventory \
        ORACLE_HOME=${_ORACLE_HOME} \
        ORACLE_BASE=${_ORACLE_BASE} \
        oracle.install.db.InstallEdition=${_EDITION} \
        oracle.install.db.isCustomInstall=${_FALSE} \
        oracle.install.db.OSDBA_GROUP=${_DBA} \
        oracle.install.db.OSOPER_GROUP=${_DBA} \
        oracle.install.db.OSBACKUPDBA_GROUP=${_DBA} \
        oracle.install.db.OSDGDBA_GROUP=${_DBA} \
        oracle.install.db.OSKMDBA_GROUP=${_DBA} \
        oracle.install.db.OSRACDBA_GROUP=${_DBA} \
        DECLINE_SECURITY_UPDATES=${_TRUE}" 
}

f_preCheckAIX () {
    echo "\n  * You have to run ${_ORACLE_HOME}/clone/rootpre.sh \n"
    print -n "  -  Do you want to run rootpre.sh ? (y/n) "; read yn; echo
    [ $(echo $yn|grep -ic Y) -eq 1 ] && ${_ORACLE_HOME}/clone/rootpre.sh

    print -n "\n  - Do you want to continue ? (y/n) "; read yn; echo
    [ $(echo $yn|grep -ic N) -eq 1 ] && exit
}

f_createBase () {
    backupFile /etc/oraInst.loc

    echo "inventory_loc=${_InventoryDir}/oraInventory\ninst_group=dba" > /etc/oraInst.loc
    [ -d ${_InventoryDir} ] || mkdir -p ${_InvnentoryDir}
    [ -d ${_ORACLE_BASE}/tmp ] || mkdir -p ${_ORACLE_BASE}/tmp

    chown oracle:dba /etc/oraInst.loc ${_InventoryDir} ${_ORACLE_BASE}/tmp
}

f_requirement (){
    yum install -y binutils compat-libcap1 compat-libstdc++ elfutils-libelf \
    elfutils-libelf-devel fontconfig-devel glibc glibc-devel ksh libaio libaio-devel \
    libXrender libXrender-devel libX11 libXau libXi libXtst libgcc libstdc++ libstdc++-devel \
    libxcb make smartmontools sysstat
}

f_runInstaller () {
    print -n "\n  - Do you want to install Oracle (y/n) ? "; read yn; echo
    case $yn in
        y|Y)
            echo "\n  Oracle Installing ..."

            [ ${_OS} == "AIX" ] && f_preCheckAIX

            f_createBase
            f_genRsp

            su - ${_UserName} -c "${_ORACLE_HOME}/runInstaller -executePrereqs -silent \
                                  $RSP 2>&1 | tee -a ${_LOG} "

            print -n "  - Do you want to continue ? (y/n) "; read yn; echo
            [ $(echo $yn|grep -ic N) -eq 1 ] && exit

            su - ${_UserName} -c "${_ORACLE_HOME}/runInstaller -ignorePrereq -waitforcompletion -silent \
                                  $RSP 2>&1 | tee -a ${_LOG} "
            ;;
        n|N)
            echo "\n  ** You don't want to install..."
            ;;
    esac
}

__main__ () {
    [ ${_OS} == "AIX" ] && f_checkIocp

    f_getRspInfo
    f_checkOracleHome

    _InventoryDir=$(cd ${_ORACLE_BASE}/../; pwd)

    f_checkUnzip
    f_unzipInstallFile

    f_runInstaller
}
__main__

