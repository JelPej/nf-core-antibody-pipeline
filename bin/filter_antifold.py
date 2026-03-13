#!/usr/bin/env python3
import argparse
import pathlib
import re


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--fasta",      required=True)
    p.add_argument("--out_fasta",  required=True)
    p.add_argument("--min_score",  type=float, required=True)
    args = p.parse_args()

    fasta_in  = pathlib.Path(args.fasta)
    fasta_out = pathlib.Path(args.out_fasta)

    # AntiFold header format (after antifold_split.py):
    # >6y1l_imgt_HL_VH, score=0.2934, global_score=0.2934, ...
    # Match "score=" not preceded by another word character (avoids "global_score=")
    score_re = re.compile(r'(?<![a-z_])score=([0-9.]+)')

    def parse_score(header: str):
        m = score_re.search(header)
        return float(m.group(1)) if m else None

    kept = 0
    total = 0
    with fasta_in.open() as fin, fasta_out.open("w") as fout:
        header = None
        seq = []

        def flush():
            nonlocal kept, total, header, seq
            if header is None or not seq:
                return
            total += 1
            score = parse_score(header)
            if score is not None and score >= args.min_score:
                kept += 1
                fout.write(header)
                fout.writelines(seq)

        for line in fin:
            if line.startswith(">"):
                flush()
                header = line
                seq = []
            else:
                seq.append(line)
        flush()

    print(f"FILTER_ANTIFOLD: kept {kept} / {total} sequences (score >= {args.min_score})")


if __name__ == "__main__":
    main()
