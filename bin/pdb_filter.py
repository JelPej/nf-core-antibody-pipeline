#!/usr/bin/env python3
import argparse
import shutil

parser = argparse.ArgumentParser(description='Filter PDB files based on CDR error thresholds.')
parser.add_argument('--pdb', type=str, required=True, help='Path to the input PDB file.')
parser.add_argument('--fasta', type=str, required=True, help='Path to the input FASTA file.')
parser.add_argument('--success_path', type=str, required=True, help='Path to the output FASTA file in case of success.')
parser.add_argument('--failure_path', type=str, required=True, help='Path to the error log in case of failure.')

args = parser.parse_args()
file_path = args.pdb
fasta_path = args.fasta
success_path = args.success_path
failure_path = args.failure_path

cdr_ranges = {
    'H1': (27, 38),
    'H2': (56, 65),
    'H3': (105, 117),
    'L1': (27, 38),
    'L2': (56, 65),
    'L3': (105, 117)
}

cdr_errors = {cdr: 0.0 for cdr in cdr_ranges}
cdr_counts = {cdr: 0 for cdr in cdr_ranges}

with open(file_path, 'r') as f:
    for line in f:
        if not line.startswith('ATOM') and not line.startswith('HETATM'):
            continue

        atom = line[12:16].strip()
        if atom != 'CA':
            continue

        chain = line[21].strip()
        resnum = int(line[22:26].strip())
        bfactor = float(line[60:66].strip())

        if chain == 'H':
            for cdr in ['H1', 'H2', 'H3']:
                start, end = cdr_ranges[cdr]
                if start <= resnum <= end:
                    cdr_errors[cdr] += bfactor
                    cdr_counts[cdr] += 1
        elif chain == 'L':
            for cdr in ['L1', 'L2', 'L3']:
                start, end = cdr_ranges[cdr]
                if start <= resnum <= end:
                    cdr_errors[cdr] += bfactor
                    cdr_counts[cdr] += 1

mean_errors = {cdr: (cdr_errors[cdr]/cdr_counts[cdr] if cdr_counts[cdr] > 0 else 0.0)
               for cdr in cdr_ranges}

thresholds = {
    'H1': 1.0, 'H2': 1.0, 'H3': 1.5,
    'L1': 0.9, 'L2': 0.9, 'L3': 1.0
}


has_exceeded_threshold = False
for cdr in cdr_ranges:
    error = mean_errors[cdr]
    threshold = thresholds[cdr]
    if error > threshold:
        has_exceeded_threshold = True
        break
    
    if has_exceeded_threshold:
        with open(success_path, 'w') as f:
            f.write(f"File {file_path} not accepted. Prediction errors for atoms are too high.\n")
            f.write("Thresholds:")
            f.write(f"{'H1':<6}{'H2':<6}{'H3':<6}")
            f.write(f"{thresholds['H1']:<6.2f}{thresholds['H2']:<6.2f}{thresholds['H3']:<6.2f}\n")
            f.write(f"{'L1':<6}{'L2':<6}{'L3':<6}")
            f.write(f"{thresholds['L1']:<6.2f}{thresholds['L2']:<6.2f}{thresholds['L3']:<6.2f}")
            f.write("\nErrors:")
            f.write(f"{'H1':<6}{'H2':<6}{'H3':<6}")
            f.write(f"{mean_errors['H1']:<6.2f}{mean_errors['H2']:<6.2f}{mean_errors['H3']:<6.2f}\n")
            f.write(f"{'L1':<6}{'L2':<6}{'L3':<6}")
            f.write(f"{mean_errors['L1']:<6.2f}{mean_errors['L2']:<6.2f}{mean_errors['L3']:<6.2f}")
    else:
        shutil.copy(fasta_path, success_path)