## Benchmarks

### Latency degradation under the large number of partitions

1. Partitioning via inheritance

    ```bash benchs/wide_partitioned/inh.sh```

    Before running you have to setup the environment variables:
    - PSQL - path to psql client to postgres, default "/usr/local/bin/psql"
    - DBNAME - name of database to connect, default "postgres"
    - START\_NUM_PARTS - initial number of partitions before running benchmark, default 10
    - MAX\_NUM_PARTS - maximum number of partitions in benchmark, default 100
    - INTERVAL - difference in number of partitions between runnings of benchmark, default 10
    - PREWARM_RUNS - numbers of test runnings to prewarm session cache, default 5
    - BENCH_RUNS - number of benchmark runnings, default 5

    This script prints to stdout the number of partitions and multiple (BENCH_RUNS) measurements of latency (in ms) of query that selects two partitions and main parent table based on condition in query.

2. Partitioning via pg_pathman

    ```bash benchs/wide_partitioned/pathman.sh```

    Environment variables are the same as before.
