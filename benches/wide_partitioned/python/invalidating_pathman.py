import random

dbname='postgres'

class InvalidatingPathmanPartedTblState:

    create_part_i = "select add_range_partition('foo', {0}, {1}, 'foo_{0}')"
    insert_part_i = 'insert into foo_{0} values ({0})'
    select = 'select * from foo where i=%d'

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
                'shared_preload_libraries=\'pg_pathman\'\n')

    def create_tbl(self):
        with self.node.connect() as con:
            con.execute('create extension pg_pathman')
            con.execute('create table foo(i int not null)')
            con.execute("select create_range_partitions('foo', 'i', 1, 1, 0)")
            con.commit()
        self.created = True

    def create_parts(self, num):
        with self.node.connect() as con:
            for i in range(self.partnum, num):
                con.execute(self.create_part_i.format(i+1, i+2))
                con.execute(self.insert_part_i.format(i+1))
            con.commit()
        self.partnum = num

    def random_select(self):
        self.node.execute(dbname, "select append_range_partition('foo', 'test')")
        self.node.execute(dbname, "select drop_range_partition('test')")
        return self.select % random.randrange(1, self.partnum+1)

