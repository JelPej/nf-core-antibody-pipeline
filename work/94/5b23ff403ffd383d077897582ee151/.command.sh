#!/usr/bin/env bash -C -e -u -o pipefail
biophi sapiens \
    test_input.fasta \
    --fasta-only \
    --output value1_humanized.fasta \


cat <<-END_VERSIONS > versions.yml
"BIOPHI_SAPIENS":
    biophi: $(biophi --version 2>&1 | grep -oP '(?<=BioPhi )\S+')
END_VERSIONS
