import os
import subprocess
from collections import OrderedDict

from filter_reads_f import count_host_reads, calculate_counts, write_log

hostdict = OrderedDict()
net_hostlist = set()
for hostid in snakemake.input.hostids:
    count_host_reads(hostid, hostdict, net_hostlist)

host, nonhost = calculate_counts(snakemake.input.reads, net_hostlist)

os.system("""
gzip -dc {a} | \
rbt fastq-filter {b} | \
gzip > {c}
""".format(a=snakemake.input.reads, b=snakemake.input.hostreads, c=snakemake.output.reads))

with open(snakemake.output.log, 'w') as log:
    write_log(log, hostdict, host, nonhost)

