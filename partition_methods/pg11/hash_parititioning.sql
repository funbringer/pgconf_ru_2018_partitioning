create table foo (i int) partition by hash (i);

create table foo_1 partition of foo for values with (modulus 2, remainder 0);
create table foo_2 partition of foo for values with (modulus 2, remainder 1);

alter table foo detach partition foo_1;

create table foo_1_1 partition of foo for values with (modulus 6, remainder 0);
create table foo_1_2 partition of foo for values with (modulus 6, remainder 2);
create table foo_1_3 partition of foo for values with (modulus 6, remainder 4);

-- Move data from foo_1 to foo_1_*

explain (costs off) select * from foo where i = 34;
/*
        QUERY PLAN
---------------------------
 Append
   ->  Seq Scan on foo_1_1
         Filter: (i = 34)
(3 rows)
*/
