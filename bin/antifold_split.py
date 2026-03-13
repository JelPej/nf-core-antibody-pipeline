#!/usr/bin/env python3
"""
Split AntiFold FASTA output into separate VH/VL entries.
AntiFold joins heavy and light chain sequences with a '/' separator.
This script splits them into individual records with _VH/_VL suffixes.

Usage:
    split_fasta.py <input.fasta> <output.fasta>
"""

import sys
import re


def split_fasta(input_path, output_path):
    records = []

    with open(input_path) as f:
        header = None
        seq = ""
        for line in f:
            line = line.strip()
            if line.startswith(">"):
                if header is not None:
                    records.append((header, seq))
                header = line[1:].strip()
                seq = ""
            else:
                seq += line

        if header is not None:
            records.append((header, seq))

    with open(output_path, "w") as out:
        for header, seq in records:
            if "/" in seq:
                vh, vl = seq.split("/", 1)
                # Insert _VH/_VL after the ID, before the rest of the metadata
                parts = header.split(",", 1)
                id_part = parts[0].strip()
                meta_part = ", " + parts[1].strip() if len(parts) > 1 else ""
                out.write(f">{id_part}_VH{meta_part}\n{vh}\n")
                out.write(f">{id_part}_VL{meta_part}\n{vl}\n")
            else:
                out.write(f">{header}\n{seq}\n")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.fasta> <output.fasta>")
        sys.exit(1)

    split_fasta(sys.argv[1], sys.argv[2])