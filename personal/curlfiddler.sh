#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin && export PATH
# Usage: 
## 保存fiddler获取的session到文件后使用curl重构请求获取执行结果

#
[[ $# != 0 ]] && all_parameter=($(echo $@)) || { echo 'Err  !!! Useage: bash this_script.sh filename function_name'; exit 1; }

#
filename="$1"
themethod=$(cat $filename | head -n1 | cut -f1 -d' ')
gettheurl=$(cat $filename | head -n1 | cut -f2 -d' ')
cookiepart="$(cat $filename | grep -oE "^Cookie:.*" | sed -e "s/$/'/g" -e "s/^/-H '&/g")"
otherparts="$(cat $filename | sed "s/^$/sneogmentmarkone/g" | sed ':a;N;$!ba;s/\n/ sneogmentmarktwo /g' | awk -F"sneogmentmarkone" '{print $1}' | awk -F" sneogmentmarktwo " '{for (i=2; i<NF; i++) print $i }' | sed -e "s/$/'/g" -e "s/^/-H '&/g" | tr "\n" " ")"

function request() {
    if [[ $themethod == "POST" ]]; then
        isdata="$(cat $filename | sed "s/^$/sneogmentmarkone/g" | sed ':a;N;$!ba;s/\n/ sneogmentmarktwo /g' | awk -F"sneogmentmarkone" '{print $2}' | awk -F" sneogmentmarktwo " '{for (i=2; i<=2; i++) print $i }')"
        eval curl -sX $themethod $otherparts $gettheurl --data "$isdata"
    else
        eval curl -sX $themethod $otherparts $gettheurl
    fi
}

function composer(){
    composerurls=""
    composerdata=""
    eval curl -sX $themethod $otherparts $composerurls --data "$composerdata"
}

function echocookie(){
    # 显示curl可以使用的cookie格式
    cat $filename | grep -oE "^Cookie:.*" | sed "s/ //g"
}

echo ${all_parameter[*]} | grep -qE "request" && request
echo ${all_parameter[*]} | grep -qE "composer" && composer
echo ${all_parameter[*]} | grep -qE "echocookie" && echocookie