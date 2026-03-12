nextflow.enable.dsl=2

process ANTIFOLD_CDR {
    tag "${meta.id}"
    label 'process_medium'
    container 'https://wave.seqera.io/view/builds/bd-2d39fa84a931b114_2?_gl=1*dovd6r*_gcl_au*OTY3NDI4Njg3LjE3Njg4Mjg4NDQ'

    input:
    tuple val(meta), path(pdb)

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

    export PYTHONPATH=/usr/local/lib/python3.10/site-packages:${PYTHONPATH:-}

    python -m antifold.main --pdb_file ${pdb} --out_dir .

    """
}

workflow {
    Channel
        .fromPath('data/6y1l_imgt.pdb')          // adjust to your test PDB path
        .map { pdb -> tuple([ id: 'test_antifold' ], pdb) }
        | ANTIFOLD_CDR
}
