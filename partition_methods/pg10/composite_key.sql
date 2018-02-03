create table foo (
    d date not null
) partition by range (EXTRACT(YEAR FROM d), EXTRACT(MONTH FROM d));

create table if not exists foo_2017_1 partition of foo for values from (2017, 1) to (2017, 2);
create table if not exists foo_2017_2 partition of foo for values from (2017, 2) to (2017, 3);
...
create table if not exists foo_2018_11 partition of foo for values from (2018, 11) to (2018, 12);

# explain (costs off) select * from foo where EXTRACT(MONTH FROM d) = 2;
                                              QUERY PLAN
------------------------------------------------------------------------------------------------------
 Append
   ->  Seq Scan on foo_2017_2
         Filter: (date_part('month'::text, (d)::timestamp without time zone) = '2'::double precision)
   ->  Seq Scan on foo_2018_2
         Filter: (date_part('month'::text, (d)::timestamp without time zone) = '2'::double precision)
(5 rows)
