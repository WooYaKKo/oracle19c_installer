#!/bin/ksh

# This script is intended to check for AIX vulnerabilities.
#                written by Hooni & Joy in 2020.11.16

_EtcPasswd=/etc/passwd
_EtcInetd=/etc/inetd.conf
_SecUser=/etc/security/user

fn_checkNotOrFind () {
#$1: FileName or Directory
#$2: Permission
#$3: User 

    [ $4 -a $4 == "echo" ] && echo "find $1 \( ! -user $3 -o ! -perm $2 \)" && return
    [ -f $1 ] && find $1 \( ! -user $3 -o ! -perm $2 \) || echo
}

fn_checkUserPerm () {
# N is used when calling from a fn_checkFirstFalse().

    [ $3 ] && User=$3 || User=root
    if [ $(fn_checkNotOrFind $1 $2 $User) ]; then
        [ $N ] || echo FALSE
        echo "  -> ls -l $1  ($User,$2)" 
        ls -l $1 | awk '{print "\t"$0}'
    else 
        echo OK
    fi
}

fn_checkFirstFalse () {
# N is predefined variable.

    if [ $N -eq 1 ]; then
        isOK=FALSE; N=2
        echo FALSE
    fi
    echo "$*"
}

fn_lssrc () {
    [ $2 -a $2 == "echo" ] && echo "lssrc -s $1" && return
    lssrc -s $1
}

fn_checkInetd () {
    OPT=$(echo ^$1|sed 's/|/|^/g')
    [ $2 ] && FILE=$2 || FILE=/etc/inetd.conf
    [ $(grep -Ew $OPT ${FILE}|awk '{if (NR == 1) print $1}') ] &&
        echo "FALSE\n  -> grep -Ew $OPT ${FILE}" &&
        grep -Ew $OPT ${FILE}|awk '{print "\t"$0}' ||
    echo OK
}

fn_checkPS () {
    [ $(ps -ef | grep -v grep| grep -Ewc $1) -gt 0 ] &&
        echo "FALSE\n  -> ps -ef | grep -v grep | grep -E $1" &&
        ps -ef | grep -Ew $1 | grep -v grep|awk '{print "\t"$0}' ||
    echo OK
}

f_check_U01 () {
    CMD="lssec -f ${_SecUser} -s root -a rlogin"
    ${CMD}|awk -F= -v cmd="$CMD" '{if($2 == "false") print "OK"
                    else  print "FALSE\n  ->",cmd"\n\t"$0}'
}

f_check_U05 () {
    [ $(echo $(grep -vw ^root ${_EtcPasswd} |awk -F: '{if ($3 == "0")  print $1}')|awk '{print $1}') ] && 
        echo "FALSE\n  ->grep -vw ^root ${_EtcPasswd} |awk -F: '{if (\$3 == \"0\")  print \$0}'" &&
        grep -vw ^root ${_EtcPasswd} |awk -F: '{if ($3 == "0")  print "\t"$0}' || 
    echo OK
}

f_check_U06 () {
    isOK=OK
    CMD="lssec -f ${_SecUser} -s default -a sugroups"
    SUGRP=$(${CMD}|awk -F= '{print $NF}')

    if [ $SUGRP ]; then
        CMD="lsgroup -a users IUSER"
        [ $(${CMD}|awk '{print $NF}') ] || {
            echo "FALSE\n  -> ${CMD}\n\t$($CMD)"
            isOK=FALSE
        }
    else
        echo "FALSE\n  -> ${CMD}\n\t$($CMD)"
        isOK=FALSE
    fi

    SU=/usr/bin/su
    [ $(find $SU -perm 4750) ] && [ $(find $SU -group IUSER) ] || { 
        [ $isOK == "OK" ] && echo "FALSE" && isOK=FALSE
        echo "  -> ls -l $SU\n\t$(ls -l $SU)"
    }

    [ $isOK == "OK" ] && echo OK
}

f_check_U07 () {
    CMD="lssec -f ${_SecUser} -s default -a minlen"
    $CMD | awk -F= -v cmd="$CMD" '{if($2 > 7) print "OK"; else print "FALSE\n  ->",cmd"\n\t"$0}'
}

f_check_U10 () {
    LIST="lp uucp nuucp"; ACC=
    for User in $LIST; do
        [ $(cat ${_EtcPasswd} |grep -v false$|grep -c ^$User) -gt 0 ] &&
            ACC="$ACC\t$(cat ${_EtcPasswd} |grep -v false$|grep -w ^$User)\n"
    done
    [ $(echo $ACC|awk '{if (NR == 1) print $1}') ] && 
        echo "FALSE\n  -> cat ${_EtcPasswd}\n$ACC" ||
    echo OK
}

f_check_U11 () {
    CMD="lsgroup -a users system"
    [ $(${CMD}|awk -F= '{print $NF}'|awk -F, '{print NF}') -gt 1 ] && 
        echo "FALSE\n  -> ${CMD}\n\t$(${CMD})" || 
    echo OK
}

f_check_U12 () {
    N=1
    for GRP in $(lsgroup ALL|awk '{print $1}'); do
        for Lists in $(lsgroup -a users $GRP|awk -F= '{print $NF}'); do
            for User in $(echo $Lists|tr ',' ' '); do
                if [ $(grep -wc ^$User ${_EtcPasswd}) -eq 0 ]; then
                    [ $N -eq 1 ] && N=2 &&
                        echo "FALSE\n  -> An account that does not exist in the group"
                    echo "\t[$User] in [$GRP]"
                fi
            done
        done
    done

    for GRP in $(lsgroup ALL|awk '{print $1}'); do
        if [ $(lsuser -a pgrp groups ALL|grep -wc $GRP) -eq 0 ]; then
            [ $N -eq 1 ] && echo FALSE
            [ $N -ne 3 ] && N=3 &&
                echo "  -> Group for which the account does not exist" 
            grep ^$GRP /etc/group|awk '{print "\t"$0}'
        fi
    done

    [ $N -eq 1 ] && echo OK
}

f_check_U13 () {
    if [ $(cat ${_EtcPasswd} | awk -F: 'x[$3]++'|wc -l) -gt 1 ]; then
        echo "FALSE\n  -> cat ${_EtcPasswd} | awk -F: 'x[\$3]++ {print \$0}'"
        cat ${_EtcPasswd} | awk -F: 'x[$3]++ {print "\t"$0}'
    else
        echo OK
    fi
}

f_check_U14 () {
    LIST="daemon bin sys adm guest uucp nuucp lp nobody pconsole invscout snapp ipsec sshd shutdown";ACC=
    for User in $LIST; do
        [ $(cat ${_EtcPasswd} |grep -v false$|grep -c ^$User) -gt 0 ] &&
            ACC="$ACC\t$(cat ${_EtcPasswd} |grep -v false$|grep -w ^$User)\n"
    done
    [ $(echo $ACC|awk '{if (NR == 1) print $1}') ] && 
        echo "FALSE\n  -> cat ${_EtcPasswd}\n$ACC" ||
    echo OK
}

f_check_U15 () {
    TmOut=$(grep TMOUT= /etc/profile|grep -v "^ *#"|cut -d= -f2)
    [ ${TmOut} ] &&
        if [ ${TmOut} -gt 900 ]; then
            echo "FALSE\n  -> grep TMOUT= /etc/profile"
            grep TMOUT= /etc/profile|grep -v "^ *#"|awk '{print "\t"$0}'
        else
            echo OK
        fi ||
    echo "FALSE\n  -> There is no value of TMOUT in /etc/profile."
}

f_check_U16 () {
    OPT="=\.:|=:|:\.|::|:$"
    isOK=OK; N=1
    FILE="/etc/profile "
    for HOME in $(grep -v false$ /etc/passwd|cut -d: -f6); do
        for File in ".profile" ".kshrc"; do
            FILE="${FILE} ${HOME}/${File}"
        done
    done
    for Profile in ${FILE}; do
        [ -f $Profile ] && Path=$(grep -w PATH $Profile|grep -v "^ *#"|grep -E $OPT|awk '{print "\\t"$0}')
        [ $(echo $Path|awk '{if (NR == 1) print $1}') ] && fn_checkFirstFalse "  -> grep -w PATH $Profile\n$Path"
    done
    unset N
    [ $isOK == "OK" ] && echo OK
}

f_check_U17 () {
    [ $(find / \( -nouser -o -nogroup \) -xdev -ls |wc -l) -gt 0 ] &&
        echo "FALSE\n  -> find / \( -nouser -o -nogroup \) -xdev -ls |head -5" &&
        find / \( -nouser -o -nogroup \) -xdev -ls |head -5|awk '{print "\t"$0}' ||
    echo OK
}

f_check_U18 () {
    fn_checkUserPerm ${_EtcPasswd} 644
}

f_check_U19 () {
    fn_checkUserPerm /etc/security/passwd 400
}

f_check_U20 () {
    fn_checkUserPerm /etc/hosts 644
}

f_check_U21 () {
    fn_checkUserPerm ${_EtcInetd} 600
}

f_check_U22 () {
    fn_checkUserPerm /etc/syslog.conf 644
}

f_check_U23 () {
    fn_checkUserPerm /etc/services 644
}

f_check_U24 () {
    [ $(find / -user root -type f \( -perm -04000 -o -perm -02000 \) -xdev | wc -l) -gt 0 ] &&
        echo "FALSE\n  -> find / -user root -type f \\( -perm -04000 -o -perm -02000 \\) -xdev -ls" &&
        find / -user root -type f \( -perm -04000 -o -perm -02000 \) -xdev -ls|awk '{print "\t"$0}' ||
    echo OK
}

f_check_U25 () {
    isOK=OK
    ENVAR=".profile .kshrc .cshrc .bashrc .bash_profile .login .exrc .netrc .sh_history .vi_history"
    for User in $(cat ${_EtcPasswd} |grep -v root|grep -v false$|cut -d: -f1); do
        LSD=$(ls -ld $(cat ${_EtcPasswd}|grep -w ^$User|cut -d: -f6))
        if [ $User != $(echo $LSD|awk '{print $3}') ]; then
            [ $isOK == "OK" ] && isOK=FALSE && 
                echo "FALSE\n  -> ls -l\n\t(${User})\t$LSD" ||
            echo "\t($User)\t$LSD" 
        fi
        for List in $ENVAR; do
            File=$(lsuser -a home $User|awk -F= '{print $NF}')/$List
            [ -e ${File} ] &&
                if [ $(find ${File} ! -user ${User}) ]; then
                    [ $isOK == "OK" ] && isOK=FALSE && 
                        echo "FALSE\n  -> ls -l\n\t(${User})\t$(ls -l ${File})" ||
                    echo "\t(${User})\t$(ls -l ${File})" 
                fi
        done
    done
    [ $isOK == "OK" ] && echo OK
}

f_check_U26 () {
    CMD="find /tmp /var /etc /home -type f -perm -2"
    [ $(${CMD}|head -1) ] && { echo FALSE
        echo " -> $CMD -ls|head -5\n$(${CMD} -exec ls -l {} \; |head -5|awk '{print "\t"$0}')"
    } || echo OK
}

f_check_U27 () {
    CMD="find /dev -type f"
    [ $(${CMD}|head -1) ] && { echo "FALSE\n  -> ${CMD} -ls"
        ${CMD} -exec ls -l {} \; |awk '{print "\t"$0}'
    } || echo OK
}

f_check_U28 () {
    isOK=OK; N=1
    [ $(fn_checkNotOrFind /etc/hosts.equiv 600 root) ] &&
        fn_checkFirstFalse "$(fn_checkUserPerm /etc/hosts.equiv 600)"
    for User in $(lsuser -a shell ALL|grep -v false$|cut -d" " -f1); do
        File=$(echo ~$User/.rhosts)
        [ -f ${File} ] &&
            if [ $(fn_checkNotOrFind ${File} 600 $User) ]; then
                fn_checkFirstFalse "$(fn_checkUserPerm ${File} 600 $User)"
            fi &&
            if [ $(grep -c "+" ${File}) -gt 1 ]; then
                [ $N -eq 1 ] && isOK=FALSE && N=2 && echo FALSE
                grep "+" ${File}|awk -v rhosts="${File}" 'BEGIN {print "  -> grep \"+\"",rhosts} {print "\t"$0}'
            fi
    done
    [ $isOK == "OK" ] && echo OK
    unset N
}

f_check_U29 () {
    [ ! -f /etc/hosts.deny ] && echo "FALSE\n  -> ls -l /etc/hosts.deny\n\tThe file does not exist." && return
    [ $(grep -c "^ *ALL:ALL" /etc/hosts.deny) -eq 0 ] && echo "FALSE\n  -> cat /etc/hosts.deny" &&
        cat /etc/hosts.deny|awk '{print "\t"$0}' || 
    echo OK
}

f_check_U30 () {
    File=$(fn_checkNotOrFind /etc/hosts.lpd 600 root)
    [ ${File} ] &&
        echo "FALSE\n  -> $(fn_checkNotOrFind $File 600 $User echo) -ls" &&
        echo "\t$(ls -l $File) " || echo OK
}

f_check_U31 () {
    fn_checkPS yp
}

f_check_U32 () {
    CMD="lssec -f ${_SecUser} -s default -a umask"
    [ $(grep umask /etc/profile|grep -v "^ *#"|wc -l) -eq 0 -a $(${CMD}|cut -d= -f2) -ne 22 ] && 
        echo "FALSE\n -> $CMD\n\t$(${CMD})" ||
    echo OK
}

f_check_U33 () {
    isOK=OK; N=1
    for User in $(egrep -v 'false$|^root' ${_EtcPasswd}|cut -d: -f1); do
        [ $User != $(ls -ld ~$User|awk '{print $3}') ] && 
            fn_checkFirstFalse "  -> ls -ld ~$User\n\t$(ls -ld ~$User)"
    done
    unset N
    [ $isOK == "OK" ] && echo OK
}

f_check_U34 () {
    isOK=OK; N=1
    for User in $(egrep -v 'false$|^root' ${_EtcPasswd}|cut -d: -f1); do
        HOME=$(grep ^$User ${_EtcPasswd}|cut -d: -f6)
        [ ! -d $HOME ] &&
            fn_checkFirstFalse "  -> User: $User\n\t* [$HOME] the directory does not exist."
    done
    unset N
    [ $isOK == "OK" ] && echo OK
}

f_check_U36 () {
    fn_checkInetd finger
}

f_check_U37 () {
    fn_checkInetd ftp ${_EtcPasswd}
}

f_check_U38 () {
    fn_checkInetd "rlogin|rsh|rexec"
}

f_check_U39 () {
    for File in "/var/adm/cron/cron.allow" "/var/adm/cron/cron.deny"; do
    [ -e $File ] &&
        fn_checkUserPerm $File 640
done
}

f_check_U40 () {
    fn_checkInetd "echo|discard|daytime|chargen"
}

f_check_U41 () {
    [ $(fn_lssrc nfsd|grep -c active) -eq 1 ] &&
        echo "FALSE\n  -> $(fn_lssrc nfsd echo)" &&
        fn_lssrc nfsd|awk '{print "\t"$0}' ||
    echo OK
}

f_check_U42 () {
    CMD="showmount -e $(hostname)"
    [ $(lssrc -s nfsd|grep -c active) -gt 0 ] &&
        [ $(${CMD}|grep -c everyone) -gt 0 ] && 
            echo "FALSE\n  -> ${CMD}|grep everyone" &&
            ${CMD}|grep everyone|awk '{print "\t"$0}' ||
    echo OK
}

f_check_U43 () {
    fn_checkPS automountd
}

f_check_U44 () {
    [ $(grep -w rpc ${_EtcInetd}|grep -vc "^ *#") -gt 0 ] && 
        echo "FALSE\n  -> grep -w rpc ${_EtcInetd}|grep -v "#"" &&
        grep -w rpc ${_EtcInetd}|grep -v "^ *#"|awk '{print "\t"$0}' ||
    echo OK
}

f_check_U45 () {
    [ $(lssrc -g yp|grep -c active) -gt 0 ] && 
        echo "FALSE\n  -> lssrc -g yp" &&
        lssrc -g yp|awk '{print "\t"$0}' ||
    echo OK
}

f_check_U46 () {
    fn_checkInetd "tftp|talk|ntalk"
}

f_check_U47 () {
    [ $(fn_lssrc sendmail|grep -c active) -eq 1 ] &&
        echo "FALSE\n  -> $(fn_lssrc sendmail echo)" &&
        fn_lssrc sendmail|awk '{print "\t"$0}' ||
    echo OK
}

f_check_U48 () {
    [ $(lssrc -s sendmail|grep -c active) -gt 0 ] && 
        [ $(grep "550 Relaying denied" /etc/sendmail.cf|grep "R\$\*"|grep -vc "^ *#") -eq 0 ] && 
        echo "FALSE\n  -> grep "R\$\*" /etc/sendmail.cf|grep 550" &&
        grep "R\$\*" /etc/sendmail.cf|grep "550 Relaying denied"|awk '{print "\t"$0}' ||
    echo OK
}

f_check_U49 () {
    [ $(lssrc -s sendmail|grep -c active) -gt 0 ] && 
        grep PrivacyOptions /etc/sendmail.cf| grep -v restrictqrun &&
        echo "FALSE\n  -> grep PrivacyOptions /etc/sendmail.cf| grep -v restrictqrun" &&
        grep PrivacyOptions /etc/sendmail.cf| grep -v restrictqrun|awk '{print "\t"$0}' ||
    echo OK
}

f_check_U50 () {
    fn_checkPS named
}

f_check_U51 () {
    fn_checkPS named
}

f_check_U59 () {
    [ $(grep -wc "^ *ssh" ${_EtcInetd}) -eq 0 ] && 
        echo "FALSE\n  -> * [ssh] service is not running." ||
    echo OK
}

f_check_U60 () {
    fn_checkInetd ftp
}

f_check_U61 () {
    [ $(grep -w ^ftp ${_EtcPasswd}) ] && 
        [ $(grep -w ^ftp ${_EtcPasswd}|grep -v false$|wc -l) -gt 0 ] &&
        echo "FALSE\n  -> grep -w ^ftp ${_EtcPasswd}" &&
        grep -w ^ftp ${_EtcPasswd}|awk '{print "\t"$0}' ||
    echo OK
}

f_check_U62 () {
    [ -f /etc/ftpusers ] && fn_checkUserPerm /etc/ftpusers 600 ||
        echo "FALSE\n  -> ls -l /etc/ftpusers\n\tThe File does not exist."
}

f_check_U63 () {
    [ $(grep -c "^ *root" /etc/ftpusers) ] && echo OK || 
        echo "FALSE\n  -> grep "root" /etc/ftpusers"
}

f_check_U64 () {
    for File in "/var/adm/cron/at.allow" "/var/adm/cron/at.deny"; do
        [ -f $File ] && fn_checkUserPerm ${File} 640
    done
}

f_check_U65 () {
    [ $(fn_lssrc snmpd|grep -c active) -eq 1 ] &&
        echo "FALSE\n  -> $(fn_lssrc snmpd echo)" &&
        fn_lssrc snmpd|awk '{print "\t"$0}' ||
    echo OK
}

f_check_U66 () {
    #[ $(lssrc -s snmpd|grep -c active) -gt 0 ] && 
    [ $(grep -i "^ *community" /etc/snmpd.conf|grep -v "^ *#"|egrep -c "public|private") -gt 0 ] &&
        echo "FALSE\n  -> grep -i "^ *community" /etc/snmpd.conf" &&
        grep -i "^ *community" /etc/snmpd.conf|grep -v "^ *#"|awk '{print "\t"$0}' ||
    echo OK
}

f_check_U67 () {
    CMD="lssec -f /etc/security/login.cfg -s default -a herald"
    [ ! -e /etc/motd -o $(echo $(${CMD}|cut -d= -f2)|awk '{if (NR==1) print $1}') == "" ]  && 
        echo "FALSE \n  -> ${CMD}" &&
        ${CMD}|awk '{print "\t"$0}' ||
    echo OK
}

f_check_U68 () {
    [ -f /etc/exports ] &&  fn_checkUserPerm /etc/exports 644 || echo OK
}

checkSecWeak () {
    echo "===[ $1 ]==="
    f_check_$(echo $1|tr -d '-')
    echo "=============="
}

__main__ () {
    LogFile="ISMS-P_AIX.txt"; > $LogFile
    i=1;while [ i -lt 73 ]; do
        List=$(printf "%02d" $i);
        [ $(grep -c U${List} $(basename $0)) -gt 0 ] &&
            checkSecWeak U-${List} | tee -a $LogFile
        ((i+=1))
    done
}
__main__