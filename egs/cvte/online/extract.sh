#!/bin/bash

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

cat result/*.txt
