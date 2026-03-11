#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

include { ABODYBUILDER2 } from '../modules/local/abodybuilder2/main'

workflow {
    def meta = [ id: 'test_ab', sample: 'test_ab', chain_heavy: 'H', chain_light: 'L' ]

    Channel
        .of( [ meta, file("${projectDir}/assets/test_antibody.fasta") ] )
        | ABODYBUILDER2

    ABODYBUILDER2.out.pdb.view      { m, pdb -> "PDB:      $pdb" }
    ABODYBUILDER2.out.versions.view { v     -> "Versions: $v" }
}
