# Load external configuration from a YAML file
configfile: "config.yaml"

# Extract the folder name from the input path to use as Run ID
RUN_ID = config["input_dir"].rstrip("/").split("/")[-1]

# Define the target directory by joining the base output path and the Run ID
EXPECTED_OUT = config["base_output_dir"] + "/" + RUN_ID

# Target rule: defines the final expected output files for the entire pipeline
rule all:
    input:
        directory(EXPECTED_OUT)

# Rule to demultiplex and base call pod5 files into BAM files
# Requires an external sample sheet to assign sample IDs to barcodes
# Modifications must be defined here (ie. 6mA, 5mC) otherwise the information will be lost for downstream analysis
rule dorado_pipeline:
    input:
        pod5 = config["input_dir"],
        sheet = config["sample_sheet"]
    output:
        run_dir = directory(EXPECTED_OUT)
    params:
        dorado = config["dorado"],
        model = config["model"],
        kit = config["kit"],
        mods = config["mods"]
    shell:
        """
        RUN_ID=$(basename "{input.pod5}")
        RUN_DIR="{output.run_dir}"
        TMP_BAM="$RUN_DIR/${{RUN_ID}}_calls.bam"

        mkdir -p "$RUN_DIR"

        {params.dorado} basecaller "{params.model}" "{input.pod5}" \
            --kit-name {params.kit} \
            --modified-bases {params.mods} \
            > "$TMP_BAM"

        {params.dorado} demux \
            --no-classify \
            --sample-sheet "{input.sheet}" \
            --output-dir "$RUN_DIR" \
            "$TMP_BAM"

        echo "Processing complete for $RUN_ID. Results are in $RUN_DIR"
        """
