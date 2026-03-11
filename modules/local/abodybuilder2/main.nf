process ABODYBUILDER2 {
    tag "$meta.id"
    label 'process_medium'

    container 'abodybuilder2:latest'

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("${prefix}.pdb"),  emit: pdb
    tuple val(meta), path("*.failed.txt"),   emit: failed, optional: true
    path  "versions.yml",                    emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix   = task.ext.prefix ?: "${meta.id}"
    """
    if ABodyBuilder2 \\
            -f ${fasta} \\
            -o ${prefix}.pdb \\
            ${args}; then
        : # prediction succeeded
    else
        echo "ABodyBuilder2 failed for ${prefix}" > ${prefix}.failed.txt
        touch ${prefix}.pdb
    fi

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
