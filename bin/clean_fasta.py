#!/usr/bin/env python3
"""
Clean BioPhi humanized FASTA output for ABodyBuilder2.
- Strips header metadata (everything after the first comma)
- Renames _VH -> H and _VL -> L
- Outputs a single FASTA file

Usage:
    clean_fasta.py <input.fasta> <output.fasta>
"""

import sys


def clean_fasta(input_path, output_path):
    records = []

    with open(input_path) as f:
        header = None
        seq = ""
        for line in f:
            line = line.strip()
            if line.startswith(">"):
                if header is not None:
                    records.append((header, seq))
                # Clean header: strip everything after first comma
                header = line[1:].split(",")[0].strip()
                seq = ""
            else:
                seq += line

        if header is not None:
            records.append((header, seq))

    with open(output_path, "w") as out:
        for header, seq in records:
            if header.endswith("_VH"):
                out.write(f">H\n{seq}\n\n")
            elif header.endswith("_VL"):
                out.write(f">L\n{seq}\n\n")
            else:
                out.write(f">{header}\n{seq}\n\n")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.fasta> <output.fasta>")
        sys.exit(1)

    clean_fasta(sys.argv[1], sys.argv[2])