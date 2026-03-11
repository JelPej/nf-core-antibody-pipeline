# Antibody Optimization Pipeline — Full Reference

> **Working on this?** See `GROUP_2B_PLAN.md` for the focused Group 2b task list.
>
> GitHub repo: `JelPej/nf-core-antibody-pipeline`

## Overview

Sequential nf-core DSL2 pipeline:

```
FASTA (H+L chains)
    │
    ▼
ABodyBuilder2  →  structure prediction (PDB)
    │
    ▼
AntiFold       →  inverse folding → variant sequences (FASTA + CSV)
    │
    ▼
BioPhi         →  Sapiens humanness score + OASis humanness percentile
    │
    ▼
rank_candidates.py  →  ranked TSV of best candidates
```

---

## Test Data

| Resource | How to get |
|----------|-----------|
| Test PDB (6y1l) | `wget https://opig.stats.ox.ac.uk/webapps/sabdab-sabpred/sabdab/pdb/6y1l/` |
| AntiFold test data | Included at `AntiFold/data/` when you clone the repo |
| OASis DB (~22 GB) | `wget https://zenodo.org/record/5164685/files/OASis_9mers_v1.db.gz` → store at `/data/oasis/` |

---

## Tasks (work through in order)

---

### Task 1 — Dockerfiles

Build and test each container individually before writing any Nextflow.

#### 1a. ABodyBuilder2 (`docker/abodybuilder2/Dockerfile`)

- Base: `mambaorg/micromamba:1.5.8`
- Install: `python=3.9 pytorch numpy scipy einops openmm pdbfixer` via conda
- Install: `ImmuneBuilder anarci` via pip
- Include wrapper script `/usr/local/bin/run_abodybuilder2.py` that:
  - Reads a FASTA file with `>sample_H` and `>sample_L` entries
  - Calls `ABodyBuilder2().predict({'H': hseq, 'L': lseq}).save('output.pdb')`

**Test:**
```bash
docker build -t ab2:test docker/abodybuilder2/
docker run --rm -v $(pwd)/test_data:/data ab2:test \
  python /usr/local/bin/run_abodybuilder2.py \
  --fasta /data/trastuzumab.fasta --output /data/trastuzumab.pdb
# Expected: /data/trastuzumab.pdb created
```

---

#### 1b. AntiFold (`docker/antifold/Dockerfile`)

- Base: `pytorch/pytorch:2.2.0-cuda12.1-cudnn8-runtime`
- Install: `pip install antifold`
- CLI: `python -m antifold.main`

**Test:**
```bash
docker build -t antifold:test docker/antifold/
docker run --rm -v $(pwd)/test_data:/data antifold:test \
  python -m antifold.main \
  --pdb_file /data/6y1l_imgt.pdb \
  --heavy_chain H --light_chain L \
  --num_seq_per_target 3 --sampling_temp 0.2 \
  --out_dir /data/antifold_out/
# Expected: /data/antifold_out/ contains .fasta and .csv files
```

---

#### 1c. BioPhi (`docker/biophi/Dockerfile`)

- Base: `mambaorg/micromamba:1.5.8`
- Conda install: `biophi python=3.9 -c bioconda -c conda-forge`
- OASis DB is **not** baked into image — mounted at runtime via `params.oasis_db`

**Test (Sapiens only — no DB needed):**
```bash
docker build -t biophi:test docker/biophi/
docker run --rm -v $(pwd)/test_data:/data biophi:test \
  biophi sapiens /data/variants.fasta --scores-only --output /data/sapiens.csv
# Expected: /data/sapiens.csv with per-residue scores
```

**Test (OASis — needs DB):**
```bash
docker run --rm \
  -v $(pwd)/test_data:/data \
  -v /data/oasis:/oasis \
  biophi:test \
  biophi oasis /data/variants.fasta \
  --oasis-db /oasis/OASis_9mers_v1.db \
  --output /data/oasis_scores.xlsx
```

---

### Task 2 — Nextflow Modules

One module per tool. Write and test with `nextflow run` using `-stub` mode first, then real data.

#### 2a. `modules/local/abodybuilder2/main.nf`

```
Input:  tuple val(meta), path(fasta)
Output: tuple val(meta), path("${meta.id}.pdb"),   emit: pdb
        tuple val(meta), path("*.version.txt"),     emit: versions
```

#### 2b. `modules/local/antifold/main.nf`

```
Input:  tuple val(meta), path(pdb)
Output: tuple val(meta), path("*.fasta"),   emit: fasta
        tuple val(meta), path("*.csv"),     emit: scores
        tuple val(meta), path("*.version.txt"), emit: versions

Params used: params.num_seq, params.sampling_temp, params.regions
```

#### 2c. `modules/local/biophi/main.nf`

```
Input:  tuple val(meta), path(fasta)
        path oasis_db
Output: tuple val(meta), path("*_sapiens.csv"),   emit: sapiens
        tuple val(meta), path("*_oasis.xlsx"),     emit: oasis
        tuple val(meta), path("*.version.txt"),    emit: versions
```

**Test each module:**
```bash
nextflow run modules/local/abodybuilder2/main.nf -profile test,docker -stub
```

---

### Task 3 — Input Validation Subworkflow

`subworkflows/local/input_check/main.nf`

Reads the CSV samplesheet, validates it has `sample` and `fasta` columns, checks files exist, emits `[ [id: row.sample], file(row.fasta) ]` channel.

**Samplesheet format:**
```csv
sample,fasta
trastuzumab,/abs/path/trastuzumab.fasta
```

---

### Task 4 — Main Workflow

`workflows/antibody_optimization.nf`

```nextflow
include { INPUT_CHECK       } from '../subworkflows/local/input_check/main'
include { ABODYBUILDER2     } from '../modules/local/abodybuilder2/main'
include { ANTIFOLD          } from '../modules/local/antifold/main'
include { BIOPHI            } from '../modules/local/biophi/main'

workflow ANTIBODY_OPTIMIZATION {
    INPUT_CHECK ( params.input )
    ABODYBUILDER2 ( INPUT_CHECK.out.reads )
    ANTIFOLD      ( ABODYBUILDER2.out.pdb )
    BIOPHI        ( ANTIFOLD.out.fasta, file(params.oasis_db) )
}
```

---

### Task 5 — Ranking Script

`bin/rank_candidates.py`

- Reads `*_sapiens.csv` (per-residue scores → compute mean Sapiens score per sequence)
- Reads `*_oasis.xlsx` (OASis humanness percentile per sequence)
- Joins on sequence ID
- Outputs `ranked_candidates.tsv` sorted by `sapiens_score * oasis_percentile / 100`

---

### Task 6 — Configuration

#### `conf/base.config`
CPU/memory labels: `process_low`, `process_medium`, `process_high`

#### `conf/modules.config`
`publishDir` rules — where each module writes outputs under `params.outdir`

#### `conf/test.config`
```nextflow
params {
    input        = "${projectDir}/assets/test_samplesheet.csv"
    oasis_db     = "${projectDir}/assets/test_oasis_stub.db"   // tiny stub for CI
    num_seq      = 3
    sampling_temp = 0.5
    outdir       = 'test_results'
}
```
- `assets/test_samplesheet.csv` points to trastuzumab FASTA in `assets/`
- Stub OASis DB: minimal SQLite file with a few 9-mers (skips 22 GB download)

---

### Task 7 — Entry Point + Schema

#### `main.nf`
Standard nf-core entry point that calls `ANTIBODY_OPTIMIZATION`.

#### `nextflow.config`
```nextflow
profiles {
    docker     { docker.enabled = true; docker.runOptions = '-u $(id -u):$(id -g)' }
    singularity { singularity.enabled = true; singularity.autoMounts = true }
    test       { includeConfig 'conf/test.config' }
}
```

Container assignments:
```nextflow
process {
    withName: 'ABODYBUILDER2' { container = 'antibody-optimization/abodybuilder2:latest' }
    withName: 'ANTIFOLD'      { container = 'antibody-optimization/antifold:latest' }
    withName: 'BIOPHI'        { container = 'antibody-optimization/biophi:latest' }
}
```

#### `nextflow_schema.json`
nf-validation schema listing all params with types, descriptions, defaults.

---

### Task 8 — End-to-End Test

```bash
cd antibody-optimization

# Build images
docker build -t antibody-optimization/abodybuilder2:latest docker/abodybuilder2/
docker build -t antibody-optimization/antifold:latest docker/antifold/
docker build -t antibody-optimization/biophi:latest docker/biophi/

# Run test profile
nextflow run main.nf -profile test,docker --outdir test_results

# Verify outputs
ls test_results/abodybuilder2/   # *.pdb
ls test_results/antifold/        # *.fasta, *.csv
ls test_results/biophi/          # *_sapiens.csv, *_oasis.xlsx
cat test_results/ranking/*.tsv   # ranked candidates
```

---

## Parameters Reference

| Param | Required | Default | Description |
|-------|----------|---------|-------------|
| `--input` | yes | — | Samplesheet CSV (sample, fasta columns) |
| `--oasis_db` | yes | — | Path to OASis_9mers_v1.db |
| `--outdir` | yes | `results` | Output directory |
| `--num_seq` | no | `10` | Variant sequences per target (AntiFold) |
| `--sampling_temp` | no | `0.2` | Sampling temperature (AntiFold) |
| `--regions` | no | `CDR1 CDR2 CDR3` | Regions to redesign (AntiFold) |

---

## Files to Create (complete list)

```
antibody-optimization/
├── main.nf
├── nextflow.config
├── nextflow_schema.json
├── CITATIONS.md
├── assets/
│   ├── schema_input.json
│   ├── test_samplesheet.csv
│   ├── trastuzumab.fasta
│   └── test_oasis_stub.db
├── bin/
│   └── rank_candidates.py
├── conf/
│   ├── base.config
│   ├── modules.config
│   └── test.config
├── docker/
│   ├── abodybuilder2/Dockerfile
│   ├── antifold/Dockerfile
│   └── biophi/Dockerfile
├── modules/local/
│   ├── abodybuilder2/main.nf
│   ├── antifold/main.nf
│   └── biophi/main.nf
├── subworkflows/local/
│   └── input_check/main.nf
└── workflows/
    └── antibody_optimization.nf
```
