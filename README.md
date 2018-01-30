## Benchmarks

### Latency degradation under the large number of partitions

1. Partitioning via inheritance

  ```bash benchs/wide_partitioned/inh.sh```

  Before running you have to setup the bash global variables:
  - PSQL - path to psql client to postgres
  - DBNAME - name of database to connect
  - START\_NUM_PARTS - initial number of partitions before running benchmark
  - MAX\_NUM_PARTS - maximum number of partitions in benchmark
  - INTERVAL - difference in number of partitions between runnings of benchmark
  - PREWARM_RUNS - numbers of test runnings to prewarm session cache
  - BENCH_RUNS - number of benchmark runnings

  This script prints to stdout the number of partitions and multiple (BENCH_RUNS) measurements of latency (in ms) of query that selects two partitions and main parent table based on condition in query.
