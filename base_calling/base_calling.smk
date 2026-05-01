configfile: "config.yaml"

RUN_ID = config["input_dir"].rstrip("/").split("/")[-1]
EXPECTED_OUT = config["base_output_dir"] + "/" + RUN_ID

rule all:
    input:
        directory(EXPECTED_OUT)

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
