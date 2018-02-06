import random

dbname='postgres'

class CustomPruningPartedTblState:

    create_parted_tbl = 'create table foo(i int)'
    create_part_i = 'create table foo_{0} (check (i={0})) inherits (foo)'
    insert_part_i = 'insert into foo_{0} values ({0})'
    select = 'select * from select_foo(%d)'

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
        custom_pruning_sql = """
            create or replace function select_foo(_i int)
            returns setof foo
            language plpgsql
            as $$
            begin
                %s
            end;
            $$
        """ % (generate_pruning(1, num+1, 1),)
        self.node.execute(dbname, custom_pruning_sql)

    def random_select(self):
        return self.select % random.randrange(1, self.partnum+1)

def generate_pruning(start, end, indent):
    def generate_pruning_recursive(start, end, indent, result):
        if end < start:
            return
        if end-start <= 10:
            result[0] += '\t'*indent + 'case _i\n'
            for i in range(start, end):
                result[0] += '\t'*indent + 'when %d then return query select * from foo_%d where i=_i;\n' % (i, i)
            result[0] += '\t'*indent + 'end case;\n'
            return
        middle = (end+start) / 2
        result[0] += '\t'*indent + 'if _i >= %d and _i < %d then\n' % (start, middle)
        generate_pruning_recursive(start, middle, indent+1, result)
        result[0] += '\t'*indent + 'else\n'
        generate_pruning_recursive(middle, end, indent+1, result)
        result[0] += '\t'*indent + 'end if;\n'

    func_body = ['']
    generate_pruning_recursive(start, end, indent, func_body)
    return func_body[0]
