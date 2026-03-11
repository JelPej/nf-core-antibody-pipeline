# Group 2b — Implementation Plan
**Repo:** `JelPej/nf-core-antibody-pipeline`
**Local clone:** `nf-core-antibody-pipeline/`

---

## Issue status

| Issue | Task | Assignee | Status |
|-------|------|----------|--------|
| [#1](https://github.com/JelPej/nf-core-antibody-pipeline/issues/1) | Initialise pipeline (samplesheet/schema/test.config for PDB) | pdias | **Done** ✅ |
| [#4](https://github.com/JelPej/nf-core-antibody-pipeline/issues/4) | Write custom Dockerfile for ABodyBuilder2 | jaaaana | **Done** ✅ |
| [#5](https://github.com/JelPej/nf-core-antibody-pipeline/issues/5) | Write nf-core module for ABodyBuilder2 | jaaaana | **Done** ✅ |
| [#8](https://github.com/JelPej/nf-core-antibody-pipeline/issues/8) | Write nf-core module for OASis humanness scoring | — | Open — waiting on biophi image (#6) |
| [#9](https://github.com/JelPej/nf-core-antibody-pipeline/issues/9) | Wire all modules into end-to-end pipeline | — | Open — depends on #3, #5, #7, #8 |
| [#10](https://github.com/JelPej/nf-core-antibody-pipeline/issues/10) | End-to-end test run with 6y1l test PDB | — | Open — depends on #9 |

---

## Pipeline flow (where our modules fit)

```
assets/samplesheet_test.csv  →  /data/antifold/pdbs/6y1l_imgt.pdb  (IMGT-numbered PDB input)
         │
         ▼  ── Group 2a (Issues #2, #3)
     AntiFold           →  CDR candidate sequences (.fasta)
         │
         ▼  ── US (Issue #5)
     ABodyBuilder2      →  predicted PDB per candidate (.pdb, failed predictions flagged)
         │
         ▼  ── Group 2a (Issues #6, #7)
     BioPhi Sapiens     →  humanized sequences (.fasta)
         │
         ▼  ── US (Issue #8)
     OASis              →  humanness scores (.csv)
```

**Entry command (Issue #10):**
```bash
nextflow run . -profile docker,test --outdir ./results
```

---

## Shared resources (pre-staged, do not download)

| Resource | Host path |
|----------|-----------|
| Test PDB (IMGT-numbered) | `/data/antifold/pdbs/6y1l_imgt.pdb` |
| OASis database | `/data/oasis/OASis_9mers_v1.db` |
| BioPhi+OASis Docker | Built in Issue #6 by TheeOliver — coordinate image name before Issue #8 |

---

## Task 1 — Dockerfile for ABodyBuilder2 (Issue #4) ✅

**File:** `docker/abodybuilder2/Dockerfile` — see [docker/abodybuilder2/Dockerfile](../docker/abodybuilder2/Dockerfile)

**What's in it:** `continuumio/miniconda3:latest`, python=3.10, openmm+pdbfixer via conda, PyTorch CPU via pip, ANARCI, ImmuneBuilder. ENTRYPOINT `/bin/bash`.

**Acceptance criteria:**
- [x] Dockerfile builds successfully
- [x] `ABodyBuilder2 --help` runs inside container
- [ ] Image pushed to Docker Hub or GitHub Container Registry

**Build & test:**
```bash
docker build -t abodybuilder2:latest docker/abodybuilder2/

# Check CLI
docker run --rm abodybuilder2:latest ABodyBuilder2 --help

# Predict structure — headers must be exactly >H and >L
docker run --rm -v /tmp:/data abodybuilder2:latest \
  ABodyBuilder2 -f /data/test_antibody.fasta -o /data/test_out.pdb
ls /tmp/test_out.pdb
```

> **Confirmed CLI flags:** `ABodyBuilder2 -f <fasta> -o <output.pdb>`

---

## Task 2 — nf-core module for ABodyBuilder2 (Issue #5) ✅

**File:** `modules/local/abodybuilder2/main.nf`

**Acceptance criteria:**
- [x] Accepts FASTA input (`tuple val(meta), path(fasta)`), produces PDB output
- [x] Failed predictions flagged via optional `*.failed.txt` (not silently skipped)
- [x] Follows nf-core module template (meta map, versions.yml, stub block)

**Channel contract:**
```
Input:  tuple val(meta), path(fasta)        ← from ANTIFOLD
Output: tuple val(meta), path("${prefix}.pdb")   emit: pdb     → to BIOPHI_SAPIENS
        tuple val(meta), path("*.failed.txt")     emit: failed  (optional)
        path "versions.yml"                        emit: versions
```

**Test:**
```bash
# Stub test — validates syntax, no Docker needed
nextflow run . -stub -profile test --outdir ./results_stub
```

---

## Task 3 — nf-core module for OASis (Issue #8)

**File to create:** `modules/local/biophi/oasis/main.nf`

> Uses the **same Docker image as BioPhi Sapiens** (built in Issue #6 by TheeOliver).
> Confirm image name before writing `container` directive.

**Acceptance criteria:**
- [ ] Accepts humanized FASTA + OASis DB path, produces `*_oasis.csv`
- [ ] Follows nf-core module template
- [ ] Depends on Issue #6 (BioPhi Docker image)

**Channel contract:**
```
Input:  tuple val(meta), path(fasta)        ← from BIOPHI_SAPIENS
        path oasis_db                        ← params.oasis_db
Output: tuple val(meta), path("${prefix}_oasis.csv")   emit: scores
        path "versions.yml"                              emit: versions
```

**Module template:**
```nextflow
process BIOPHI_OASIS {
    tag "$meta.id"
    label 'process_medium'

    container 'biophi:latest'   // confirm name with TheeOliver

    input:
    tuple val(meta), path(fasta)
    path  oasis_db

    output:
    tuple val(meta), path("${prefix}_oasis.csv"), emit: scores
    path  "versions.yml",                          emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix   = task.ext.prefix ?: "${meta.id}"
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
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_oasis.csv
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        biophi: 1.0.5
    END_VERSIONS
    """
}
```

---

## Task 4 — Wire end-to-end pipeline (Issue #9)

**File to edit:** `workflows/antibodyoptimization.nf` (nf-core template stub — currently only runs MultiQC)

**Acceptance criteria:**
- [ ] All four modules wired: AntiFold → ABodyBuilder2 → BioPhi Sapiens → OASis
- [ ] `ch_samplesheet` from `PIPELINE_INITIALISATION` feeds into `ANTIFOLD`
- [ ] OASis DB passed via `params.oasis_db`
- [ ] Depends on Issues #3, #5, #7, #8 all being done

**Wiring sketch:**
```nextflow
include { ANTIFOLD       } from '../modules/local/antifold/main'
include { ABODYBUILDER2  } from '../modules/local/abodybuilder2/main'
include { BIOPHI_SAPIENS } from '../modules/local/biophi/sapiens/main'
include { BIOPHI_OASIS   } from '../modules/local/biophi/oasis/main'

workflow ANTIBODYOPTIMIZATION {
    take:
    ch_samplesheet   // tuple val(meta), path(pdb) — from PIPELINE_INITIALISATION

    main:
    ch_oasis_db = file(params.oasis_db)

    ANTIFOLD       ( ch_samplesheet )
    ABODYBUILDER2  ( ANTIFOLD.out.fasta )
    BIOPHI_SAPIENS ( ABODYBUILDER2.out.pdb )
    BIOPHI_OASIS   ( BIOPHI_SAPIENS.out.fasta, ch_oasis_db )
    ...
}
```

**Stub test (validates wiring before all images are ready):**
```bash
nextflow run . -stub -profile test --oasis_db /data/oasis/OASis_9mers_v1.db --outdir ./results_stub
```

---

## Task 5 — End-to-end test with 6y1l (Issue #10)

**Acceptance criteria:**
- [ ] Pipeline completes without errors
- [ ] AntiFold produces CDR candidate sequences
- [ ] ABodyBuilder2 produces refolded structures
- [ ] BioPhi produces humanized sequences
- [ ] OASis produces humanness scores

**Run command:**
```bash
nextflow run . -profile docker,test \
  --oasis_db /data/oasis/OASis_9mers_v1.db \
  --outdir ./results
```

**Check outputs:**
```bash
ls results/antifold/          # FASTA candidates
ls results/abodybuilder2/     # PDB structures + any *.failed.txt
ls results/biophi/sapiens/    # humanized FASTA
ls results/biophi/oasis/      # *_oasis.csv
```

---

## Working order

```
[x] Issue #1  →  assets/samplesheet.csv, schema_input.json, conf/test.config, assets/samplesheet_test.csv
[x] Issue #4  →  docker/abodybuilder2/Dockerfile — built and smoke-tested
[x] Issue #5  →  modules/local/abodybuilder2/main.nf — created
[ ] Issue #8  →  modules/local/biophi/oasis/main.nf — blocked on biophi image name from TheeOliver (#6)
[ ] Issue #7  →  modules/local/biophi/sapiens/main.nf — Group 2a (TheeOliver)
[ ] Issue #3  →  modules/local/antifold/main.nf — Group 2a (avitanov)
[ ] Issue #9  →  wire workflows/antibodyoptimization.nf — once #3, #5, #7, #8 done
[ ] Issue #10 →  end-to-end test — once #9 done
```

---

## Files — current state

```
nf-core-antibody-pipeline/
├── assets/
│   ├── samplesheet.csv               ← template (sample,pdb,chain_heavy,chain_light)
│   ├── samplesheet_test.csv          ← test entry: 6y1l_imgt.pdb H L  ✅
│   └── schema_input.json             ← validates PDB samplesheet  ✅
├── conf/
│   └── test.config                   ← points to samplesheet_test.csv  ✅
├── docker/
│   └── abodybuilder2/
│       └── Dockerfile                ← Issue #4  ✅
├── modules/local/
│   ├── abodybuilder2/
│   │   └── main.nf                   ← Issue #5  ✅
│   ├── antifold/                     ← Issue #3  (Group 2a — pending)
│   └── biophi/
│       ├── sapiens/                  ← Issue #7  (Group 2a — pending)
│       └── oasis/                    ← Issue #8  (pending, blocked on image)
└── workflows/
    └── antibodyoptimization.nf       ← Issue #9  (pending — needs all modules)
```
