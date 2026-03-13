process OASIS {
    tag "$meta.id"
    label 'process_low'

    container 'howlinman/biophi-oasis:1.0.0'

    input:
    tuple val(meta), path(humanized_fasta)
    path oasis_db

    output:
    tuple val(meta), path("*_oasis_scores.xlsx"), emit: scores
    path "versions.yml",                          emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    biophi oasis \\
        ${humanized_fasta} \\
        --oasis-db ${oasis_db} \\
        --output ${prefix}_oasis_scores.xlsx \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        biophi: \$( biophi --version 2>&1 | head -1 )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_oasis_scores.xlsx

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        biophi: \$( biophi --version 2>&1 | head -1 )
    END_VERSIONS
    """
}
