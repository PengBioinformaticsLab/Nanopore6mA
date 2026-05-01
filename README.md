# 6mA Methylation Pileup Pipeline

This Snakemake pipeline automates the extraction of 6mA methylation signals from long-read sequencing data. It processes samples from CRAM format through to compressed bedGraph pileups, specifically optimized for high-performance computing (HPC) environments.

## Workflow Overview

1.  **CRAM to BAM Conversion**: Reverts input CRAM files to BAM format using `samtools`, applying a MAPQ filter of 20 to ensure high-quality alignments.
2.  **BAM Indexing**: Generates `.bai` index files to enable efficient downstream processing.
3.  **6mA Pileup Generation**: Utilizes `modkit pileup` to call 6mA methylation at the **A 0** motif, outputting compressed BED files (`.bed.gz`).

## Pipeline Configuration

The workflow is configured via `config.yaml` with the following relative paths:

- **Reference Genome**: `/path_to_reference.fna`
- **Input CRAM Directory**: `/input/directory/download`
- **Output BAM Directory**: `/output/bams`
- **Final Pileup Directory**: `/path/to/MODKIT_PILEUP_6mA`
- **Manifest File**: `/path/to/manifest.csv`
- **Modkit Executable**: `/path/to/modkit/v0.5.1`

## Requirements

The pipeline requires the following software to be available (typically via `module load` on HPC systems):

- **Snakemake**
- **Samtools**
- **HTSlib** (for `bgzip`)
- **Modkit**

## Usage

To run the pipeline locally or on a head node:

```bash
snakemake \
  --executor slurm \
  --jobs 10 \
  --default-resources \
      slurm_account=r***** \
      slurm_partition=general \
  --latency-wait 60 \
  --rerun-incomplete \
  --printshellcmds
