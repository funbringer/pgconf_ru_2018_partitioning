create extension timescaledb;

-- For monitoring loading of device
create table monitoring_data(time timestamp not null, device_id int, loading numeric);

-- Partition by range on 'time' (each interval is 1 month as default)
-- and by hash on device_id (4 buckets are created)
select create_hypertable('monitoring_data', 'time', 'device_id', 4);

insert into monitoring_data
    select 
        timestamp '2018-01-01' + random()*(now() - timestamp '2018-01-01'),
        (15*random())::int, (100*random())::numeric
    from generate_series(1, 100000) i;

-- Request average loads over last 15-minutes intervals inside 3 hours for each device
select
    device_id,
    time_bucket('15 minutes', time) as fifteen_min,
    avg(loading)
from monitoring_data
where
    time > now() - interval '3 hours'
group by fifteen_min, device_id
order by fifteen_min, device_id;

-- Build histogram on 5 buckets from 0 to 100% for loading metric over last week
select
    device_id, count(*), histogram(loading, 0, 100, 5)
from monitoring_data
where time > now() - interval '1 week'
group by device_id
order by device_id;
