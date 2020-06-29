#!/bin/bash

mv result/* result-bak/

# list=`ls data/wav`
list=`find data/wav -iname "*.wav"`

for dir in $list; do
(
    wav=`basename $dir .wav`
    wav_path=`dirname $dir`
    output=$(basename "$wav_path")-${wav}
    grep ^${output} log/* >> result/${output}.txt
)
done


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
    
#     groups_array[${#groups_array[*]}]=$group
#     groups_array=("${groups_array[@]}" $group)
    output=$(basename "$wav_path")-${wav}
    grep ^${output} log/* >> result/${output}.txt
done

for group in ${groups_array[*]}; do
    echo $group
done

cat result/*.txt
