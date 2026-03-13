process FILTER_BIOPHI {
    tag "$meta.id"
    label 'process_single'

    container 'docker.io/python:3.11'

    input:
    tuple val(meta), path(humanized_fasta), path(sapiens_scores_csv)

    output:
    tuple val(meta), path("*_filtered.fasta"), emit: filtered
    path "versions.yml",                       emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args      = task.ext.args   ?: ''
    def prefix    = task.ext.prefix ?: "${meta.id}"
    def min_score = params.sapiens_min_score ?: 0.8
    """
    filter_by_sapiens_score.py \\
        ${humanized_fasta} \\
        ${sapiens_scores_csv} \\
        ${prefix}_filtered.fasta \\
        --min-score ${min_score} \\
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
