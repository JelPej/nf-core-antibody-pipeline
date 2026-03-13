# Coding Agent Guidelines

## Purpose

This file defines required behavior for autonomous coding agents working in this repository.
Agents MUST follow these rules unless a user explicitly overrides them in the current task.

---

## Persona & Baseline

- Assume a staff/principal-level bioinformatics engineering context.
- Optimize for correctness, modularity, and long-term pipeline maintainability.
- Communicate clearly, directly, and pragmatically.
- Be direct, critical, and constructive; call out suboptimal designs.
- Prefer system-level thinking over narrow fixes.
- Surface assumptions, risks, and tradeoffs when they materially affect implementation.
- Prioritize actionable outcomes over lengthy explanations.
- Avoid fluff, cheerleading, or unnecessary verbosity.
- Keep recommendations grounded in repository constraints and existing architecture.

---

## Project Knowledge

### What This Project Does

End-to-end nf-core Nextflow pipeline (`nf-core/antibodyoptimization`) for antibody optimization.
Takes an antibody PDB structure as input and produces redesigned, structurally verified, and humanized
antibody sequences with OASis humanness scores.

### Core Stack

| Layer | Technology |
|---|---|
| Workflow framework | Nextflow DSL2 (`>=25.04.0` required) |
| Pipeline conventions | nf-core strict |
| Containers | Docker (primary); registry `quay.io` by default |
| Input validation | nf-schema plugin `2.5.1` |
| Module testing | nf-test |
| Linting / validation | nf-core lint, nf-core schema lint |
| Input format | PDB structure file via samplesheet CSV |

### Pipeline Stage Order

```
PDB input (antibody structure)
   ↓
ANTIFOLD_CDR      — CDR redesign via inverse folding → redesigned FASTA candidates (VH/VL joined with '/')
   ↓
ANTIFOLD_SPLIT    — split joined VH/VL sequences into separate FASTA records (_VH / _VL suffixes)
   ↓
FILTER_ANTIFOLD   — CDR log-odds score (AntiFold `score` field) > threshold (user-defined) [in progress — separate owner]
   ↓
BIOPHI_SAPIENS    — humanization → humanized FASTA + per-sequence Sapiens scores CSV
   ↓
FILTER_BIOPHI     — Sapiens humanness score ≥ params.sapiens_min_score (default: 0.8)
   ↓
ABODYBUILDER2     — structure prediction → PDB per humanized candidate
   ↓
FILTER_ABODYBUILDER2 — mean CDR B-factor error < 1.5 Å AND Cα CDR RMSD to input PDB < 2.0 Å
   ↓
OASIS             — humanness scoring against observed antibody space
   ↓
RANK_OASIS        — rank by OASis percentile (0–100); exclude extreme outliers below params.oasis_min_percentile (default: 10)
   ↓
results/ (ranked candidates: sequences + OASis humanness scores)
```

### Channel Contract

Preserve these channel shapes at module boundaries:

| Boundary | Channel shape |
|---|---|
| Input → ANTIFOLD_CDR | `tuple val(meta), path(pdb)` |
| ANTIFOLD_CDR → ANTIFOLD_SPLIT | `tuple val(meta), path(redesigned_fasta)` |
| ANTIFOLD_CDR → FILTER_ANTIFOLD | `tuple val(meta), path(redesigned_fasta), path(scores_csv)` (join on `meta.id`) |
| FILTER_ANTIFOLD → BIOPHI_SAPIENS | `tuple val(meta), path(split_fasta)` |
| BIOPHI_SAPIENS → FILTER_BIOPHI | `tuple val(meta), path(humanized_fasta), path(sapiens_scores_csv)` |
| FILTER_BIOPHI → ABODYBUILDER2 | `tuple val(meta), path(humanized_fasta)` — **one tuple per antibody candidate** (see Known Issues) |
| ABODYBUILDER2 → FILTER_ABODYBUILDER2 | `tuple val(meta), path(predicted_pdb)` joined with original `path(input_pdb)` via `meta.id` |
| FILTER_ABODYBUILDER2 → OASIS | `tuple val(meta), path(predicted_pdb)` |
| OASIS → RANK_OASIS | `tuple val(meta), path(oasis_scores_csv)` |
| RANK_OASIS → output | `tuple val(meta), path(ranked_scores_csv)` |

The `meta` map MUST contain at minimum: `id`, `sample`, `chain_heavy`, `chain_light`.
Do not add meta fields without updating all affected modules.

Score files are used by filter modules for inter-stage filtering and published to `results/` as-is. Do not embed scores in the `meta` map. The original input PDB must be carried as a separate channel and joined by `meta.id` at `FILTER_ABODYBUILDER2`.

### Known Issues / Open Design Gaps

- **FILTER_BIOPHI → ABODYBUILDER2 compatibility (unresolved)**: `ABODYBUILDER2` expects one FASTA
  per antibody candidate containing exactly one VH and one VL sequence. `FILTER_BIOPHI` currently
  outputs a single multi-sequence FASTA. Before wiring `ABODYBUILDER2`, a splitting/pairing step is
  needed. Blocked by a separate issue: `ANTIFOLD_SPLIT` produces non-unique sequence IDs for
  redesigned candidates (all get `T=0.20_VH` / `T=0.20_VL`), making name-based VH+VL pairing
  impossible. Fix required in `antifold_split.py` to include `sample=N` in the ID.

---

## Common Commands

```bash
# Run full pipeline
nextflow run . -profile docker --input samplesheet.csv --outdir results

# Run with test profile (uses /data/antifold/pdbs/6y1l_imgt.pdb)
nextflow run . -profile docker,test --outdir ./results

# Dry-run (validate workflow structure without executing)
nextflow run . -profile docker,test --outdir ./results -preview

# Stub run (validates logic, no containers)
nextflow run . -profile docker,test --outdir ./results -stub

# Lint entire pipeline
nf-core lint

# Validate nextflow_schema.json
nf-core schema lint

# Test a module or subworkflow
nf-test test <path/to/tests/>
```

---

## Input Format

Primary input: antibody PDB structure file(s) via a samplesheet CSV passed to `--input`:

```csv
sample,pdb,chain_heavy,chain_light
Ab001,/path/to/Ab001.pdb,H,L
```

### Repository Layout (key paths)

```
workflows/antibodyoptimization.nf               # main workflow — wire modules here
modules/local/antifold_cdr/main.nf              # AntiFold CDR redesign
modules/local/antifold_split/main.nf            # VH/VL FASTA splitter
modules/local/biophi/main.nf                   # BioPhi Sapiens humanization (+ scores output)
modules/local/filter_biophi/main.nf            # FILTER_BIOPHI
modules/local/abodybuilder2/main.nf            # ABodyBuilder2 structure prediction
modules/local/oasis/main.nf                    # OASis humanness scoring
bin/filter_by_sapiens_score.py                 # filter script used by FILTER_BIOPHI
subworkflows/local/utils_nfcore_antibodyoptimization_pipeline/main.nf  # samplesheet parsing
assets/samplesheet.csv                         # template samplesheet
assets/samplesheet_test.csv                    # test samplesheet (points at 6y1l_imgt.pdb)
assets/schema_input.json                       # input validation schema
conf/base.config                               # resource label definitions
conf/modules.config                            # per-module publishDir and ext.args
conf/test.config                               # test profile
```

### Host Data Paths

These paths are pre-staged on the host and must be mounted into containers where needed:

| Data | Host path | Notes |
|---|---|---|
| Test PDB | `/data/antifold/pdbs/6y1l_imgt.pdb` | SAbDab entry, IMGT-numbered |
| OASis database | `/data/oasis/OASis_9mers_v1.db` | ~22 GB; mount read-only into OASis container |

---

## Key Architectural Decisions — Do Not Reverse Without Discussion

- **All modules are local** (`modules/local/`) — not nf-core community modules. Do not replace them
  with community equivalents without explicit instruction.
- **Docker is the only supported profile** at this stage. Do not add Singularity/Conda profiles
  unless explicitly requested.
- **The `meta` map is the cross-module contract.** Every process must pass `meta` through
  unchanged unless a field is explicitly being added for downstream use.
- **`versions` channel is mandatory** in every process. Never omit it, even in draft modules.
- **Resource labels** are defined in `conf/base.config`. Assign based on expected compute; do not
  hardcode CPUs/memory in modules. Available labels:
  `process_single` (1 CPU / 6 GB), `process_low` (2 CPU / 12 GB), `process_medium` (6 CPU / 36 GB),
  `process_high` (12 CPU / 72 GB), `process_long` (extended time), `process_high_memory` (200 GB),
  `process_gpu` (GPU accelerator — only effective under `-profile gpu`).
- **`BIOPHI_SAPIENS` runs twice** — once with `--fasta-only` for the humanized FASTA, once with
  `--mean-score-only` for the sapiens scores CSV. Both outputs are required by `FILTER_BIOPHI`.

---

## Required Workflow

1. **Read before writing.** Inspect relevant module, subworkflow, and config files before making changes.
2. **Check existing modules before implementing.** Verify no equivalent module or bin script already exists.
3. **Keep changes minimal and task-focused.** Do not refactor surrounding modules unless asked.
4. **Run validation before finishing.** At minimum: `nf-core lint` and targeted `nf-test` for changed modules.
5. **Report clearly.** State what changed, what was validated, and any known gaps or limitations.

---

## Coding Rules

### Nextflow / nf-core

- All processes use `tuple val(meta), path(...)` as the primary input/output channel shape.
- Every process block MUST include:
  ```nextflow
  output:
    tuple val(meta), path("*.ext"), emit: <name>
    path "versions.yml",            emit: versions
  ```
- Version capture in `script:` block:
  ```bash
  cat <<-END_VERSIONS > versions.yml
  "${task.process}":
      <tool>: $(<tool> --version 2>&1 | head -1)
  END_VERSIONS
  ```
- Container images are specified per-module with the `container` directive. Never set containers
  in `nextflow.config` globally for a specific tool.
- Use `$task.cpus` and `$task.memory` in process scripts — never hardcode resource values.

### Style

- Process names: `SCREAMING_SNAKE_CASE` (e.g. `ANTIFOLD_CDR`, `ABODYBUILDER2`).
- Workflow and subworkflow names: `SCREAMING_SNAKE_CASE`.
- Channel variable names: `snake_case`, descriptive (e.g. `ch_redesigned_fasta`).
- No inline comments unless the logic is genuinely non-obvious.
- Prefer explicit channel operations (`map`, `join`, `combine`) over implicit channel coercion.

### Defensive Coding — Do Not Add

- No hardcoded file paths in modules or workflows.
- No `println` debug statements in committed code.
- No optional/nullable channel branches unless the pipeline explicitly supports optional steps.
- Trust upstream channel outputs — do not add redundant existence checks inside processes.

---

## Change Management

- Keep diffs small and single-purpose.
- Avoid unrelated edits in the same commit.
- Do not modify the channel contract without updating all affected modules.

### Conventional Commits

Commit messages, branch names, and PR titles MUST follow
[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) format.

**Commit messages:**
```
<type>(<optional scope>): <short description>
```

**Branch names:**
```
<type>/<short-kebab-description>
```

Common types for this repo:

| Type | When to use |
|---|---|
| `feat` | New module, subworkflow, or pipeline capability |
| `fix` | Bug fix in process logic or channel wiring |
| `refactor` | Restructuring with no behaviour change |
| `test` | Adding or updating nf-test tests |
| `docs` | Documentation only |
| `chore` | Config, CI, dependency maintenance |

Examples:
- Branch: `feat/antifold-module`, `fix/meta-map-missing-field`
- Commit: `feat(modules): add AntiFold CDR redesign process`
- PR title: `fix(subworkflows): pass chain fields through meta in redesign subworkflow`

---

## Issue Tracker & Dependency Map

| # | Title | Status |
|---|---|---|
| #1 | Initialise pipeline using nf-core template | ✅ Done |
| #2 | Write custom Dockerfile for AntiFold | ✅ Done (`quay.io/avitanov/antifold:0.3.1-build2`) |
| #3 | Write nf-core module for AntiFold CDR redesign | ✅ Done (`modules/local/antifold_cdr/`) |
| #4 | Write custom Dockerfile for ABodyBuilder2 | ✅ Done (community.wave.seqera.io container) |
| #5 | Write nf-core module for ABodyBuilder2 | ✅ Done (`modules/local/abodybuilder2/`) |
| #6 | Write custom Dockerfile for BioPhi Sapiens + OASis | ✅ Done (community.wave.seqera.io container) |
| #7 | Write nf-core module for BioPhi Sapiens humanization | ✅ Done (`modules/local/biophi/`) |
| #8 | Write nf-core module for OASis humanness scoring | ✅ Done (`modules/local/oasis/`) |
| #9 | Wire all modules into end-to-end pipeline | 🔄 In progress — wired through `FILTER_BIOPHI`; remaining: `FILTER_ANTIFOLD` (separate owner), `ABODYBUILDER2`, `FILTER_ABODYBUILDER2`, `RANK_OASIS` |
| #10 | End-to-end test run with 6y1l test PDB | 🔄 In progress — tested through `FILTER_BIOPHI`; blocked on FILTER_BIOPHI → ABODYBUILDER2 compatibility (see Known Issues) |

### Notes
- BioPhi and OASis share one container image (conda install `biophi` installs both).
- OASis requires the database at `/data/oasis/OASis_9mers_v1.db` to be mounted at runtime.
- `ANTIFOLD_SPLIT` sits between `ANTIFOLD_CDR` and `FILTER_ANTIFOLD`/`BIOPHI_SAPIENS` — it is
  already implemented and wired.
- `FILTER_ANTIFOLD` is being developed by a separate team member; do not implement it independently.

---

## Definition of Done

- [ ] Implementation is complete for the requested scope.
- [ ] `nf-core lint` passes with no errors.
- [ ] Targeted `nf-test` tests pass for changed modules/subworkflows.
- [ ] `versions.yml` is emitted by every new or modified process.
- [ ] Tests and docs updated when externally visible behaviour changes.
- [ ] Final report lists: changed files, commands run, and any known limitations.
