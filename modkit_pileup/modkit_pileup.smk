import csv

configfile: "config.yaml"

# Global variables extracted from config for easier access throughout the workflow
REF = config["ref"]
CRAM_BASE = config["cram_base"]
BAM_BASE = config["bam_base"]
MANIFEST = config["manifest"]
MODKIT = config["modkit"]
PILEUP_BASE = config["pileup_base"]

# Function to read the manifest
# Manifest is written in the format of: SampleName,PathToCramFile,NameOfOutputBAMFile as a .csv
def parse_manifest(manifest_path):
    samples = {}
    with open(manifest_path) as f:
        reader = csv.reader(f)
        for row in reader:
            if len(row) < 3:
                continue
            sample, cram_sub, bam_file = row[0], row[1], row[2]
            if not sample.strip():
                continue
            samples[sample] = {
                "cram_sub": cram_sub,
            }
    return samples

# Parse the manifest into a dictionary for Snakemake to use
SAMPLES = parse_manifest(MANIFEST)

# Target rule: Defines the final expected output files for the entire pipeline
# This ensures that a 6mA pileup bed file is generated for every sample found in the manifest
rule all:
    input:
        expand(PILEUP_BASE + "/{sample}_6mA_pileup.bed.gz", sample=SAMPLES.keys())

# Rule to convert CRAM files back to BAM format
# Filters by mapping quality (MAPQ) and requires the original reference genome for decompression
rule cram_to_bam:
    input:
        cram=lambda wc: CRAM_BASE + "/" + SAMPLES[wc.sample]["cram_sub"],
        ref=REF,
    output:
        bam=BAM_BASE + "/{sample}_revert.bam",
    params:
        mapq=20,
    threads: 4
    resources:
        mem_mb=64000,
        runtime=2880,
    log:
        "logs/{sample}_cram_to_bam.log",
    shell:
        """
        module load samtools
	mkdir -p $(dirname {output.bam})
        samtools view \
            -h -b \
            -q {params.mapq} \
            -@ {threads} \
            -T {input.ref} \
            -o {output.bam} \
            {input.cram} \
        2>&1 | tee {log}
        """

# Rule to generate a BAM index (.bai)
# Required for downstream tools like modkit to perform random access on the alignment data
rule index_bam:
    input:
        bam=BAM_BASE + "/{sample}_revert.bam",
    output:
        bai=BAM_BASE + "/{sample}_revert.bam.bai",
    threads: 4
    resources:
        mem_mb=8000,
        runtime=600,
    log:
        "logs/{sample}_index.log",
    shell:
        """
	module load samtools
        samtools index -@ {threads} {input.bam} 2>&1 | tee {log}
        """

# Rule to run modkit pileup
# The A 0 motif is designated to focus on 6mA methylation
# Output is piped through bgzip to produce a compressed, indexed-ready BED file
rule modkit_pileup_6mA:
    input:
        bam=BAM_BASE + "/{sample}_revert.bam",
        bai=BAM_BASE + "/{sample}_revert.bam.bai",
        ref=REF,
    output:
        bed=PILEUP_BASE + "/{sample}_6mA_pileup.bed.gz",
    threads: 4
    resources:
        mem_mb=32000,
        runtime=2880,
    log:
        "logs/{sample}_modkit_pileup.log",
    shell:
        """
	module load samtools htslib
        mkdir -p $(dirname {output.bed})
        {modkit} pileup \
            {input.bam} \
            - \
            --motif A 0 \
            --ref {input.ref} \
            --threads {threads} \
            --log-filepath {log} \
            | bgzip -c > {output.bed}
        """.replace("{modkit}", MODKIT)
