create table foo (a int, b int) partition by hash (a);

-- Initial partitioning schema
create table hot_foo partition of foo for values with (modulus 2, remainder 0);
create table rest_foo partition of foo for values with (modulus 2, remainder 1);

-- Break hot patition
alter table foo detach partition hot_foo;
create table parted_hot_foo partition of foo for values with (modulus 2, remainder 0) partition by list (a);

-- Segregate hot items into partition
create table hot_foo_items partition of parted_hot_foo for values in (123) partition by hash (b);
create table hot_foo_rest partition of parted_hot_foo default;

-- Break hot item to different partitions
create table hot_foo_items_1 partition of hot_foo_items for values with (modulus 2, remainder 0);
create table hot_foo_items_2 partition of hot_foo_items for values with (modulus 2, remainder 1);

-- Query to not hot partition
# explain (costs off) select * from foo where a = 4;
         QUERY PLAN
----------------------------
 Append
   ->  Seq Scan on rest_foo
         Filter: (a = 4)
(3 rows)
 
-- Query to hot item with additional parameter
# explain (costs off) select * from foo where a = 123 and b=0;
               QUERY PLAN
-----------------------------------------
 Append
   ->  Seq Scan on hot_foo_items_1
         Filter: ((a = 123) AND (b = 0))
(3 rows)

-- Query to not hot item in the hot parent partition
# explain (costs off) select * from foo where a = 125;
           QUERY PLAN
--------------------------------
 Append
   ->  Seq Scan on hot_foo_rest
         Filter: (a = 125)
(3 rows)
