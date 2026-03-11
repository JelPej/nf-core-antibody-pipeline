# Project Context — nf-core Antibody Optimization Pipeline

## Repo
`JelPej/nf-core-antibody-pipeline`

## My group: Group 2b
Issues to close: #4 (done), #5, #8, #9, #10

## Pipeline flow
```
/data/pdb/6y1l.pdb (input)
  → AntiFold        (Group 2a)  → CDR candidate sequences (.fasta)
  → ABodyBuilder2   (ME, #5)    → predicted PDB per candidate
  → BioPhi Sapiens  (Group 2a)  → humanized sequences (.fasta)
  → OASis           (ME, #8)    → humanness scores (.csv)
```

## Current status
- Issue #4 ✅ — `docker/abodybuilder2/Dockerfile` built and smoke-tested
- Issue #5 — next: `modules/local/abodybuilder2/main.nf`
- Issues #8, #9, #10 — not started

## ABodyBuilder2 CLI (confirmed from container)
```bash
ABodyBuilder2 -f input.fasta -o output.pdb
# FASTA headers must be exactly >H and >L
# Default numbering: imgt (correct for AntiFold compatibility)
```

## Pre-staged resources
- `/data/pdb/6y1l.pdb` — test PDB
- `/data/oasis/OASis_9mers_v1.db` — OASis database (~22 GB)

## Other groups
- Group 2a: AntiFold (#2/#3) + BioPhi Sapiens (#6/#7) — avitanov + TheeOliver
- BioPhi Docker image (#6) by TheeOliver — coordinate image name before OASis tests

## Docs
- @docs/GROUP_2B_PLAN.md — task list with code templates for all 5 issues
- @docs/PIPELINE_PLAN.md — full pipeline reference
- @docs/new-context.md — original project brief
