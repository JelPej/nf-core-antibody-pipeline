nextflow.enable.dsl=2

process FILTER_ANTIFOLD {

    tag "${meta.id}"
    label 'process_low'
    container 'python:3.10-slim'

    // Input from ANTIFOLD_CDR: meta, redesigned_fasta, scores_csv
    input:
    tuple val(meta), path(redesigned_fasta, stageAs: "dir/"), path(scores_csv, stageAs: "dir/")

    // Output: filtered FASTA only
    output:
    tuple val(meta), path("${meta.id}.filtered.fasta"), emit: fasta
    path "versions.yml", emit: versions

    script:
    // User MUST provide a threshold
    def minScore = task.ext.min_score ?: params.antifold_min_score
    if( minScore == null )
        throw new IllegalArgumentException("params.antifold_min_score must be set for FILTER_ANTIFOLD")

    """
    set -euo pipefail

    python /workspace/modules/nf-core/antifold_cdr_filter/filter_antifold.py \
    --fasta ${redesigned_fasta} \
    --csv ${scores_csv} \
    --out_fasta ${meta.id}.filtered.fasta \
    --min_score ${minScore}


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        filter_antifold: 0.1.0
    END_VERSIONS
    """
}
