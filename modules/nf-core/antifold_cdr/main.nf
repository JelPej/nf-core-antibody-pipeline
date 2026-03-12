nextflow.enable.dsl=2

process ANTIFOLD_CDR 
{
    tag "${meta.id}"
    label 'process_medium'
    // container 'quay.io/avitanov/antifold:0.3.1'

    input:
    tuple val(meta), path(pdb, stageAs: 'dir/')

    output:
    tuple val(meta), path("${meta.id}.fasta"), emit: fasta
    tuple val(meta), path("${meta.id}.csv"),   emit: logits
    path "versions.yml",                       emit: versions

    script:
    def numSeq  = task.ext.num_seq_per_target ?: 50
    def regions = task.ext.regions            ?: "CDR1 CDR2 CDR3"
    def temp    = task.ext.sampling_temp      ?: "0.2"
    def heavy   = task.ext.heavy_chain        ?: "H"
    def light   = task.ext.light_chain        ?: "L"

    """
    set -euo pipefail

    python -m antifold.main --pdb_file ${pdb} --out_dir .

    """
}

workflow {
    Channel
        .fromPath('/data/pdb/6y1l_imgt.pdb')
        .map { pdb -> tuple([ id: 'test_antifold' ], pdb) }
        | ANTIFOLD_CDR
}
