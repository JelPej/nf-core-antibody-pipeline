process ABODYBUILDER2 {
    tag "$meta.id"
    label 'process_medium'

    container 'amihajlovski/abodybuilder2:latest'

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("${prefix}.pdb"),  emit: pdb
<<<<<<< HEAD
=======
    tuple val(meta), path("*.failed.txt"),   emit: failed, optional: true
<<<<<<< HEAD
>>>>>>> 9ba9fc8 (Add ABodyBuilder2 module)
=======
>>>>>>> 2408d5c (Add ABodyBuilder2 module)
>>>>>>> 7144b93 (Add ABodyBuilder2 module)
    path  "versions.yml",                    emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix   = task.ext.prefix ?: "${meta.id}"
    """
    ABodyBuilder2 \\
            -f ${fasta} \\
            -o ${prefix}.pdb \\
            ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ImmuneBuilder: \$(python -c "import ImmuneBuilder; print(ImmuneBuilder.__version__)")
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.pdb

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ImmuneBuilder: 1.0.0
    END_VERSIONS
    """
}

