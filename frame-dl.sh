#!/bin/bash

if [ $# -lt 2 ]; then
    echo Usage: frame-dl.sh LST DST \[NWK:-1 FPS:-0 NFR:-16 LOC:-0.5]
    exit
fi
LST=$1
DST=$2
NWK=${3:-1}
FPS=${4:-0}
NFR=${5:-16}
LOC=${6:-0.5}

# find videos that are not yet processed
if [ ! -f broken.list ]; then 
    touch broken.list
fi
if [ ! -f skipped.list ]; then 
    touch skipped.list
fi
comm -23 <(comm -23 <(comm -23 <(sort $LST) <(ls $DST)) <(sort broken.list)) <(sort skipped.list) > targets-all
split -n l/$NWK -d -a 3 targets-all targets.

# start processes to do work
for worker in `seq 0 $(($NWK-1))`; do
    ./frame-dl-worker.sh $worker `printf 'targets.%03d' $worker` $DST $RES $FPS $NFR $LOC &
done 

# trap on exit and call kill_workers()
trap kill_workers EXIT
worker_pids=`pgrep -P$$`
function kill_workers() {
    # kill all child processes
    for pid in $worker_pids; do
        kill $pid
	wait $pid
    done
    rm targets-all targets.*    
    exit
}

# wait for command (q -- quit)
while [ -z "$cmd" ] || [ "$cmd" != q ]; do 
    read -p "Command (q--quit,i--info): " cmd
    case $cmd in
        quit|exit|q)
            cmd=q
            ;;
        info|i)
            echo -e `ls $DST | wc -l` videos processed/being processed. \
                `pgrep -c -P$$` workers are running.
            ;;
    esac
done

