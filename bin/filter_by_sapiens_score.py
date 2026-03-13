#!/usr/bin/env python3
"""Filter a FASTA file by Sapiens humanness score from a BioPhi scores CSV.

Expected CSV format (biophi sapiens --mean-score-only):
    id,chain,sapiens_score
    seq1_VH,H,0.92
    seq1_VL,L,0.85
"""

import argparse
import csv
import sys


def parse_fasta(fasta_path):
    sequences = []
    name = None
    seq_lines = []
    with open(fasta_path) as fh:
        for line in fh:
            line = line.rstrip()
            if line.startswith(">"):
                if name is not None:
                    sequences.append((name, "".join(seq_lines)))
                # Use only the first token as the sequence ID (BioPhi appends
                # annotation after the ID, e.g. ">seq1_VH VH Sapiens 1iter ...")
                name = line[1:].split()[0]
                seq_lines = []
            elif line:
                seq_lines.append(line)
    if name is not None:
        sequences.append((name, "".join(seq_lines)))
    return sequences


def parse_scores(csv_path, score_col):
    scores = {}
    with open(csv_path, newline="") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            scores[row["id"]] = float(row[score_col])
    return scores


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("humanized_fasta", help="Input humanized FASTA")
    parser.add_argument("sapiens_scores_csv", help="BioPhi Sapiens scores CSV")
    parser.add_argument("output_fasta", help="Output filtered FASTA")
    parser.add_argument("--min-score", type=float, default=0.8,
                        help="Minimum Sapiens score to retain (default: 0.8)")
    parser.add_argument("--score-col", default="sapiens_score",
                        help="CSV column name for Sapiens score (default: sapiens_score)")
    args = parser.parse_args()

    sequences = parse_fasta(args.humanized_fasta)
    scores = parse_scores(args.sapiens_scores_csv, args.score_col)

    retained = []
    filtered_names = []
    for name, seq in sequences:
        score = scores.get(name)
        if score is not None and score >= args.min_score:
            retained.append((name, seq))
        else:
            filtered_names.append(name)

    total = len(sequences)
    print(
        f"FILTER_BIOPHI: retained {len(retained)}/{total} candidates "
        f"(sapiens_score >= {args.min_score})",
        file=sys.stderr,
    )
    if filtered_names:
        print(f"FILTER_BIOPHI: filtered — {', '.join(filtered_names)}", file=sys.stderr)

    with open(args.output_fasta, "w") as fh:
        for name, seq in retained:
            fh.write(f">{name}\n{seq}\n")


if __name__ == "__main__":
    main()
