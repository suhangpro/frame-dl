#!/bin/bash

if [ $# -lt 2 ]; then
    echo Usage: rm_partial.sh DST NFR
    exit
fi

for vid in `ls $1`; do
    nframes=`ls $1/$vid | wc -l`
    if [ $nframes -lt $2 ]; then
        rm -rf $1/$vid
        echo $vid removed - $nframes
    fi
done
