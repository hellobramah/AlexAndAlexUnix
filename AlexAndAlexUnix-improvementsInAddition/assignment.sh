#!/bin/bash

# flagn sets -n: this argument is to declare the number of results 
# flagc sets -c: this argument is to show which IP address makes the most number of connection attempts
# flag2 sets -2: this argument is to show which address makes the most number of successful attempts
# flagr sets -r: this argument is to show what the most common results codes and where they come from
# flagF sets -F: this argument is to show the most common result codes that indicate failure (no auth, not found etc) and where they come from
# flagt sets -t: this argument is to show which IP number get the most bytes sent to them
# flage sets -e: this argument implements the optional feature to show which IP address is blacklisted
# fileflag this argument is used for file processing for checking if a file exists, has been supplied at command line and for reading of a file

#declare flags for each argument and initialize them to zero

flagn=0 
flagc=0
flag2=0
flagr=0
flagF=0
flagt=0
flage=0
fileflag=0

# set n to a default value of one that there may be at least one ip value displayed, n is not allowed to be zero
n=1

#record stdout
exec 6>&1

#record arguements
while getopts "n:c2rFte" opt; 
do
    case $opt in
        n) 
            re='^[0-9]+$'
            if ! [[ "$OPTARG" =~ $re ]]
            then
                echo Error: incorrect arguement "n"
                exit 
            fi
            n=$OPTARG
            flagn=1;;
        c) 
            flagc=1;;
        2) 
            flag2=1;;
        r) 
            flagr=1;;
        F) 
            flagF=1;;
        t) 
            flagt=1;;
        e)
            flage=1;;
    esac
done

#check arguements at least -c|-2|-r|-F|-t must be given, if not that is an error condition.
#to check this we create a sum variable which is a sum of $flagc, $flag2, $flagr,$flagF, $flagt if sum = 0 then it means that neither -c|-2|-r|-F|-t have been passed as an argument and this is an error condition
let "sum = $flagc + $flag2 + $flagr + $flagF + $flagt"
if [ $sum = 0 ]       
then 
    echo "Error: incorrect arguements: please supply either -c|-2|-r|-F|-t as an argument"
    exit
fi

#get filepath 
shift $(($OPTIND - 1)) # this removes all other arguments so that $1 points to the file path
filepath=$1
if [ x"$filepath" != x"-" ]
then 
    if [ -f "$filepath" ]
    then
        fileflag=1
    fi
fi

#if no file name is given or the file does not exist read from stdin
if [ $fileflag = 0 ]
then
    filepath=$(mktemp -t $$.XXX)
    while read line
    do
        echo $line >> $filepath
    done
fi

#If the -e operation is specified, then redirect the stdout to a tempfile
if [ $flage = 1 ]
then
    efunctionstdout=$(mktemp -t $$.XXX)
    exec 1>$efunctionstdout
fi      

#process arguements
# -c
if [ $flagc = 1 ]
then
    if [ $sum != 1 ]
    then
        echo -c:
    fi
    cut -f 1 -d ' ' $filepath | sort | uniq -c | sort -n -r| head -$n | awk '{print $2 "\t" $1}' 
fi

# -2
if [ $flag2 = 1 ]
then
    if [ $sum != 1 ]
    then 
        echo -2:
    fi
    cut -f 1,9 -d ' ' $filepath | grep "[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\ 2" | sort | uniq -c | sort -n -r | head -$n | awk '{print $2 "\t" $1}'
fi

# -r
if [ $flagr = 1 ]
then
    if [ $sum != 1 ]
    then 
        echo -r:
    fi
    cut -f 9 -d ' ' $filepath | sort | uniq -c | sort -n -r | head -1 | awk '{print "[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\ "$2}' | grep -f - <(cut -f 1,9 -d ' ' $filepath | sort | uniq ) | head -$n | awk '{print $2 "\t" $1}'
fi

# -F
if [ $flagF = 1 ]
then
    if [ $sum != 1 ]
    then 
        echo -F:
    fi
    cut -f 9 -d ' ' $filepath | grep -E [4,5][0-9]{2} | sort | uniq -c | sort -n -r | head -1 | awk '{print "[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\ "$2}' | grep -f - <(cut -f 1,9 -d ' ' $filepath | sort | uniq) | head -$n | awk '{print $2 "\t" $1}'
fi

# -t
if [ $flagt = 1 ]
then
    if [ $sum != 1 ]
    then 
        echo -t:
    fi

    text=$(cut -d ' ' -f 1 $filepath | sort | uniq)
    tempfilepath=$(mktemp -t $$.XXX)
    for each_ip in $text
    do
        sum=0
        results=$(cut -d ' ' -f 1,10 $filepath | grep "$each_ip\ [0-9]" | awk '{print $2}')
        for each_number in $results
        do
            let "sum = $sum + $each_number"
        done
        echo -e $each_ip"\t"$sum >> $tempfilepath
    done
    cat $tempfilepath | sort -n -k 2 -r | head -$n
fi

#-e
exec 1>&6
blacklistpath=
if [ $flage = 1 ]
then
    if [ x"$2" = x ]
    then
        blacklistpath=dns.blacklist.txt
    else
        blacklistpath=$2
    fi
    if ! [ -f $blacklistpath ]
    then 
        echo The blacklist file does not exist.
        exit 
    fi

    blacklist=$(cat $blacklistpath)
    blockedipaddresses=
    for each_domain in $blacklist
    do
        ip=$(dig +short $each_domain)
        for each_ip in $ip
        do
            blockedipaddresses=$blockedipaddresses" $each_ip"
        done
    done 
    while read line
    do
        match=$(echo $line | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | grep -f - <(echo $blockedipaddresses))
        if [ x"$match" = x ]
        then
            echo $line | awk '{ print $1 "\t" $2 }'
        else
            echo $line | awk '{ print $1 "\t" $2 "\tBlacklisted" }'
        fi
    done < $efunctionstdout
fi

#remove all tempfiles
rm -f /tmp/$$.*
