nextflow.enable.dsl=2

process ANTIFOLD_CDR
{
    tag "${meta.id}"
    label 'process_medium'

    container 'quay.io/avitanov/antifold:0.3.1'

    // stageAs: "dir/" is required: antifold uses os.path.dirname(pdb_file) to resolve pdb_dir.
    // Without a parent directory, dirname returns "" which produces an invalid absolute path "/name.pdb".
    input:
    tuple val(meta), path(pdb, stageAs: "dir/")

    output:
    tuple val(meta), path("*.fasta", optional: true), emit: fasta
    tuple val(meta), path("*.csv"),   emit: logits
    path "versions.yml",                       emit: versions

    script:
    def numSeq  = task.ext.num_seq_per_target ?: 5
    def regions = task.ext.regions            ?: "CDR1 CDR2 CDR3"
    def temp    = task.ext.sampling_temp      ?: "0.2"
    def heavy   = meta.chain_heavy            ?: "H"
    def light   = meta.chain_light            ?: "L"
    def pdbStem = pdb.baseName

    // # AntiFold names outputs as {pdb_stem}_{chains}.{ext} — rename to meta.id
    """
    set -euo pipefail

    python3 -m antifold.main \\
        --pdb_file ${pdb} \\
        --out_dir . \\
        --heavy_chain ${heavy} \\
        --light_chain ${light} \\
        --num_seq_per_target ${numSeq} \\
        --sampling_temp "${temp}" \\
        --regions "${regions}"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        antifold: \$(python3 -c "import antifold; print(antifold.__version__)")
    END_VERSIONS
    """
}

workflow {
    Channel
        .fromPath('/data/pdb/6y1l_imgt.pdb')          // adjust to your test PDB path
        .map { pdb -> tuple([ id: 'test_antifold' ], pdb) }
        | ANTIFOLD_CDR
}
