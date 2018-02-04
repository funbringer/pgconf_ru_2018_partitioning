create table foo (i int, j int) partition by list (i);
create table foo_1 partition of foo for values in (1);
create table foo_2 partition of foo for values in (2);
create table foo_3 partition of foo for values in (3);
insert into foo select i%2, (1000*random())::int from generate_series(1, 1000000) i;

set enable_parallel_append to off;

# explain (costs off, analyze, timing off, verbose) select * from foo where j=10;
                               QUERY PLAN
-------------------------------------------------------------------------
 Gather (actual rows=992 loops=1)
   Output: foo_1.i, foo_1.j
   Workers Planned: 2
   Workers Launched: 2
   ->  Append (actual rows=331 loops=3)
         Worker 0: actual rows=293 loops=1
         Worker 1: actual rows=309 loops=1
         ->  Parallel Seq Scan on public.foo_1 (actual rows=113 loops=3)
               Output: foo_1.i, foo_1.j
               Filter: (foo_1.j = 10)
               Rows Removed by Filter: 110998
               Worker 0: actual rows=92 loops=1
               Worker 1: actual rows=101 loops=1
         ->  Parallel Seq Scan on public.foo_2 (actual rows=109 loops=3)
               Output: foo_2.i, foo_2.j
               Filter: (foo_2.j = 10)
               Rows Removed by Filter: 111002
               Worker 0: actual rows=112 loops=1
               Worker 1: actual rows=90 loops=1
         ->  Parallel Seq Scan on public.foo_3 (actual rows=108 loops=3)
               Output: foo_3.i, foo_3.j
               Filter: (foo_3.j = 10)
               Rows Removed by Filter: 111003
               Worker 0: actual rows=89 loops=1
               Worker 1: actual rows=118 loops=1
 Planning time: 0.528 ms
 Execution time: 115.811 ms
(27 rows)

-- Disable parallel scan for specific partition
alter table foo_1 set (parallel_workers = 0);

# explain (costs off, analyze, timing off, verbose) select * from foo where j=10;
                        QUERY PLAN
----------------------------------------------------------
 Append (actual rows=992 loops=1)
   ->  Seq Scan on public.foo_1 (actual rows=339 loops=1)
         Output: foo_1.i, foo_1.j
         Filter: (foo_1.j = 10)
         Rows Removed by Filter: 332994
   ->  Seq Scan on public.foo_2 (actual rows=328 loops=1)
         Output: foo_2.i, foo_2.j
         Filter: (foo_2.j = 10)
         Rows Removed by Filter: 333006
   ->  Seq Scan on public.foo_3 (actual rows=325 loops=1)
         Output: foo_3.i, foo_3.j
         Filter: (foo_3.j = 10)
         Rows Removed by Filter: 333008
 Planning time: 0.291 ms
 Execution time: 202.859 ms
(15 rows)

-- Enable parallel append
set enable_parallel_append to on;

# explain (costs off, analyze, timing off, verbose) select * from foo where j=10;
                               QUERY PLAN
-------------------------------------------------------------------------
 Gather (actual rows=992 loops=1)
   Output: foo_1.i, foo_1.j
   Workers Planned: 2
   Workers Launched: 2
   ->  Parallel Append (actual rows=331 loops=3)
         Worker 0: actual rows=257 loops=1
         Worker 1: actual rows=339 loops=1
         ->  Seq Scan on public.foo_1 (actual rows=339 loops=1)
               Output: foo_1.i, foo_1.j
               Filter: (foo_1.j = 10)
               Rows Removed by Filter: 332994
               Worker 1: actual rows=339 loops=1
         ->  Parallel Seq Scan on public.foo_2 (actual rows=164 loops=2)
               Output: foo_2.i, foo_2.j
               Filter: (foo_2.j = 10)
               Rows Removed by Filter: 166503
               Worker 0: actual rows=257 loops=1
         ->  Parallel Seq Scan on public.foo_3 (actual rows=325 loops=1)
               Output: foo_3.i, foo_3.j
               Filter: (foo_3.j = 10)
               Rows Removed by Filter: 333008
 Planning time: 0.547 ms
 Execution time: 138.238 ms
(23 rows)
