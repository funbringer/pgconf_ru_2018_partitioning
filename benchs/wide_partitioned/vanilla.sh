#!/bin/bash

# Connection info
PSQL=${PSQL:-/usr/local/bin/psql}" -X -q"
DBNAME=${DBNAME:-postgres}

# Constants
START_NUM_PARTS=${START_NUM_PARTS:-10}
MAX_NUM_PARTS=${MAX_NUM_PARTS:-100}
INTERVAL=${INTERVAL:-10}
PREWARM_RUNS=${PREWARM_RUNS:-5}
BENCH_RUNS=${BENCH_RUNS:-5}

# Global variables
cur_ts=`date +"%Y-%m-%d %H:%M:%S"`

function ts_inc_hours()
{
    result=`date --date="$1 $2 hour" +"${3:-"%Y-%m-%d %H:%M:%S"}"`
    # result=`date -j -f "%Y-%m-%d %H:%M:%S" -v+$2H "$1" +"${3:-"%Y-%m-%d %H:%M:%S"}"`
}
function ts_dec_hours()
{
    result=`date --date="$1 $2 hour ago" +"${3:-"%Y-%m-%d %H:%M:%S"}"`
    # result=`date -j -f "%Y-%m-%d %H:%M:%S" -v-$2H "$1" +"${3:-"%Y-%m-%d %H:%M:%S"}"`
}

# Init partitioned table
$PSQL -d $DBNAME -c "create table if not exists wide_tbl(t timestamp, i int) partition by range(t)" > /dev/null
for (( i=0; i<$START_NUM_PARTS; i++ )); do
    ts_dec_hours "$cur_ts" $i "%Y-%m-%d %H:00:00"
    start_ts=$result
    ts_dec_hours "$cur_ts" $i
    middle_ts=$result
    ts_inc_hours "$start_ts" 1
    end_ts=$result

    create_part="create table if not exists wide_tbl_$i partition of wide_tbl for values from ('$start_ts') to ('$end_ts')"
    insert_value="insert into wide_tbl_$i values(timestamp '$middle_ts', $i)"
    $PSQL -d $DBNAME -c "$create_part" -c "$insert_value" > /dev/null
done

# Incrementally add partitions and run benchs
i=$START_NUM_PARTS
while true; do

    # Specify test query that touchs 2 random partitions and main table
    ts_dec_hours "$cur_ts" $(($RANDOM%$i))
    test_start_ts=$result
    ts_inc_hours "$test_start_ts" 1
    test_end_ts=$result
    query="select * from wide_tbl where t between timestamp '$test_start_ts' and timestamp '$test_end_ts'"

    # Make bench
    cmds=""
    for j in $(seq 1 $PREWARM_RUNS); do
        cmds="${cmds} -c \"${query}\""
    done
    cmds="${cmds} -c \"\timing\""
    for j in $(seq 1 $BENCH_RUNS); do
        cmds="${cmds} -c \"$query\""
    done

    # Print number of partitions and time measurements
    printf "$i\t"
    eval $PSQL -d $DBNAME "$cmds" | grep 'Time:' | cut -f2,3 -d' ' | paste -s -

    if (( $(( i+INTERVAL )) > $MAX_NUM_PARTS )); then
        break
    fi

    # Add new partitions
    for (( j=$i; j<$((i+INTERVAL)); j++ )); do
        ts_dec_hours "$cur_ts" $j "%Y-%m-%d %H:00:00"
        start_ts=$result
        ts_dec_hours "$cur_ts" $j
        middle_ts=$result
        ts_inc_hours "$start_ts" 1
        end_ts=$result
        create_part="create table if not exists wide_tbl_$j partition of wide_tbl for values from ('$start_ts') to ('$end_ts')"
        insert_value="insert into wide_tbl_$j values(timestamp '$middle_ts', $j)"
        $PSQL -d $DBNAME -c "$create_part" -c "$insert_value" > /dev/null
    done
    i=$j
done

# Remove partitioned table
$PSQL -d $DBNAME -c "drop table wide_tbl cascade" > /dev/null 2>&1
