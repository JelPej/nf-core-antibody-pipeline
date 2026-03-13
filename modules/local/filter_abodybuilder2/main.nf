process FILTER_ABODYBUILDER2 {
    tag "$meta.id"
    label 'process_low'

    container 'docker.io/python:3.10'

    input:
    tuple val(meta), path(fasta_file), path(predicted_pdb)

    output:
    tuple val(meta), path("filtered_${fasta_file}"),     emit: filtered, optional: true
    tuple val(meta), path("error_${fasta_file}.txt"),    emit: error,    optional: true
    path "versions.yml",                                  emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    pdb_filter.py \\
        --pdb ${predicted_pdb} \\
        --fasta ${fasta_file} \\
        --success_path filtered_${fasta_file} \\
        --failure_path error_${fasta_file}.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //')
    END_VERSIONS
    """

    stub:
    """
    cp ${fasta_file} filtered_${fasta_file}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: stub
    END_VERSIONS
    """
}
