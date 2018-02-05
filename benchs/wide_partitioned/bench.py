import testgres
import random
import tempfile
import subprocess
import os
import re

dbname='postgres'

class PartedTblState:

    create_parted_tbl = 'create table foo(i int)'
    create_part_i = 'create table foo_{0} (check (i={0})) inherits (foo)'
    insert_part_i = 'insert into foo_{0} values ({0})'
    select = 'select * from foo where i=%d'

    def __init__(self, node):
        self.created = False
        self.partnum = 0

    def set_node(self, node):
        self.node = node

    def create_tbl(self):
        self.node.execute(dbname, self.create_parted_tbl)
        self.created = True

    def create_parts(self, num):
        with self.node.connect() as con:
            for i in range(self.partnum, num):
                con.execute(self.create_part_i.format(i+1))
                con.execute(self.insert_part_i.format(i+1))
            con.commit()
        self.partnum = num

    def random_select(self):
        return self.select % random.randrange(1, self.partnum+1)


BENCH_DURATION = 100
#  part_nums = [10] + range(100, 1001, 100)
PART_NUMS = [100, 250, 500, 10**3, 2 * 10**3, 4 * 10**3, 8 * 10**3, 16 * 10**3]

with testgres.get_new_node('master') as master:
    pstate = PartedTblState(master)

    # start a new node
    master.init()
    pstate.set_node(master)
    master.start()
    pstate.create_tbl()

    temp = tempfile.NamedTemporaryFile()
    FNULL = open(os.devnull, 'w')
    for nparts in PART_NUMS:
        pstate.create_parts(nparts)

        temp.seek(0)
        temp.write(pstate.random_select())
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
