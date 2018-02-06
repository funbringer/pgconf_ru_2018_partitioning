import random

dbname='postgres'

class Pg10PartedTblState:

    create_parted_tbl = 'create table foo(i int) partition by list(i)'
    create_part_i = 'create table foo_{0} partition of foo for values in ({0})'
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
