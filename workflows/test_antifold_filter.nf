nextflow.enable.dsl=2

include { ANTIFOLD_CDR    } from '../modules/local/antifold_cdr/main'
include { ANTIFOLD_SPLIT  } from '../modules/local/antifold_split/main'
include { FILTER_ANTIFOLD } from '../modules/local/filter_antifold/main'

workflow {

    Channel
        .fromPath('modules/local/antifold_cdr/tests/data/pdb/6y1l_imgt.pdb')
        .map { pdb ->
            tuple([ id: 'test_antifold', sample: 'test_antifold', chain_heavy: 'H', chain_light: 'L' ], pdb)
        }
        | ANTIFOLD_CDR

    ANTIFOLD_SPLIT(ANTIFOLD_CDR.out.fasta)

    FILTER_ANTIFOLD(ANTIFOLD_SPLIT.out.fasta)

    FILTER_ANTIFOLD.out.filtered.view { "FILTERED -> $it" }
    FILTER_ANTIFOLD.out.versions.view { "VERS     -> $it" }
}
