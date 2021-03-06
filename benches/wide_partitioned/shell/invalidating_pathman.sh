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
$PSQL -d $DBNAME -c "create extension if not exists pg_pathman" > /dev/null
$PSQL -d $DBNAME -c "create table if not exists wide_tbl(t timestamp not null, i int)" > /dev/null
ts_dec_hours "$cur_ts" $((START_NUM_PARTS-1)) "%Y-%m-%d %H:00:00"
start_ts=$result
create_parts="select create_range_partitions('wide_tbl', 't', timestamp '$start_ts', interval '1 hour', $START_NUM_PARTS)"
$PSQL -d $DBNAME -c "$create_parts" > /dev/null
for (( i=0; i<$START_NUM_PARTS; i++ )); do
    ts_dec_hours "$cur_ts" $i
    middle_ts=$result
    insert_value="insert into wide_tbl values(timestamp '$middle_ts', $i)"
    $PSQL -d $DBNAME -c "$insert_value" > /dev/null
done

# Incrementally add partitions and run benches
i=$START_NUM_PARTS
while true; do

    # Specify test query that touchs 2 random partitions and main table
    ts_dec_hours "$cur_ts" $(($RANDOM%$i))
    test_start_ts=$result
    ts_inc_hours "$test_start_ts" 1
    test_end_ts=$result
    query="select * from wide_tbl where t between timestamp '$test_start_ts' and timestamp '$test_end_ts'"
    attach_detach_query="select append_range_partition('wide_tbl', 'test'); select drop_range_partition('test')"

    # Make bench
    cmds=""
    for j in $(seq 1 $PREWARM_RUNS); do
        cmds="${cmds} -c \"${query}\""
    done
    for j in $(seq 1 $BENCH_RUNS); do
        cmds="${cmds} -c \"$attach_detach_query\" -c \"\timing\" -c \"$query\" -c \"\timing\""
    done

    # Print number of partitions and time measurements
    printf "$i\t"
    eval $PSQL -d $DBNAME "$cmds" | grep 'Time:' | cut -f2,3 -d' ' | paste -s -

    if (( $(( i+INTERVAL )) > $MAX_NUM_PARTS )); then
        break
    fi

    # Add new partitions
    for (( j=$i; j<$((i+INTERVAL)); j++ )); do
        ts_dec_hours "$cur_ts" $j
        middle_ts=$result
        create_part="select prepend_range_partition('wide_tbl')"
        insert_value="insert into wide_tbl values(timestamp '$middle_ts', $j)"
        $PSQL -d $DBNAME -c "$create_part" -c "$insert_value" > /dev/null
    done
    i=$j
done

# Remove partitioned table
$PSQL -d $DBNAME -c "drop table wide_tbl cascade" > /dev/null 2>&1
$PSQL -d $DBNAME -c "drop extension pg_pathman cascade" > /dev/null 2>&1
