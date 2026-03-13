#!/usr/bin/env python3
import argparse
import csv
import pathlib


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--fasta", required=True)
    p.add_argument("--csv", required=True)
    p.add_argument("--out_fasta", required=True)
    p.add_argument("--min_score", type=float, required=True)
    args = p.parse_args()

    fasta_in = pathlib.Path(args.fasta)
    csv_in = pathlib.Path(args.csv)
    fasta_out = pathlib.Path(args.out_fasta)

    # 1) Collect allowed sequence IDs from CSV based on 'score' column
    keep_ids = set()
    with csv_in.open() as fin:
        reader = csv.DictReader(fin)
        for row in reader:
            sid = row.get("seq_id") or row.get("id") or row.get("name")
            if not sid:
                continue
            s = row.get("score")
            if s is None:
                continue
            if float(s) > args.min_score:
                keep_ids.add(sid)

    # 2) Filter FASTA entries whose ID is in keep_ids
    def header_id(h: str) -> str:
        return h[1:].split()[0].split(",")[0]

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
            if header_id(header) in keep_ids:
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

    print(f"FILTER_ANTIFOLD: kept {kept} / {total} sequences (score > {args.min_score})")


if __name__ == "__main__":
    main()
