nextflow.enable.dsl=2

include { ANTIFOLD_CDR    } from '../modules/nf-core/antifold_cdr/main.nf'
include { FILTER_ANTIFOLD } from '../modules/local/antifold_cdr_filter/main.nf'

workflow {

    Channel
        .fromPath('modules/nf-core/antifold_cdr/tests/data/pdb/6y1l_imgt.pdb')
        .map { pdb -> tuple([ id: 'test_antifold' ], pdb) }
        | ANTIFOLD_CDR

    ANTIFOLD_CDR.out.fasta.view    { "FASTA  -> $it" }
    ANTIFOLD_CDR.out.logits.view   { "LOGITS -> $it" }
    ANTIFOLD_CDR.out.versions.view { "VERS   -> $it" }

    // Channel of (meta, fasta, csv)
    tuples_ch = ANTIFOLD_CDR.out.fasta
        .join(ANTIFOLD_CDR.out.logits)
        .map { meta, fasta, meta2, csv ->
            assert meta == meta2
            tuple(meta, fasta, csv)
        }

    // Single-value channel with the script
    script_ch = Channel.of( file('bin/filter_antifold.py') )

    // Call process with two separate input channels
    FILTER_ANTIFOLD( tuples_ch, script_ch )
}
