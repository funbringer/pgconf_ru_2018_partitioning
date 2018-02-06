/* https://github.com/maksm90/postgresql/tree/master */


drop table if exists foo cascade;

create table foo (i int, j int) partition by list (i);
create table foo_1 partition of foo for values in (1);
create table foo_2 partition of foo for values in (2);
create table foo_3 partition of foo for values in (3);

insert into foo select i%3+1, (1000*random())::int from generate_series(1, 1000000) i;

vacuum analyze;



-- Disable parallel appends
set enable_parallel_append to off;

explain (costs off, analyze, timing off, verbose) select * from foo where j=10;
/*
                               QUERY PLAN
-------------------------------------------------------------------------
 Gather (actual rows=1022 loops=1)
   Output: foo_1.i, foo_1.j
   Workers Planned: 1
   Workers Launched: 1
   ->  Append (actual rows=511 loops=2)
         Worker 0: actual rows=521 loops=1
         ->  Parallel Seq Scan on public.foo_1 (actual rows=170 loops=2)
               Output: foo_1.i, foo_1.j
               Filter: (foo_1.j = 10)
               Rows Removed by Filter: 166496
               Worker 0: actual rows=150 loops=1
         ->  Parallel Seq Scan on public.foo_2 (actual rows=174 loops=2)
               Output: foo_2.i, foo_2.j
               Filter: (foo_2.j = 10)
               Rows Removed by Filter: 166493
               Worker 0: actual rows=190 loops=1
         ->  Parallel Seq Scan on public.foo_3 (actual rows=167 loops=2)
               Output: foo_3.i, foo_3.j
               Filter: (foo_3.j = 10)
               Rows Removed by Filter: 166500
               Worker 0: actual rows=181 loops=1
 Planning time: 0.298 ms
 Execution time: 55.400 ms
(23 rows)
*/


-- Disable parallel scan for specific partition
alter table foo_1 set (parallel_workers = 0);

explain (costs off, analyze, timing off, verbose) select * from foo where j=10;
/*
                        QUERY PLAN
----------------------------------------------------------
 Append (actual rows=1022 loops=1)
   ->  Seq Scan on public.foo_1 (actual rows=340 loops=1)
         Output: foo_1.i, foo_1.j
         Filter: (foo_1.j = 10)
         Rows Removed by Filter: 332993
   ->  Seq Scan on public.foo_2 (actual rows=348 loops=1)
         Output: foo_2.i, foo_2.j
         Filter: (foo_2.j = 10)
         Rows Removed by Filter: 332986
   ->  Seq Scan on public.foo_3 (actual rows=334 loops=1)
         Output: foo_3.i, foo_3.j
         Filter: (foo_3.j = 10)
         Rows Removed by Filter: 332999
 Planning time: 0.518 ms
 Execution time: 67.793 ms
(15 rows)
*/


-- Enable parallel append
set enable_parallel_append to on;

explain (costs off, analyze, timing off, verbose) select * from foo where j=10;
/*
                               QUERY PLAN
-------------------------------------------------------------------------
 Gather (actual rows=1022 loops=1)
   Output: foo_1.i, foo_1.j
   Workers Planned: 2
   Workers Launched: 2
   ->  Parallel Append (actual rows=341 loops=3)
         Worker 0: actual rows=312 loops=1
         Worker 1: actual rows=340 loops=1
         ->  Seq Scan on public.foo_1 (actual rows=340 loops=1)
               Output: foo_1.i, foo_1.j
               Filter: (foo_1.j = 10)
               Rows Removed by Filter: 332993
               Worker 1: actual rows=340 loops=1
         ->  Parallel Seq Scan on public.foo_2 (actual rows=174 loops=2)
               Output: foo_2.i, foo_2.j
               Filter: (foo_2.j = 10)
               Rows Removed by Filter: 166493
               Worker 0: actual rows=312 loops=1
         ->  Parallel Seq Scan on public.foo_3 (actual rows=334 loops=1)
               Output: foo_3.i, foo_3.j
               Filter: (foo_3.j = 10)
               Rows Removed by Filter: 332999
 Planning time: 0.302 ms
 Execution time: 31.369 ms
(23 rows)
*/
