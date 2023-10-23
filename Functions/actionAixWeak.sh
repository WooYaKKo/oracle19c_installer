#!/bin/ksh

# This script is to work around the AIX vulnerability.
#             written by Hooni in 2020.11.

. ./checkAixWeak.lib

_DateTime=$(date +%Y%m%d)
_sedTemp=/tmp/SedTemp

f_action_U01 () {
    f_check_U01
    [ $(echo $(f_check_U01)|awk '{print $1}') == "FALSE" ] &&
        chsec -f /etc/security/user -s root -a rlogin=false &&
            echo "\n * The action was taken successfully." &&
            lssec -f /etc/security/user -s root -a rlogin
}

f_action_U12 () {
    f_check_U12
    [ $(echo $(f_check_U01)|awk '{print $1}') == "FALSE" ] &&
        for Group in $(lsgroup ALL|awk '{print $1}'); do
            isChange="No"
            if [ $(lsuser -a groups ALL|grep -wc $Group) -eq 0 ]; then
                echo " * [$Group] Group does not have a member."
            else
            for Lists in $(lsgroup -a users $Group|awk -F= '{print $NF}'); do
                Users=$Lists
                for User in $(echo $Lists|tr ',' ' '); do
                    if [ $(grep -wc ^$User /etc/passwd) -eq 0 ]; then
                        Users=$(echo $Users| sed -e 's/'$User'//' -e 's/,,/,/' -e 's/^,//' -e 's/,$//')
        #                echo " * [$User] Account, which is a member of the [$Group] group, does not exist."
                        isChange="Yes"
                    fi
                done
                if [ $(echo $isChange) == "Yes" ]; then
                    chgroup users=$Users $Group
                    echo " * [$Group]'s member was \"$Lists\"\n   -> $(lsgroup -a users $Group)"
                fi
            done
            fi
        done
}

f_action_U16 () {
    f_check_U16
    OPT="=\.:|=:|:\.|::|:$"
    for Profile in "/.profile" "/etc/profile"; do
        [ $(cat ${Profile}|grep PATH|grep -E $OPT|wc -l) -eq 0 ] && continue
        # backupFile ${Profile}
        cp -rp ${Profile} ${_sedTemp}
        for Sel in "=\.:" "=:" ":\." "::"; do
            D=$(echo $Sel|cut -c 1)
            cp -rp ${_sedTemp} ${_sedTemp}.1
            sed 's/'$Sel'/'$D'/g' ${_sedTemp}.1 > ${_sedTemp}
        done
        sed 's/:$//g' ${_sedTemp} > ${Profile}
    done
}

df_action_U16 () {
    f_check_U16
    if [ $(echo $(f_check_U01)|awk '{print $1}') == "FALSE" ]; then
        for Profile in "/.profile" "/etc/profile"; do
            CMD="cat -n ${Profile}|grep -E \"=\.|=:|:\.|::\""
            [ $(${CMD}|wc -l) -eq 0 ] && continue
                        echo $CMD

            # backupFile ${Profile}
            cp -rp ${Profile} ${_sedTemp}
            cat -n ${_sedTemp}|grep -E "=\.|=:|:\.|::"|awk -v sedtemp="${_sedTemp}" -v profile="${Profile}" 'BEGIN {printf "sed "} 
                {printf " -e \""$1"\''s/=\\./=/g\"" " -e \""$1"\''s/=:/=/g\"" " -e \""$1"\''s/:\\./:/g\"" " -e \""$1"\''s/::/:/g\" "} 
                END {print sedtemp,">",profile}' | sh
            [ $? -eq 0 ] &&
                echo "\n * The action was taken successfully." &&
                lssec -f /etc/security/user -s root -a rlogin ||
                echo "\n * The action FAILED, Check...!"
        done
    fi
}

actionSecWeak () {
    echo "\n===[ $1 ]==="
    f_action_$(echo $1|tr -d '-')
    echo "=============="
}

__main__ () {
    LIST="01 16"
    for List in ${LIST};  do
        actionSecWeak U-${List}
    done
}
__main__