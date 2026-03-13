#!/usr/bin/env python3
"""
Rank OASis candidates by OASis percentile and exclude extreme outliers.

Usage:
    rank_oasis.py <input.xlsx> <output.csv> <min_percentile>
"""

import sys
import pandas as pd


def rank_oasis(input_path, output_path, min_percentile):
    # Read OASis xlsx output
    df = pd.read_excel(input_path)

    # Normalize column names to lowercase for robustness
    df.columns = [c.strip().lower().replace(" ", "_") for c in df.columns]

    # Find the oasis percentile column
    percentile_col = next(
        (c for c in df.columns if "percentile" in c),
        None
    )
    if percentile_col is None:
        raise ValueError(f"No percentile column found. Columns: {list(df.columns)}")

    total = len(df)

    # Filter out extreme outliers below min_percentile
    filtered = df[df[percentile_col] >= min_percentile].copy()
    excluded = total - len(filtered)

    # Sort descending by OASis percentile
    ranked = filtered.sort_values(percentile_col, ascending=False)

    # Save to CSV
    ranked.to_csv(output_path, index=False)

    print(f"Total candidates:    {total}")
    print(f"Retained:            {len(ranked)}")
    print(f"Excluded (< {min_percentile} percentile): {excluded}")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <input.xlsx> <output.csv> <min_percentile>")
        sys.exit(1)

    rank_oasis(sys.argv[1], sys.argv[2], float(sys.argv[3]))
