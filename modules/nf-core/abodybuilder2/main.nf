process ABODYBUILDER2 {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/6e/6e96687bc5b90044499fd3d741dca4c768156aa758ae2312ae270b3183a73bcc/data'
        : 'community.wave.seqera.io/library/anarci_openmm_pdbfixer_pip_immunebuilder:fcc3171a3a0b48f8'} "

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*.pdb"), emit: pdb
    path  "versions.yml", emit: versions

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
