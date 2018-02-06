import testgres
import tempfile
import subprocess
import os
import re

from inh import *
from pathman import *
from pg10 import *
from invalidating_pathman import *
from plpgsql_pruning import *
from timescaledb import *

dbname='postgres'

BENCH_DURATION = 100
#  part_nums = [10] + range(100, 1001, 100)
PART_NUMS = [100, 250, 500, 10**3, 2 * 10**3, 4 * 10**3, 8 * 10**3, 16 * 10**3]

with testgres.get_new_node('master') as master:
    pstate = TimescalePartedTblState()

    # start a new node
    master.init()
    pstate.set_node(master)
    master.start()
    pstate.create_tbl()

    #  pstate.create_parts(10)
    #  print master.execute(dbname, pstate.random_select())
    #  print master.execute(dbname, 'select tableoid::regclass, * from foo')
    #  import sys; sys.exit(0)

    temp = tempfile.NamedTemporaryFile()
    FNULL = open(os.devnull, 'w')
    for nparts in PART_NUMS:
        pstate.create_parts(nparts)

        temp.seek(0)
        sql = pstate.random_select()
        temp.write(sql)
        temp.truncate()
        temp.flush()

        p = master.pgbench(dbname, stdout=subprocess.PIPE, stderr=FNULL,
                options=[
                    '-f', temp.name,
                    '-T', str(BENCH_DURATION)
        ])

        latency_re = re.compile(r'^latency average = ([\d\.]+) (\w+)$')
        tps_re = re.compile(r'^tps = ([\d\.]+) \(excluding connections establishing\)$')
        latency, tps = None, None
        for line in p.stdout.readlines():
            m = latency_re.search(line)
            if m:
                latency = (float(m.group(1)), m.group(2))
            m = tps_re.search(line)
            if m:
                tps = float(m.group(1))
        print nparts, '%f%s' % (latency[0], latency[1]), tps

        p.communicate()

    #  import ipdb; ipdb.set_trace()
    temp.close()

    master.stop()
