# Group 2b — Implementation Plan
**Repo:** `JelPej/nf-core-antibody-pipeline`
**Local clone:** `nf-core-antibody-pipeline/`

---

## Your issues

| Issue | Task | Assignee | Status |
|-------|------|----------|--------|
| [#4](https://github.com/JelPej/nf-core-antibody-pipeline/issues/4) | Write custom Dockerfile for ABodyBuilder2 | jaaaana | Open |
| [#5](https://github.com/JelPej/nf-core-antibody-pipeline/issues/5) | Write nf-core module for ABodyBuilder2 | jaaaana | Open |
| [#8](https://github.com/JelPej/nf-core-antibody-pipeline/issues/8) | Write nf-core module for OASis humanness scoring | — | Open |
| [#9](https://github.com/JelPej/nf-core-antibody-pipeline/issues/9) | Wire all modules into end-to-end pipeline | — | Open |
| [#10](https://github.com/JelPej/nf-core-antibody-pipeline/issues/10) | End-to-end test run with 6y1l test PDB | — | Open |

---

## Pipeline flow (where your modules fit)

```
/data/pdb/6y1l.pdb  (input PDB — IMGT-numbered)
         │
         ▼  ── Group 2a (Issues #2, #3)
     AntiFold           →  CDR candidate sequences (.fasta)
         │
         ▼  ── YOU (Issue #5)
     ABodyBuilder2      →  predicted PDB per candidate (.pdb, failed predictions flagged)
         │
         ▼  ── Group 2a (Issues #6, #7)
     BioPhi Sapiens     →  humanized sequences (.fasta)
         │
         ▼  ── YOU (Issue #8)
     OASis              →  humanness scores, ranked candidates (.csv)
```

**Entry command (Issue #10):**
```bash
nextflow run . -profile docker --input /data/pdb/6y1l.pdb --outdir ./results
```

---

## Shared resources (pre-staged, do not download)

| Resource | Path |
|----------|------|
| Test PDB | `/data/pdb/6y1l.pdb` |
| OASis database | `/data/oasis/OASis_9mers_v1.db` |
| BioPhi+OASis Docker | Shared image built in Issue #6 by Group 2a — coordinate on image name |

---

## Task 1 — Dockerfile for ABodyBuilder2 (Issue #4)

**File to create:** `docker/abodybuilder2/Dockerfile`

**Source:** https://github.com/oxpig/ImmuneBuilder

**Acceptance criteria:**
- [ ] Dockerfile builds successfully
- [ ] `ABodyBuilder2 --help` runs inside container
- [ ] Image pushed to Docker Hub or GitHub Container Registry

**Dockerfile:**
```dockerfile
FROM continuumio/miniconda3

RUN conda install -y -c conda-forge python=3.9 openmm pdbfixer && \
    conda clean -afy

RUN pip install --no-cache-dir ImmuneBuilder anarci

CMD ["ABodyBuilder2", "--help"]
```

> `python:3.9-slim` won't work cleanly — `openmm` and `pdbfixer` need conda.

**Build & test:**
```bash
cd nf-core-antibody-pipeline

docker build -t abodybuilder2:latest docker/abodybuilder2/

# Acceptance check 1: help text prints
docker run --rm abodybuilder2:latest ABodyBuilder2 --help

# Acceptance check 2: predicts structure from FASTA
cat > /tmp/test_antibody.fasta << 'EOF'
>heavy
EVQLVESGGGLVQPGGSLRLSCAASGFTFSSYAMSWVRQAPGKGLEWVSAISGSGGSTYYADSVKGRFTISRDNSKNTLYLQMNSLRAEDTAVYYCAR
>light
DIQMTQSPSSLSASVGDRVTITCRASQDVNTAVAWYQQKPGKAPKLLIYSASFLYSGVPSRFSGSRSGTDFTLTISSLQPEDFATYYCQQHYTTPPTFG
EOF

docker run --rm -v /tmp:/data abodybuilder2:latest \
  ABodyBuilder2 --fasta /data/test_antibody.fasta --output /data/ab2_out/
ls /tmp/ab2_out/   # should contain a .pdb file
```

---

## Task 2 — nf-core module for ABodyBuilder2 (Issue #5)

**File to create:** `modules/local/abodybuilder2/main.nf`

**Acceptance criteria:**
- [ ] Accepts FASTA input, produces PDB output per candidate
- [ ] Failed/invalid predictions are flagged (not silently skipped)
- [ ] Follows nf-core module template (meta map, versions.yml, stub block)
- [ ] Depends on Task 1 being done first

**Module:**
```nextflow
process ABODYBUILDER2 {
    tag "$meta.id"
    label 'process_medium'

    container 'abodybuilder2:latest'

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("${meta.id}.pdb"),    emit: pdb
    tuple val(meta), path("*.failed.txt"),       emit: failed, optional: true
    path  "versions.yml",                        emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    ABodyBuilder2 \\
        --fasta ${fasta} \\
        --output ./ \\
        ${args} \\
        || echo "FAILED: ${prefix}" > ${prefix}.failed.txt

    # Rename output to include sample prefix if successful
    if ls *.pdb 1>/dev/null 2>&1; then
        mv *.pdb ${prefix}.pdb
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ImmuneBuilder: \$(python -c "import ImmuneBuilder; print(ImmuneBuilder.__version__)")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.pdb
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ImmuneBuilder: 1.0.0
    END_VERSIONS
    """
}
```

**Test:**
```bash
# Stub test first (no Docker needed — just checks syntax)
nextflow run modules/local/abodybuilder2/main.nf -stub

# Real test (needs Task 1 done)
nextflow run modules/local/abodybuilder2/main.nf \
  -profile docker \
  --input /tmp/test_antibody.fasta
```

---

## Task 3 — nf-core module for OASis (Issue #8)

**File to create:** `modules/local/biophi/oasis/main.nf`

> Uses the **same Docker image as BioPhi Sapiens** (Issue #6 — built by Group 2a).
> Coordinate with TheeOliver on the final image name before running real tests.

**Acceptance criteria:**
- [ ] Module queries OASis database and returns humanness scores
- [ ] Output includes ranked list of candidates by humanness score
- [ ] Follows nf-core module template
- [ ] Depends on Issue #6 (BioPhi Docker image)

**Module:**
```nextflow
process BIOPHI_OASIS {
    tag "$meta.id"
    label 'process_medium'

    container 'biophi:latest'

    input:
    tuple val(meta), path(fasta)
    path  oasis_db

    output:
    tuple val(meta), path("${meta.id}_oasis.csv"), emit: scores
    path  "versions.yml",                          emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    biophi oasis ${fasta} \\
        --oasis-db ${oasis_db} \\
        --output ${prefix}_oasis.csv \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        biophi: \$(biophi --version 2>&1 | sed 's/biophi, version //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_oasis.csv
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        biophi: 1.0.5
    END_VERSIONS
    """
}
```

**Test:**
```bash
# Stub test (no Docker or DB needed)
nextflow run modules/local/biophi/oasis/main.nf -stub

# Real test (needs biophi:latest image + OASis DB)
docker run --rm \
  -v /tmp:/data \
  -v /data/oasis:/oasis \
  biophi:latest \
  biophi oasis /data/humanized.fasta \
  --oasis-db /oasis/OASis_9mers_v1.db \
  --output /data/oasis_scores.csv
```

---

## Task 4 — Wire end-to-end pipeline (Issue #9)

**Files to create:**
- `workflows/antibody_pipeline.nf`
- `main.nf`

**Acceptance criteria:**
- [ ] Pipeline runs end to end from PDB input to ranked candidates
- [ ] All four modules connected correctly (AntiFold → ABodyBuilder2 → BioPhi → OASis)
- [ ] Output directory is clean and well-organised
- [ ] Depends on Issues #3, #5, #7, #8 all being done

**`workflows/antibody_pipeline.nf`:**
```nextflow
include { ANTIFOLD       } from '../modules/local/antifold/main'
include { ABODYBUILDER2  } from '../modules/local/abodybuilder2/main'
include { BIOPHI_SAPIENS } from '../modules/local/biophi/sapiens/main'
include { BIOPHI_OASIS   } from '../modules/local/biophi/oasis/main'

workflow ANTIBODY_PIPELINE {
    // Single PDB input → meta map
    ch_pdb = Channel
        .fromPath(params.input)
        .map { pdb -> [ [id: pdb.baseName], pdb ] }

    // OASis DB as a single path (reused for all samples)
    ch_oasis_db = file(params.oasis_db)

    // Chain modules
    ANTIFOLD       ( ch_pdb )
    ABODYBUILDER2  ( ANTIFOLD.out.fasta )
    BIOPHI_SAPIENS ( ABODYBUILDER2.out.pdb )
    BIOPHI_OASIS   ( BIOPHI_SAPIENS.out.fasta, ch_oasis_db )

    emit:
    scores = BIOPHI_OASIS.out.scores
}
```

**`main.nf`:**
```nextflow
#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

include { ANTIBODY_PIPELINE } from './workflows/antibody_pipeline'

workflow {
    ANTIBODY_PIPELINE ()
}
```

**Test (stub — validates wiring before all images are ready):**
```bash
nextflow run . -stub \
  --input /data/pdb/6y1l.pdb \
  --oasis_db /data/oasis/OASis_9mers_v1.db \
  --outdir ./results_stub
```

---

## Task 5 — End-to-end test with 6y1l (Issue #10)

**Acceptance criteria:**
- [ ] Pipeline completes without errors
- [ ] AntiFold produces CDR candidate sequences
- [ ] ABodyBuilder2 produces refolded structures
- [ ] BioPhi produces humanized sequences
- [ ] OASis produces humanness scores
- [ ] Final output contains ranked candidates

**Exact command from the issue:**
```bash
nextflow run . -profile docker \
  --input /data/pdb/6y1l.pdb \
  --outdir ./results
```

**For OASis you'll also need:**
```bash
nextflow run . -profile docker \
  --input /data/pdb/6y1l.pdb \
  --oasis_db /data/oasis/OASis_9mers_v1.db \
  --outdir ./results
```

**Check outputs:**
```bash
ls results/antifold/          # FASTA candidates
ls results/abodybuilder2/     # PDB structures + any *.failed.txt
ls results/biophi/sapiens/    # humanized FASTA
ls results/biophi/oasis/      # *_oasis.csv — ranked candidates
```

---

## Recommended working order

```
[ ] Task 1  →  docker build + ABodyBuilder2 --help
[ ] Task 2  →  nextflow run modules/local/abodybuilder2/main.nf -stub
[ ] Task 2  →  nextflow run modules/local/abodybuilder2/main.nf -profile docker  (needs Task 1)
[ ] Task 3  →  nextflow run modules/local/biophi/oasis/main.nf -stub
[ ] Task 3  →  real run  (coordinate with TheeOliver for biophi:latest)
[ ] Task 4  →  nextflow run . -stub  (validates wiring, no images needed)
[ ] Task 5  →  nextflow run . -profile docker  (all modules + images done)
```

---

## Files you will create

```
nf-core-antibody-pipeline/
├── docker/
│   └── abodybuilder2/
│       └── Dockerfile                    ← Issue #4
├── modules/local/
│   ├── abodybuilder2/
│   │   └── main.nf                       ← Issue #5
│   └── biophi/
│       └── oasis/
│           └── main.nf                   ← Issue #8
├── workflows/
│   └── antibody_pipeline.nf              ← Issue #9
└── main.nf                               ← Issue #9
```
