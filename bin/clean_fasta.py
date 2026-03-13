#!/usr/bin/env python3
"""
Prepare BioPhi humanized FASTA for ABodyBuilder2.
- Strips header metadata (everything after the first whitespace or comma)
- Renames _VH -> H and _VL -> L
- Pairs H[i] + L[i] positionally and writes one FASTA per candidate

Usage:
    clean_fasta.py <input.fasta> <prefix>

Outputs:
    <prefix>_candidate_0001.fasta
    <prefix>_candidate_0002.fasta
    ...
"""

import sys


def clean_fasta(input_path, prefix):
    h_seqs = []
    l_seqs = []

    with open(input_path) as f:
        header = None
        seq = ""
        for line in f:
            line = line.strip()
            if not line:
                continue
            if line.startswith(">"):
                if header is not None:
                    _store(header, seq, h_seqs, l_seqs)
                # Strip BioPhi annotation: drop everything after first comma or space
                raw = line[1:].split(",")[0].split()[0].strip()
                header = raw
                seq = ""
            else:
                seq += line

        if header is not None:
            _store(header, seq, h_seqs, l_seqs)

    if len(h_seqs) != len(l_seqs):
        raise ValueError(
            f"Mismatched H/L counts: {len(h_seqs)} heavy, {len(l_seqs)} light chains. "
            "Check that FILTER_BIOPHI retains complete VH+VL pairs "
            "(try lowering --sapiens_min_score)."
        )

    if len(h_seqs) == 0:
        raise ValueError(
            "No VH+VL pairs found in input FASTA. "
            "All candidates were filtered out — try lowering --sapiens_min_score."
        )

    for i, (h_seq, l_seq) in enumerate(zip(h_seqs, l_seqs), start=1):
        out_path = f"{prefix}_candidate_{i:04d}.fasta"
        with open(out_path, "w") as out:
            out.write(f">H\n{h_seq}\n")
            out.write(f">L\n{l_seq}\n")


def _store(header, seq, h_seqs, l_seqs):
    if header.endswith("_VH"):
        h_seqs.append(seq)
    elif header.endswith("_VL"):
        l_seqs.append(seq)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.fasta> <prefix>")
        sys.exit(1)

    clean_fasta(sys.argv[1], sys.argv[2])
