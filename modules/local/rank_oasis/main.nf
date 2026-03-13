process RANK_OASIS {
    tag "$meta.id"
    label 'process_low'

    container 'docker.io/howlinman/biophi-oasis:1.0.0'

    input:
    tuple val(meta), path(oasis_scores_xlsx)

    output:
    tuple val(meta), path("*_ranked.csv"), emit: ranked
    path "versions.yml",                   emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix      = task.ext.prefix ?: "${meta.id}"
    def min_pct     = params.oasis_min_percentile ?: 10
    """
    rank_oasis.py \\
        ${oasis_scores_xlsx} \\
        ${prefix}_ranked.csv \\
        ${min_pct}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //')
        pandas: \$(python3 -c "import pandas; print(pandas.__version__)")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_ranked.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: stub
        pandas: stub
    END_VERSIONS
    """
}
