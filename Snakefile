import csv

configfile: "config.yaml"

REF = config["ref"]
CRAM_BASE = config["cram_base"]
BAM_BASE = config["bam_base"]
MANIFEST = config["manifest"]
MODKIT = config["modkit"]
PILEUP_BASE = config["pileup_base"]

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

SAMPLES = parse_manifest(MANIFEST)

rule all:
    input:
        expand(PILEUP_BASE + "/{sample}_6mA_pileup.bed.gz", sample=SAMPLES.keys())

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
