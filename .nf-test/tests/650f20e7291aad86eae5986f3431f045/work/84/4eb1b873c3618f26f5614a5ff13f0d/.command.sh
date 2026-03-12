#!/usr/bin/env bash -C -e -u -o pipefail
touch test_antibody_humanized.fasta

cat <<-END_VERSIONS > versions.yml
"BIOPHI_SAPIENS":
    biophi: stub
END_VERSIONS
