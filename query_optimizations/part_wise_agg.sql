create table foo (i int, t timestamp) partition by range (t);
create table foo_2018_01 partition of foo for values from ('2018-01-01') to ('2018-02-01');
create table foo_2018_02 partition of foo for values from ('2018-02-01') to ('2018-03-01');
create table foo_2018_03 partition of foo for values from ('2018-03-01') to ('2018-04-01');

-- Fill in random data
insert into foo
select (random()*100)::int,
       timestamp '2018-01-01' + random() * (timestamp '2018-04-01' - timestamp '2018-01-01')
from generate_series(1, 1000000) i;

# explain (analyze, costs off, timing off) select i, count(*) from foo group by i;
                            QUERY PLAN
------------------------------------------------------------------
 HashAggregate (actual rows=101 loops=1)
   Group Key: foo_2018_01.i
   ->  Append (actual rows=1010000 loops=1)
         ->  Seq Scan on foo_2018_01 (actual rows=347767 loops=1)
         ->  Seq Scan on foo_2018_02 (actual rows=315078 loops=1)
         ->  Seq Scan on foo_2018_03 (actual rows=347155 loops=1)
 Planning time: 0.208 ms
 Execution time: 659.298 ms
(8 rows)

-- Enable partition-wise aggregate
set enable_partition_wise_agg to on;

# explain (analyze, costs off, timing off) select i, count(*) from foo group by i;
                                  QUERY PLAN
------------------------------------------------------------------------------
 Finalize GroupAggregate (actual rows=101 loops=1)
   Group Key: foo_2018_01.i
   ->  Sort (actual rows=303 loops=1)
         Sort Key: foo_2018_01.i
         Sort Method: quicksort  Memory: 41kB
         ->  Append (actual rows=303 loops=1)
               ->  Partial HashAggregate (actual rows=101 loops=1)
                     Group Key: foo_2018_01.i
                     ->  Seq Scan on foo_2018_01 (actual rows=347767 loops=1)
               ->  Partial HashAggregate (actual rows=101 loops=1)
                     Group Key: foo_2018_02.i
                     ->  Seq Scan on foo_2018_02 (actual rows=315078 loops=1)
               ->  Partial HashAggregate (actual rows=101 loops=1)
                     Group Key: foo_2018_03.i
                     ->  Seq Scan on foo_2018_03 (actual rows=347155 loops=1)
 Planning time: 0.425 ms
 Execution time: 597.272 ms
(17 rows)

-- Enable parallel append
set enable_parallel_append to on;
set max_parallel_workers_per_gather to 2;

# explain (analyze, costs off, timing off) select i, count(*) from foo group by i;
                                         QUERY PLAN
---------------------------------------------------------------------------------------------
 Finalize GroupAggregate (actual rows=101 loops=1)
   Group Key: foo_2018_01.i
   ->  Sort (actual rows=606 loops=1)
         Sort Key: foo_2018_01.i
         Sort Method: quicksort  Memory: 58kB
         ->  Gather (actual rows=606 loops=1)
               Workers Planned: 2
               Workers Launched: 2
               ->  Parallel Append (actual rows=202 loops=3)
                     ->  Partial HashAggregate (actual rows=101 loops=3)
                           Group Key: foo_2018_01.i
                           ->  Parallel Seq Scan on foo_2018_01 (actual rows=115922 loops=3)
                     ->  Partial HashAggregate (actual rows=101 loops=2)
                           Group Key: foo_2018_03.i
                           ->  Parallel Seq Scan on foo_2018_03 (actual rows=173578 loops=2)
                     ->  Partial HashAggregate (actual rows=101 loops=1)
                           Group Key: foo_2018_02.i
                           ->  Parallel Seq Scan on foo_2018_02 (actual rows=315078 loops=1)
 Planning time: 0.463 ms
 Execution time: 284.889 ms
(20 rows)

-- Add foreign partitions
create extension postgres_fdw;
create server loopback foreign data wrapper postgres_fdw options (dbname 'postgres', port '5432');
alter table foo detach partition foo_2018_01;
alter table foo detach partition foo_2018_02;
alter table foo detach partition foo_2018_03;

alter table foo attach partition f_foo_2018_01 for values from ('2018-01-01') to ('2018-02-01');
alter table foo attach partition f_foo_2018_02 for values from ('2018-02-01') to ('2018-03-01');
alter table foo attach partition f_foo_2018_03 for values from ('2018-03-01') to ('2018-04-01');

-- Simple aggregate doesn't push down under foreign scan
# explain (costs off, verbose) select avg(i) from foo;
                            QUERY PLAN
------------------------------------------------------------------
 Finalize Aggregate
   Output: avg(f_foo_2018_01.i)
   ->  Append
         ->  Partial Aggregate
               Output: PARTIAL avg(f_foo_2018_01.i)
               ->  Foreign Scan on public.f_foo_2018_01
                     Output: f_foo_2018_01.i
                     Remote SQL: SELECT i FROM public.foo_2018_01
         ->  Partial Aggregate
               Output: PARTIAL avg(f_foo_2018_02.i)
               ->  Foreign Scan on public.f_foo_2018_02
                     Output: f_foo_2018_02.i
                     Remote SQL: SELECT i FROM public.foo_2018_02
         ->  Partial Aggregate
               Output: PARTIAL avg(f_foo_2018_03.i)
               ->  Foreign Scan on public.f_foo_2018_03
                     Output: f_foo_2018_03.i
                     Remote SQL: SELECT i FROM public.foo_2018_03
(18 rows)

-- But aggregates grouped by partition key pushes down
# explain (costs off, verbose) select t, avg(i) from foo group by t;
                               QUERY PLAN
-------------------------------------------------------------------------
 Append
   ->  Foreign Scan
         Output: f_foo_2018_01.t, (avg(f_foo_2018_01.i))
         Relations: Aggregate on (public.f_foo_2018_01 foo)
         Remote SQL: SELECT t, avg(i) FROM public.foo_2018_01 GROUP BY 1
   ->  Foreign Scan
         Output: f_foo_2018_02.t, (avg(f_foo_2018_02.i))
         Relations: Aggregate on (public.f_foo_2018_02 foo)
         Remote SQL: SELECT t, avg(i) FROM public.foo_2018_02 GROUP BY 1
   ->  Foreign Scan
         Output: f_foo_2018_03.t, (avg(f_foo_2018_03.i))
         Relations: Aggregate on (public.f_foo_2018_03 foo)
         Remote SQL: SELECT t, avg(i) FROM public.foo_2018_03 GROUP BY 1
(13 rows)
