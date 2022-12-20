import os
import re
import sys
import yaml
import configparser
from pprint import pprint
from pathlib import Path, PurePath
from snakemake.utils import update_config, listfiles
from snakemake.exceptions import WorkflowError
from sunbeamlib import load_sample_list, read_seq_ids
from sunbeamlib.config import *
from sunbeamlib.reports import *
import collections


# Disallow slashes in our sample names during Snakemake's wildcard evaluation.
# Slashes should always be interpreted as directory separators.
wildcard_constraints:
  sample="[^/]+"

sunbeam_dir = ""
try:
    sunbeam_dir = os.environ["SUNBEAM_DIR"]
except KeyError:
    raise SystemExit(
        "$SUNBEAM_DIR environment variable not defined. Are you sure you're "
        "running this from the Sunbeam conda env?")

# Setting up config files and samples
Cfg = check_config(config)

print(Cfg['all']['download_reads'])
Samples = load_sample_list(Cfg['all']['samplelist_fp'], Cfg['all']['paired_end'], Cfg['all']['download_reads'], Cfg["all"]['root']/Cfg['all']['output_fp'])

Pairs = ['1', '2'] if Cfg['all']['paired_end'] else ['1']

# Collect host (contaminant) genomes
sys.stderr.write("Collecting host/contaminant genomes... ")
if Cfg['qc']['host_fp'] == Cfg['all']['root']:
    HostGenomeFiles = []
else:
    HostGenomeFiles = [f for f in Cfg['qc']['host_fp'].glob('*.fasta')] ## fna
    if not HostGenomeFiles:
        sys.stderr.write(
            "\n\nWARNING: No files detected in host genomes folder ({}). "
            "If this is not intentional, make sure all files end in "
            ".fasta and the folder is specified correctly.\n\n".format(
                Cfg['qc']['host_fp']
            ))
HostGenomes = {Path(g.name).stem: read_seq_ids(Cfg['qc']['host_fp'] / g) for g in HostGenomeFiles}
sys.stderr.write("done.\n")

sys.stderr.write("Collecting target genomes... ")
if Cfg['mapping']['genomes_fp'] == Cfg['all']['root']:
    GenomeFiles = []
    GenomeSegments = {}
else:
    GenomeFiles = [f for f in Cfg['mapping']['genomes_fp'].glob('*.fna')]
    GenomeSegments = {PurePath(g.name).stem: read_seq_ids(Cfg['mapping']['genomes_fp'] / g) for g in GenomeFiles}
sys.stderr.write("done.\n")

# ---- Change your workdir to output_fp
workdir: str(Cfg['all']['output_fp'])

# ---- Set up output paths for the various steps
QC_FP = output_subdir(Cfg, 'qc')
MAPPING_FP = output_subdir(Cfg, 'mapping')

# ---- Targets rules
include: "rules/targets/targets.rules"

# ---- Quality control rules
include: "rules/qc/qc.rules"
include: "rules/qc/decontaminate.rules"

# ---- Reports rules
include: "rules/reports/reports.rules"


# ---- Rule all: run all targets
rule all:
    input: TARGET_ALL

rule samples:
    message: "Samples to be processed:"
    run:
        [print(sample) for sample in sorted(list(Samples.keys()))]
