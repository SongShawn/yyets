#!/bin/bash

#set -x

save_http_proxy=$http_proxy
unset http_proxy

if [ $# -ne 3 ]
then
    echo "$0 0 phone_number password, debug is 0 or 1."
    exit 0
fi

debug=$1
username="$2"
password="$3"
password_md5=`echo -n $password|md5sum|cut -d ' ' -f1`
max_try_time=10

yum install jq curl -y

function debug_print()
    if [ $# -eq 1 ]
    then
        if [ $debug -eq 1 ]
        then
            echo $1
        fi
    fi
vm_cnt=0
for ip in `cat ip_list.txt`
do
    if [[ $ip == \#* ]]
    then
        continue 
    fi
    
    c=0
    while ((c<=max_try_time))
    do
        sleep 1
        ((c++))
        response=`curl -s -m 5 'http://'$ip':10000/node/v2/api/user/login' \
            -H 'Accept: application/json, text/plain, */*' \
            -H 'Referer: http://'$ip':10000/' \
            -H 'Origin: http://'$ip':10000' \
            -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/76.0.3809.132 Safari/537.36' \
            -H 'Content-Type: application/json; charset=UTF-8' \
            --data-binary '{"name":"'$username'","password":"'$password_md5'","version":"1.1.0"}' \
            --compressed --insecure 2>/dev/null`
        debug_print "login response: ["$response"]"
        if [ -z "$response" ] 
        then 
            continue 
        fi

        status=`echo $response | jq -r '.status'`
        if [ $status -ne 1 ] 
        then 
            continue 
        fi
       
        token=`echo $response | jq -r '.data.token'`
        if [ $token'a' == 'a' ]
        then 
            continue 
        else
            echo "****[$ip]**** token is $token"
            break
        fi
    done
    

    # start running
    response=`curl 'http://'$ip':10000/node/v2/api/start?token='$token \
        -H 'Accept: application/json, text/plain, */*' \
        -H 'Connection: keep-alive' \
        -H 'Accept-Encoding: gzip, deflate' \
        -H 'Referer: http://'$ip':10000/' \
        -H 'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8' \
        -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/76.0.3809.100 Safari/537.36' \
        --compressed --insecure 2>/dev/null`
    
    debug_print "start running response: ["$response"]"
    if [ -z "$response" ] 
    then 
        continue 
    fi

    status=`echo $response | jq -r '.status'`
    if [ $status -ne 1 ] 
    then 
        continue 
    fi
    echo "****[$ip]**** start running OK"
   
    # set disk space , max share speed, cache directory
    response=`curl 'http://'$ip':10000/node/v2/api/edit_conf?token='$token \
        -H 'Origin: http://'$ip':10000' \
        -H 'Accept-Encoding: gzip, deflate' \
        -H 'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8' \
        -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/76.0.3809.100 Safari/537.36' \
        -H 'Content-Type: application/json; charset=UTF-8' -H 'Accept: application/json, text/plain, */*' \
        -H 'Referer: http://'$ip':10000/' \
        -H 'Connection: keep-alive' \
        --data-binary '{"CacheDir":"/home/repo","MaxUpSpeed":5,"MaxDiskUsageGB":25,"MinDiskAvailGB":2}' \
        --compressed --insecure 2>/dev/null`

    debug_print "set config response: ["$response"]"
    if [ -z "$response" ] 
    then 
        echo "****[$ip]**** set config failed"
        continue 
    fi

    status=`echo $response | jq -r '.status'`
    if [ $status -ne 1 ] 
    then 
        echo "****[$ip]**** set config failed, status is not 1"
        continue 
    fi
    echo "****[$ip]**** set config OK"

    # get runing status
    response=`curl 'http://'$ip':10000/node/v2/api/status?token='$token \
        -H 'Accept: application/json, text/plain, */*' \
        -H 'Connection: keep-alive' \
        -H 'Accept-Encoding: gzip, deflate' \
        -H 'Referer: http://'$ip':10000/' \
        -H 'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8' \
        -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/76.0.3809.100 Safari/537.36' \
        --compressed --insecure 2>/dev/null`

    debug_print "set config response: ["$response"]"
    if [ -z "$response" ]  
    then 
        echo "****[$ip]**** get status failed"
        continue 
    fi

    status=`echo $response | jq -r '.status'`
    if [ $status -ne 1 ] 
    then 
        echo "****[$ip]**** get status failed, status is not 1"
        continue 
    fi

    data=`echo $response | jq -r '.data'`
    echo "****[$ip]**** get status $data"

    sleep 1
    ((vm_cnt++))
done

echo "vm count: "$vm_cnt

http_proxy=$save_http_proxy
