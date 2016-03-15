#!/bin/bash

if [ $# -lt 7 ]; then
    echo Usage: frame-dl-worker.sh WID LST DST FPS NFR LOC \[MIN_DURATION:-3]
    exit
fi
WID=$1
LST=$2
DST=$3
FPS=$4
NFR=$5
LOC=$6
MIN_DURATION=${7:-3}
keep_fps=`echo "$FPS <= 0" | bc`

echo "worker #$WID initiated."
cache_dir=`printf 'cache.%03d' $WID`
mkdir $cache_dir
mkdir $cache_dir/video

# trap on exit and call cleanup()
trap cleanup EXIT
function cleanup() {
    echo "Stopping worker #$WID (pid $$) ..."
    # kill all child processes
    child_pids=`pgrep -P$$`
    for pid in $child_pids; do
        kill $pid
        wait $pid
    done
    if [ -f $cache_dir/lock ]; then
        curr_vid=`cat $cache_dir/lock`
        if [ ${#curr_vid} -gt 0 ]; then
            rm -rf $DST/$curr_vid
        fi
    fi
    if [ -f $cache_dir/broken.list ]; then
        cat $cache_dir/broken.list >> broken.list
    fi
    if [ -f $cache_dir/skipped.list ]; then
        cat $cache_dir/skipped.list >> skipped.list
    fi
    rm -rf $cache_dir
    exit
}

for vid in `cat $LST`; do
    echo "worker #$WID is working on $vid (pid $$) ..."
    echo $vid > $cache_dir/lock
    youtube-dl -R 3 -q --prefer-ffmpeg -f bestvideo/best -o "$cache_dir/video/%(id)s.%(ext)s" -- $vid
    vname=`ls $cache_dir/video`
    if [ -n "$vname" ]; then
        duration=`ffmpeg -i $cache_dir/video/$vname 2>&1 | grep Duration | awk '{print $2}' | tr -d , | awk -F ':' '{print ($3+$2*60+$1*3600)}'`
        long_enough=`echo "$duration >= $MIN_DURATION" | bc`
        if [[ $long_enough -eq 1 ]]; then
            mkdir $DST/$vid
            if [[ $keep_fps -eq 1 ]]; then
                ffmpeg -v error -noaccurate_seek -ss `echo $duration | awk "{print \$1*$LOC}"` -i $cache_dir/video/$vname -vframes $NFR $DST/$vid/$vid-%04d.jpg
            else
                ffmpeg -v error -noaccurate_seek -ss `echo $duration | awk "{print \$1*$LOC}"` -i $cache_dir/video/$vname -r $FPS -vframes $NFR $DST/$vid/$vid-%04d.jpg
            fi
            nframes=`ls $DST/$vid | wc -l` 
            if [ $nframes -lt $NFR ]; then
                rm -rf $DST/$vid   
                echo $vid >> $cache_dir/skipped.list
            fi
        else
            echo $vid >> $cache_dir/skipped.list
        fi
        rm -rf $cache_dir/video/*
    else
        echo $vid >> $cache_dir/broken.list
    fi
    echo -n "" > $cache_dir/lock
done
