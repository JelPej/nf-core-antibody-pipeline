# Antibody Optimization Pipeline — Full Reference

> **Working on this?** See `GROUP_2B_PLAN.md` for the focused Group 2b task list.
>
> GitHub repo: `JelPej/nf-core-antibody-pipeline`

## Overview

Sequential nf-core DSL2 pipeline:

```
PDB input (antibody structure, IMGT-numbered)
    │
    ▼
AntiFold       →  CDR inverse folding → redesigned FASTA candidates
    │
    ▼
ABodyBuilder2  →  structure prediction → PDB per candidate
    │
    ▼
BioPhi Sapiens →  humanization → humanized sequences (FASTA)
    │
    ▼
OASis          →  humanness scoring against observed antibody space (CSV)
```

---

## Test Data

| Resource | Host path | Notes |
|----------|-----------|-------|
| Test PDB (6y1l, IMGT-numbered) | `/data/antifold/pdbs/6y1l_imgt.pdb` | Pre-staged — do not download |
| OASis DB (~22 GB) | `/data/oasis/OASis_9mers_v1.db` | Pre-staged — do not download |

Test samplesheet: `assets/samplesheet_test.csv`

---

## Input Format

Samplesheet CSV passed to `--input`:

```csv
sample,pdb,chain_heavy,chain_light
6y1l,/data/antifold/pdbs/6y1l_imgt.pdb,H,L
```

Schema validated by `assets/schema_input.json` via nf-schema plugin.
The `chain_heavy` and `chain_light` columns are pulled into the `meta` map and passed through all module boundaries.

---

## Channel Contract

| Boundary | Shape |
|----------|-------|
| Input → AntiFold | `tuple val(meta), path(pdb)` |
| AntiFold → ABodyBuilder2 | `tuple val(meta), path(fasta)` |
| ABodyBuilder2 → BioPhi Sapiens | `tuple val(meta), path(pdb)` |
| BioPhi Sapiens → OASis | `tuple val(meta), path(fasta)` |

`meta` map must carry: `id`, `sample`, `chain_heavy`, `chain_light`.

---

## Tasks

---

### Task 1 — Dockerfiles

Build and test each container individually before writing any Nextflow.

#### 1a. ABodyBuilder2 (`docker/abodybuilder2/Dockerfile`) ✅

- Base: `continuumio/miniconda3:latest`
- Conda: `python=3.10 openmm pdbfixer`
- Pip: `torch` (CPU), `anarci`, `ImmuneBuilder`
- ENTRYPOINT: `/bin/bash`

**CLI (confirmed):** `ABodyBuilder2 -f <fasta> -o <output.pdb>` — FASTA headers must be `>H` and `>L`

**Test:**
```bash
docker build -t abodybuilder2:latest docker/abodybuilder2/
docker run --rm abodybuilder2:latest ABodyBuilder2 --help
docker run --rm -v /tmp:/data abodybuilder2:latest \
  ABodyBuilder2 -f /data/test.fasta -o /data/out.pdb
```

---

#### 1b. AntiFold (`docker/antifold/Dockerfile`) — Group 2a (Issue #2)

- Base: `pytorch/pytorch:2.2.0-cuda12.1-cudnn8-runtime`
- Pip: `antifold`
- CLI: `python -m antifold.main`

**Test:**
```bash
docker build -t antifold:latest docker/antifold/
docker run --rm -v /data/antifold/pdbs:/data antifold:latest \
  python -m antifold.main \
  --pdb_file /data/6y1l_imgt.pdb \
  --heavy_chain H --light_chain L \
  --num_seq_per_target 3 --sampling_temp 0.2 \
  --out_dir /data/antifold_out/
```

---

#### 1c. BioPhi (`docker/biophi/Dockerfile`) — Group 2a (Issue #6)

- Base: `mambaorg/micromamba:1.5.8`
- Conda: `biophi python=3.9 -c bioconda -c conda-forge`
- OASis DB is **not** baked into image — mounted at runtime via `params.oasis_db`

**Test (Sapiens, no DB):**
```bash
docker build -t biophi:latest docker/biophi/
docker run --rm -v /tmp:/data biophi:latest \
  biophi sapiens /data/variants.fasta --scores-only --output /data/sapiens.csv
```

**Test (OASis, needs DB):**
```bash
docker run --rm \
  -v /tmp:/data \
  -v /data/oasis:/oasis \
  biophi:latest \
  biophi oasis /data/variants.fasta \
  --oasis-db /oasis/OASis_9mers_v1.db \
  --output /data/oasis_scores.csv
```

---

### Task 2 — Nextflow Modules

#### 2a. `modules/local/antifold/main.nf` — Group 2a (Issue #3)

```
Input:  tuple val(meta), path(pdb)
Output: tuple val(meta), path("*.fasta"),  emit: fasta
        tuple val(meta), path("*.csv"),    emit: scores
        path "versions.yml",               emit: versions
```

#### 2b. `modules/local/abodybuilder2/main.nf` ✅ (Issue #5)

```
Input:  tuple val(meta), path(fasta)
Output: tuple val(meta), path("${prefix}.pdb"),    emit: pdb
        tuple val(meta), path("*.failed.txt"),      emit: failed (optional)
        path "versions.yml",                         emit: versions
```

CLI: `ABodyBuilder2 -f ${fasta} -o ${prefix}.pdb`

#### 2c. `modules/local/biophi/sapiens/main.nf` — Group 2a (Issue #7)

```
Input:  tuple val(meta), path(pdb)
Output: tuple val(meta), path("*_sapiens.fasta"),  emit: fasta
        tuple val(meta), path("*_sapiens.csv"),    emit: scores
        path "versions.yml",                        emit: versions
```

#### 2d. `modules/local/biophi/oasis/main.nf` — US (Issue #8)

```
Input:  tuple val(meta), path(fasta)
        path oasis_db
Output: tuple val(meta), path("${prefix}_oasis.csv"),  emit: scores
        path "versions.yml",                             emit: versions
```

CLI: `biophi oasis ${fasta} --oasis-db ${oasis_db} --output ${prefix}_oasis.csv`

---

### Task 3 — Main Workflow (Issue #9)

**File to edit:** `workflows/antibodyoptimization.nf`

Wire all four modules. Input comes from `PIPELINE_INITIALISATION` as `tuple val(meta), path(pdb)`.

```nextflow
include { ANTIFOLD       } from '../modules/local/antifold/main'
include { ABODYBUILDER2  } from '../modules/local/abodybuilder2/main'
include { BIOPHI_SAPIENS } from '../modules/local/biophi/sapiens/main'
include { BIOPHI_OASIS   } from '../modules/local/biophi/oasis/main'

workflow ANTIBODYOPTIMIZATION {
    take:
    ch_samplesheet

    main:
    ch_oasis_db = file(params.oasis_db)

    ANTIFOLD       ( ch_samplesheet )
    ABODYBUILDER2  ( ANTIFOLD.out.fasta )
    BIOPHI_SAPIENS ( ABODYBUILDER2.out.pdb )
    BIOPHI_OASIS   ( BIOPHI_SAPIENS.out.fasta, ch_oasis_db )
    ...
}
```

**Stub test:**
```bash
nextflow run . -stub -profile test --oasis_db /data/oasis/OASis_9mers_v1.db --outdir ./results_stub
```

---

### Task 4 — End-to-End Test (Issue #10)

```bash
nextflow run . -profile docker,test \
  --oasis_db /data/oasis/OASis_9mers_v1.db \
  --outdir ./results

# Verify
ls results/antifold/          # FASTA candidates
ls results/abodybuilder2/     # PDB structures + *.failed.txt
ls results/biophi/sapiens/    # humanized FASTA + Sapiens scores
ls results/biophi/oasis/      # *_oasis.csv — humanness scores
```

---

## Parameters Reference

| Param | Required | Default | Description |
|-------|----------|---------|-------------|
| `--input` | yes | — | Samplesheet CSV (`sample,pdb,chain_heavy,chain_light`) |
| `--oasis_db` | yes | — | Path to `OASis_9mers_v1.db` |
| `--outdir` | yes | `results` | Output directory |
| `--num_seq` | no | `10` | Variant sequences per target (AntiFold) |
| `--sampling_temp` | no | `0.2` | Sampling temperature (AntiFold) |
| `--regions` | no | `CDR1 CDR2 CDR3` | Regions to redesign (AntiFold) |

---

## Files — current state

```
nf-core-antibody-pipeline/
├── assets/
│   ├── samplesheet.csv               ✅  template (sample,pdb,chain_heavy,chain_light)
│   ├── samplesheet_test.csv          ✅  test entry pointing to 6y1l_imgt.pdb
│   └── schema_input.json             ✅  PDB validation schema
├── conf/
│   ├── base.config                   ✅  resource labels
│   ├── modules.config                ✅  publishDir rules
│   └── test.config                   ✅  points to samplesheet_test.csv
├── docker/
│   ├── abodybuilder2/Dockerfile      ✅  Issue #4
│   ├── antifold/Dockerfile           ⏳  Issue #2 (Group 2a)
│   └── biophi/Dockerfile             ⏳  Issue #6 (Group 2a)
├── modules/local/
│   ├── abodybuilder2/main.nf         ✅  Issue #5
│   ├── antifold/main.nf              ⏳  Issue #3 (Group 2a)
│   └── biophi/
│       ├── sapiens/main.nf           ⏳  Issue #7 (Group 2a)
│       └── oasis/main.nf             ⏳  Issue #8 (blocked on #6)
├── subworkflows/local/
│   └── utils_nfcore_antibodyoptimization_pipeline/main.nf  ✅  PDB samplesheet parsing
└── workflows/
    └── antibodyoptimization.nf       ⏳  Issue #9 — wire modules here
```
