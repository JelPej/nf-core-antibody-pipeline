process FILTER_ABODYBUILDER2 {
    tag "$meta.id"
    label 'process_low'

    container "python:3.10-slim"

    input:
    tuple val(meta), path(fasta_file), path(predicted_pdb)

    output:
    tuple val(meta), path("filtered_${fasta_file}"), emit: success, optional: true
    tuple val(meta), path("error_${fasta_file}.txt"), emit: error, optional: true

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    pdb_filter.py --pdb ${predicted_pdb} \\
                  --fasta ${fasta_file} \\
                  --success_path filtered_${fasta_file} \\
                  --failure_path error_${fasta_file}.txt
    """

    stub:
    """
    cp fasta_file filtered_${fasta_file}
    """
}
