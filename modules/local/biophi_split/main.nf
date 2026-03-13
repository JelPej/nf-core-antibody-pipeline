process BIOPHI_SPLIT {
    tag "$meta.id"
    label 'process_single'

    container 'quay.io/avitanov/antifold:0.3.1-build2'

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*_candidate_*.fasta"), emit: fastas
    path "versions.yml",                          emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    clean_fasta.py ${fasta} ${prefix}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_candidate_0001.fasta
    touch ${prefix}_candidate_0002.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: stub
    END_VERSIONS
    """
}
