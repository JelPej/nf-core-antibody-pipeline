process ANTIFOLD_CDR{
    tag "${meta.id}"
    cpus 6
    memory 12.GB
    //label 'process_medium'

    container 'quay.io/avitanov/antifold:0.3.1-build2'
    // stageAs: "dir/" is required: antifold uses os.path.dirname(pdb_file) to resolve pdb_dir.
    // Without a parent directory, dirname returns "" which produces an invalid absolute path "/name.pdb".
    input:
    tuple val(meta), path(pdb, stageAs: "dir/")

    output:
    tuple val(meta), path("*.fasta"), optional: true,  emit: fasta
    tuple val(meta), path("*.csv"),   emit: logits
    path "versions.yml",                       emit: versions

    script:
    // Chains come from meta (populated by samplesheet)
    def heavy = meta.chain_heavy ?: "H"
    def light = meta.chain_light ?: "L"

    // All other args only added when explicitly set via task.ext (antifold defaults apply otherwise)
    def args = [
        task.ext.num_seq_per_target != null ? "--num_seq_per_target ${task.ext.num_seq_per_target}" : "",
        task.ext.sampling_temp      != null ? "--sampling_temp \"${task.ext.sampling_temp}\""       : "",
        task.ext.regions            != null ? "--regions \"${task.ext.regions}\""                   : "",
        task.ext.antigen_chain      != null ? "--antigen_chain ${task.ext.antigen_chain}"           : "",
        task.ext.nanobody_chain     != null ? "--nanobody_chain ${task.ext.nanobody_chain}"         : "",
        task.ext.batch_size         != null ? "--batch_size ${task.ext.batch_size}"                 : "",
        task.ext.num_threads        != null ? "--num_threads ${task.ext.num_threads}"               : "",
        task.ext.seed               != null ? "--seed ${task.ext.seed}"                             : "",
        task.ext.verbose            != null ? "--verbose ${task.ext.verbose}"                       : "",
        task.ext.model_path         != null ? "--model_path ${task.ext.model_path}"                 : "",
        task.ext.limit_variation    ? "--limit_variation"    : "",
        task.ext.extract_embeddings ? "--extract_embeddings" : "",
        task.ext.custom_chain_mode  ? "--custom_chain_mode"  : "",
        task.ext.exclude_heavy      ? "--exclude_heavy"      : "",
        task.ext.exclude_light      ? "--exclude_light"      : "",
        task.ext.esm_if1_mode       ? "--esm_if1_mode"       : "",
    ].findAll { it }.join(" \\\n        ")

    """
    python3 -m antifold.main \\
        --pdb_file ${pdb} \\
        --out_dir . \\
        --heavy_chain ${heavy} \\
        --light_chain ${light} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        antifold: \$(python3 -c "from importlib.metadata import version; print(version('antifold'))")
    END_VERSIONS
    """
}
