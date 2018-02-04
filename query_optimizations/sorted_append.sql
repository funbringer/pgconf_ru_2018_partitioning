-- Branch sorted_append

create table foo(i int, t timestamp) partition by range (t);
create table foo_2018_1 partition of foo for values from ( '2018-01-01') to ('2018-02-01');
create table foo_2018_2 partition of foo for values from ( '2018-02-01') to ('2018-03-01');
create table foo_2018_3 partition of foo for values from ( '2018-03-01') to ('2018-04-01');

-- create index on foo(t desc);
create index on foo_2018_1(t desc);
create index on foo_2018_2(t desc);
create index on foo_2018_3(t desc);

insert into foo select i, timestamp '2018-01-01' + random() * (timestamp '2018-04-01' - timestamp '2018-01-01') from generate_series(1, 1000) i;

-- Sorted append
# explain (costs off, analyze, timing off) select i from foo order by t desc limit 10;
                                      QUERY PLAN
--------------------------------------------------------------------------------------
 Limit (actual rows=10 loops=1)
   ->  Append (actual rows=10 loops=1)
         Sort Key: foo_2018_3.t DESC
         ->  Index Scan using foo_2018_3_t_idx on foo_2018_3 (actual rows=10 loops=1)
         ->  Index Scan using foo_2018_2_t_idx on foo_2018_2 (never executed)
         ->  Index Scan using foo_2018_1_t_idx on foo_2018_1 (never executed)
 Planning time: 0.826 ms
 Execution time: 0.116 ms
(8 rows)

-- Without optimization
# explain (costs off, analyze, timing off) select i from foo order by t desc limit 10;
                             QUERY PLAN
--------------------------------------------------------------------
 Limit (actual rows=10 loops=1)
   ->  Sort (actual rows=10 loops=1)
         Sort Key: foo_2018_1.t DESC
         Sort Method: top-N heapsort  Memory: 25kB
         ->  Append (actual rows=1000 loops=1)
               ->  Seq Scan on foo_2018_1 (actual rows=329 loops=1)
               ->  Seq Scan on foo_2018_2 (actual rows=298 loops=1)
               ->  Seq Scan on foo_2018_3 (actual rows=373 loops=1)
 Planning time: 1.264 ms
 Execution time: 0.671 ms
(10 rows)
