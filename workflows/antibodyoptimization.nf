/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_antibodyoptimization_pipeline'
include { samplesheetToList      } from 'plugin/nf-schema'
include { ANTIFOLD_CDR           } from '../modules/local/antifold_cdr/main'
include { ANTIFOLD_SPLIT         } from '../modules/local/antifold_split/main'
include { BIOPHI_SAPIENS         } from '../modules/local/biophi/main'
include { FILTER_BIOPHI          } from '../modules/local/filter_biophi/main'
include { BIOPHI_SPLIT           } from '../modules/local/biophi_split/main'
include { ABODYBUILDER2          } from '../modules/local/abodybuilder2/main'
include { FILTER_ABODYBUILDER2   } from '../modules/local/filter_abodybuilder2/main'
include { OASIS                  } from '../modules/local/oasis/main'
include { RANK_OASIS             } from '../modules/local/rank_oasis/main'


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow ANTIBODYOPTIMIZATION {

    main:

    ch_versions = channel.empty()

    channel
        .fromList(samplesheetToList(params.input, "${projectDir}/assets/schema_input.json"))
        .set { ch_pdbs }

    //
    // STEP 1: AntiFold CDR redesign
    //
    ANTIFOLD_CDR(ch_pdbs)
    ch_versions = ch_versions.mix(ANTIFOLD_CDR.out.versions)

    //
    // STEP 2: Split joined VH/VL FASTA into separate chain records
    //
    ANTIFOLD_SPLIT(ANTIFOLD_CDR.out.fasta)
    ch_versions = ch_versions.mix(ANTIFOLD_SPLIT.out.versions)

    //
    // STEP 3: BioPhi Sapiens humanization
    //
    BIOPHI_SAPIENS(ANTIFOLD_SPLIT.out.fasta)
    ch_versions = ch_versions.mix(BIOPHI_SAPIENS.out.versions)

    //
    // STEP 4: Filter by Sapiens humanness score
    //
    ch_biophi_for_filter = BIOPHI_SAPIENS.out.humanized
        .join(BIOPHI_SAPIENS.out.sapiens_scores, by: 0)

    FILTER_BIOPHI(ch_biophi_for_filter)
    ch_versions = ch_versions.mix(FILTER_BIOPHI.out.versions)

    //
    // STEP 5: Clean filtered FASTA and split into per-candidate FASTAs for ABodyBuilder2
    //
    BIOPHI_SPLIT(FILTER_BIOPHI.out.filtered)
    ch_versions = ch_versions.mix(BIOPHI_SPLIT.out.versions)

    //
    // STEP 6: ABodyBuilder2 structure prediction — one process per candidate
    //
    ch_candidate_fastas = BIOPHI_SPLIT.out.fastas
        .transpose()
        .map { meta, fasta ->
            def idx = (fasta.baseName =~ /_candidate_(\d+)$/)[0][1]
            [ meta + [id: "${meta.id}_candidate_${idx}"], fasta ]
        }

    ABODYBUILDER2(ch_candidate_fastas)
    ch_versions = ch_versions.mix(ABODYBUILDER2.out.versions)

    //
    // STEP 7: Filter candidates by CDR B-factor error
    //
    ch_filter_input = ch_candidate_fastas
        .join(ABODYBUILDER2.out.pdb, by: 0)

    FILTER_ABODYBUILDER2(ch_filter_input)
    ch_versions = ch_versions.mix(FILTER_ABODYBUILDER2.out.versions)

    //
    // STEP 8: OASis humanness scoring on structurally-validated candidates
    //
    ch_oasis_db = file(params.oasis_db)

    OASIS(FILTER_ABODYBUILDER2.out.filtered, ch_oasis_db)
    ch_versions = ch_versions.mix(OASIS.out.versions)

    //
    // STEP 9: Rank candidates by OASis percentile
    //
    RANK_OASIS(OASIS.out.scores)
    ch_versions = ch_versions.mix(RANK_OASIS.out.versions)

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_antibodyoptimization_software_mqc_versions.yml',
            sort: true,
            newLine: true
        )

    emit:
    versions = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
