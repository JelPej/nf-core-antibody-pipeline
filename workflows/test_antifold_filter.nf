nextflow.enable.dsl=2

include { ANTIFOLD_CDR    } from '../modules/nf-core/antifold_cdr/main.nf'
include { FILTER_ANTIFOLD } from '../modules/nf-core/antifold_cdr_filter/main.nf'

workflow {

    // 1) Use a single PDB for testing
    Channel
        .fromPath('../modules/nf-core/antifold_cdr/tests/data/pdb/6y1l_imgt.pdb')
        .map { pdb -> tuple([ id: 'test_antifold' ], pdb) }
        | ANTIFOLD_CDR

    // 2) Join FASTA + CSV on meta
    def antifold_pairs = ANTIFOLD_CDR.out.fasta
        .join(ANTIFOLD_CDR.out.logits)
        .map { meta, fasta, meta2, csv ->
            assert meta == meta2
            tuple(meta, fasta, csv)
        }

    // 3) Filter by score
    antifold_pairs | FILTER_ANTIFOLD
}
