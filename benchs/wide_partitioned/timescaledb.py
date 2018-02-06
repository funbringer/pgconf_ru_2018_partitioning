import random

dbname='postgres'

class TimescalePartedTblState:

    #  create_part_i = ""
    insert_part_i = "insert into foo values (now() - interval '{0} hour')"
    select = "select * from foo where t > now() - interval '1 hour'"

    def __init__(self):
        self.created = False
        self.partnum = 0

    def set_node(self, node):
        self.node = node
        node.append_conf(
                'postgresql.conf',
                'max_locks_per_transaction=4096\n')
        node.append_conf(
                'postgresql.conf',
                'shared_preload_libraries=\'timescaledb\'\n')

    def create_tbl(self):
        with self.node.connect() as con:
            con.execute('create extension timescaledb')
            con.execute('create table foo(t timestamp)')
            con.execute("select create_hypertable('foo', 't', chunk_time_interval := interval '1 hour', create_default_indexes := false);")
            con.commit()
        self.created = True

    def create_parts(self, num):
        with self.node.connect() as con:
            for i in range(self.partnum, num):
                #  con.execute(self.create_part_i.format(i+1, i+2))
                con.execute(self.insert_part_i.format(i))
            con.commit()
        self.partnum = num

    def random_select(self):
        return self.select# % random.randrange(1, self.partnum+1)

