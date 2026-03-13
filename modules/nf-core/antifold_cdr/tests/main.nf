nextflow.enable.dsl=2

include { ANTIFOLD_CDR } from '../main.nf'

workflow {
    Channel
        .fromPath('data/pdb/6y1l_imgt.pdb')
        .map { pdb ->
            def meta = [ id: 'test_antifold' ]
            tuple(meta, pdb)
        }
        | ANTIFOLD_CDR

    ANTIFOLD_CDR.out.fasta.view { it }
    ANTIFOLD_CDR.out.logits.view { it }
}
