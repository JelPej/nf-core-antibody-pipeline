nextflow.enable.dsl=2

process FILTER_ANTIFOLD {

    tag "$meta.id"
    label 'process_single'

    container 'docker.io/python:3.11'

    input:
    tuple val(meta), path(redesigned_fasta), path(scores_csv)
    path filter_script

    output:
    tuple val(meta), path("*_filtered.fasta"), emit: filtered
    path "versions.yml",                       emit: versions

    script:
    def args      = task.ext.args   ?: ''
    def prefix    = task.ext.prefix ?: "${meta.id}"
    def min_score = params.antifold_min_score
    if( min_score == null )
        throw new IllegalArgumentException("params.antifold_min_score must be set for FILTER_ANTIFOLD")

    """
    set -euo pipefail

    python ${filter_script} \\
        --fasta ${redesigned_fasta} \\
        --csv ${scores_csv} \\
        --out_fasta ${prefix}_filtered.fasta \\
        --min_score ${min_score} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version 2>&1 | sed 's/Python //')
    END_VERSIONS
    """
}

