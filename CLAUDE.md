# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

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

End-to-end nf-core Nextflow pipeline for antibody optimization. Takes PDB structure files as input
and produces redesigned, structurally verified, and humanized antibody sequences with humanness scores.

The pipeline is developed collaboratively across two groups:

- **Group 2a:** AntiFold (CDR redesign) → BioPhi Sapiens (humanization)
- **Group 2b:** ABodyBuilder2 (structural verification) → OASis (humanness scoring)

The four modules connect into a single end-to-end workflow.

### Core Stack

| Layer | Technology |
|---|---|
| Workflow framework | Nextflow DSL2 |
| Pipeline conventions | nf-core strict |
| Containers | Docker (primary) |
| Module testing | nf-test |
| Linting / validation | nf-core lint, nf-core schema lint |
| Input format | PDB structure files via samplesheet CSV |

### Pipeline Stage Order

```
PDB input
   ↓
AntiFold          — CDR redesign (Group 2a)
   ↓
ABodyBuilder2     — structural verification of redesigned sequences (Group 2b)
   ↓
BioPhi Sapiens    — humanization scoring and redesign (Group 2a)
   ↓
OASis             — humanness scoring against observed antibody space (Group 2b)
   ↓
results/
```

### Cross-Group Channel Contract

Both groups MUST agree on and preserve these channel shapes at integration boundaries:

| Boundary | Channel shape |
|---|---|
| AntiFold → ABodyBuilder2 | `tuple val(meta), path(redesigned_fasta)` |
| ABodyBuilder2 → BioPhi | `tuple val(meta), path(verified_pdb)` |
| BioPhi → OASis | `tuple val(meta), path(humanized_fasta)` |

The `meta` map MUST contain at minimum: `id`, `sample`, `chain_heavy`, `chain_light`.
Do not add meta fields without coordinating with both groups.

---

## Scope

| Area | Default behaviour |
|---|---|
| `modules/local/`, `subworkflows/local/`, `workflows/` | In scope — read and modify freely |
| `conf/`, `assets/`, `nextflow.config`, `main.nf` | In scope — modify carefully; pipeline-wide impact |
| `README.md` | In scope — update when public-facing behaviour changes |
| `bin/` | In scope — custom scripts called by processes |
| Test data files (`.pdb`, `.fasta`) | **Never modify** — managed outside git |

---

## Repository Map

```
nf-core-antibody-pipeline/
├── main.nf                          # Entry point: ANTIBODY_PIPELINE workflow
├── nextflow.config                  # Global params, profiles, process defaults
├── workflows/
│   └── antibody_pipeline.nf         # Top-level workflow wiring subworkflows
├── subworkflows/local/
│   ├── redesign/main.nf             # AntiFold → ABodyBuilder2
│   └── humanize/main.nf             # BioPhi → OASis
├── modules/local/
│   ├── antifold/main.nf
│   ├── abodybuilder2/main.nf
│   ├── biphi_sapiens/main.nf
│   └── oasis/main.nf
├── conf/
│   ├── base.config                  # Resource labels and defaults
│   └── test.config                  # Minimal params for test profile
├── assets/
│   └── schema_input.json            # Samplesheet validation schema
└── bin/                             # Custom helper scripts
```

---

## Common Commands

```bash
# Run full pipeline
nextflow run main.nf -profile docker --input samplesheet.csv --outdir results

# Run with test data
nextflow run main.nf -profile test,docker --outdir results

# Lint entire pipeline
nf-core lint

# Validate nextflow_schema.json
nf-core schema lint

# Test a single module
nf-test test modules/local/antifold/tests/
nf-test test modules/local/abodybuilder2/tests/
nf-test test modules/local/biphi_sapiens/tests/
nf-test test modules/local/oasis/tests/

# Test a subworkflow
nf-test test subworkflows/local/redesign/tests/
nf-test test subworkflows/local/humanize/tests/

# Test full workflow
nf-test test workflows/tests/
```

---

## Input Format

Primary input: PDB structure files via a samplesheet CSV passed to `--input`:

```csv
sample,pdb,chain_heavy,chain_light
Ab001,/path/to/Ab001.pdb,H,L
```

`assets/schema_input.json` defines and validates the samplesheet schema. Any new input fields
MUST be added to this schema.

---

## Key Architectural Decisions — Do Not Reverse Without Discussion

- **All four tools are local modules** under `modules/local/` — not nf-core community modules.
  Do not attempt to replace them with community equivalents without explicit instruction.
- **Docker is the only supported profile** at this stage. Do not add Singularity/Conda profiles
  unless explicitly requested.
- **The `meta` map is the cross-module contract.** Every process must pass `meta` through
  unchanged unless a field is explicitly being added for downstream use.
- **`versions` channel is mandatory** in every process. Never omit it, even in draft modules.
- **Resource labels** (`process_low`, `process_medium`, `process_high`) are defined in
  `conf/base.config`. Assign them based on expected compute; do not hardcode CPUs/memory in modules.
- **Test config** (`conf/test.config`) must use minimal input data (single PDB) to allow fast CI runs.

---

## Required Workflow

1. **Read before writing.** Inspect relevant module, subworkflow, and config files before making changes.
2. **Check existing modules before implementing.** Before writing new logic, verify no equivalent
   module or bin script already exists.
3. **Keep changes minimal and task-focused.** Do not refactor surrounding modules unless asked.
4. **Run validation before finishing.** See Command Policy above.
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

- Process names: `SCREAMING_SNAKE_CASE` (e.g. `ANTIFOLD`, `ABODYBUILDER2`).
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

## Testing and Validation Rules

- Every module MUST have an nf-test file at `modules/local/<tool>/tests/main.nf.test`.
- Every subworkflow MUST have an nf-test file at `subworkflows/local/<name>/tests/main.nf.test`.
- Tests use minimal real input data (single PDB/FASTA). Do not use synthetic data that would
  never appear in a real run.
- At minimum, run `nf-core lint` and the targeted `nf-test` tests for any changed module.
- If tests cannot run (e.g. missing Docker or tool license), state what was skipped and why.

### Test Quality Rules

- **Realistic over exhaustive.** Test inputs must reflect real antibody data shapes.
- **No redundancy.** Each test covers a distinct behaviour. Do not duplicate assertions across tests.
- **Assert outputs exist and are non-empty.** Also assert versions.yml is emitted.
- **No trivial coverage padding.** Every test must be justified by a real regression risk.

---

## Change Management

- Keep diffs small and single-purpose.
- Avoid unrelated edits in the same commit.
- Do not modify the cross-group channel contract without coordinating with both groups.

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

## Definition of Done

- [ ] Implementation is complete for the requested scope.
- [ ] `nf-core lint` passes with no errors.
- [ ] Targeted `nf-test` tests pass for changed modules/subworkflows.
- [ ] `versions.yml` is emitted by every new or modified process.
- [ ] Tests and docs updated when externally visible behaviour changes.
- [ ] Final report lists: changed files, commands run, and any known limitations.
