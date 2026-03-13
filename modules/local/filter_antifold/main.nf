process FILTER_ANTIFOLD {

    tag "$meta.id"
    label 'process_single'

    container 'docker.io/python:3.11'

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*_filtered.fasta"), emit: filtered
    path "versions.yml",                       emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args      = task.ext.args   ?: ''
    def prefix    = task.ext.prefix ?: "${meta.id}"
    def min_score = params.antifold_min_score
    if ( min_score == null )
        throw new IllegalArgumentException("params.antifold_min_score must be set for FILTER_ANTIFOLD")
    """
    filter_antifold.py \\
        --fasta ${fasta} \\
        --out_fasta ${prefix}_filtered.fasta \\
        --min_score ${min_score} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version 2>&1 | sed 's/Python //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_filtered.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version 2>&1 | sed 's/Python //')
    END_VERSIONS
    """
}
