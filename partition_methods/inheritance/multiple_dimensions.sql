CREATE OR REPLACE FUNCTION public.hash_mod(value integer, mod integer)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $function$
    select ((hashint4(value) + 2147483648) % mod)::integer;
$function$;

create table foo(i integer, t timestamp);
create table foo_1_1 (check(t >= '2018-01-01' and t < '2018-02-01' and hash_mod(i, 2) = 0)) inherits (foo);
create table foo_1_2 (check(t >= '2018-01-01' and t < '2018-02-01' and hash_mod(i, 2) = 1)) inherits (foo);
create table foo_2_1 (check(t >= '2018-02-01' and t < '2018-03-01' and hash_mod(i, 2) = 0)) inherits (foo);
create table foo_2_2 (check(t >= '2018-02-01' and t < '2018-03-01' and hash_mod(i, 2) = 1)) inherits (foo);

explain (costs off) select * from foo where t between '2018-01-01 03:00:00' and '2018-01-01 06:00:00';
/*
                                                                    QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------------------------
 Append
    ->  Seq Scan on foo
            Filter: ((t >= '2018-01-01 03:00:00'::timestamp without time zone) AND (t <= '2018-01-01 06:00:00'::timestamp without time zone))
    ->  Seq Scan on foo_1_1
            Filter: ((t >= '2018-01-01 03:00:00'::timestamp without time zone) AND (t <= '2018-01-01 06:00:00'::timestamp without time zone))
    ->  Seq Scan on foo_1_2
            Filter: ((t >= '2018-01-01 03:00:00'::timestamp without time zone) AND (t <= '2018-01-01 06:00:00'::timestamp without time zone))
(7 rows)
*/

explain (costs off) select * from foo where hash_mod(i, 2) = 1;
/*
                                      QUERY PLAN
---------------------------------------------------------------------------------------
 Append
    ->  Seq Scan on foo
            Filter: ((((hashint4(i) + '2147483648'::bigint) % '2'::bigint))::integer = 1)
    ->  Seq Scan on foo_1_2
            Filter: ((((hashint4(i) + '2147483648'::bigint) % '2'::bigint))::integer = 1)
    ->  Seq Scan on foo_2_2
            Filter: ((((hashint4(i) + '2147483648'::bigint) % '2'::bigint))::integer = 1)
(7 rows)
*/
