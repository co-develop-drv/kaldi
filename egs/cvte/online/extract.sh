#!/bin/bash

# list=`ls data/wav`
list=`find data/wav -iname "*.wav"`
echo '' > result.txt

for dir in $list; do
(
    wav=`basename $dir .wav`
    grep ^$wav log/* >> result.txt
)
done 

cat result.txt
