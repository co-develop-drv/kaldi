#!/bin/bash

mv result/* result-bak/

# rm result/*
# rm log/*.txt

# list=`ls data/wav`
list=`find data/wav -iname "*.wav"`

groups_array=()

for dir in $list; do
    wav=`basename $dir .wav`
    wav_path=`dirname $dir`
    group_c=$(basename "$wav_path")
#     echo ${group##*-}
#     echo ${group%%-*}

    group=${group_c%%-*}
    if [[ ! "${groups_array[@]}" =~ $group ]] ; then
        groups_array+=("$group")
    fi
    
    output=$(basename "$wav_path")-${wav}
    grep ^${output} log/* >> log/${output}.txt
done

for group in ${groups_array[*]}; do
#     echo $group
    echo "${group}_a1" | tr -d '\n' > result/${group}_a1.txt
    group_count=`find log/ -name "${group}*" | wc -l`
    int=0
    while(( $int<${group_count} ))
    do
        txt=$(cat `find log/ -name "$group-$int-*"`)
        echo $txt | awk -F ' ' '{$1="";printf $0}' >> result/${group}_a1.txt
#         echo $txt | awk -F ' ' '{$1="";printf $0}'| tr -d ' ' >> result/${group}_a1.txt
        let "int++"
    done
    rm log/${group}*
done

cat result/*.txt
