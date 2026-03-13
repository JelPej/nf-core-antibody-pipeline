process BIOPHI_SAPIENS {
    tag "$meta.id"
    label 'process_low'

    container 'community.wave.seqera.io/library/biophi:1.0.11--591744abb77f706b'

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*_humanized.fasta"), emit: humanized
    tuple val(meta), path("*_scores.csv"),      emit: sapiens_scores
    path "versions.yml",                        emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    biophi sapiens \\
        ${fasta} \\
        --fasta-only \\
        --output ${prefix}_humanized.fasta \\
        ${args}

    biophi sapiens \\
        ${fasta} \\
        --mean-score-only \\
        --output ${prefix}_scores.csv \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        biophi: \$(biophi --version 2>&1 | grep -oP '(?<=BioPhi )\\S+')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_humanized.fasta
    touch ${prefix}_scores.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        biophi: stub
    END_VERSIONS
    """
}
