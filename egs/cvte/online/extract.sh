#!/bin/bash

# list=`ls data/wav`
list=`find data/wav -iname "*.wav"`

for dir in $list; do
(
    wav=`basename $dir .wav`
    grep ^$wav log/* > result.txt
)
done 
