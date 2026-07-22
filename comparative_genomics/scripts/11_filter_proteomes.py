#!/usr/bin/env python3
"""11 — Filter proteomes (min length, clean stop marks). Config-aware paths."""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))
from species import project_root, load_species  # noqa: E402


def parse_fasta(filename: Path) -> dict[str, str]:
    sequences: dict[str, str] = {}
    current_id = None
    current_seq: list[str] = []
    with filename.open() as f:
        for line in f:
            line = line.strip()
            if line.startswith(">"):
                if current_id:
                    sequences[current_id] = "".join(current_seq)
                current_id = line[1:].split()[0]
                current_seq = []
            else:
                current_seq.append(line)
        if current_id:
            sequences[current_id] = "".join(current_seq)
    return sequences


def clean_sequence(seq: str) -> str:
    seq = seq.upper().replace("*", "").replace(".", "")
    return re.sub(r"\s+", "", seq)


def filter_proteome(input_file: Path, output_file: Path, min_length: int = 50) -> dict:
    sequences = parse_fasta(input_file)
    stats = {"total": len(sequences), "too_short": 0, "invalid_char": 0, "kept": 0}
    valid_aa = set("ACDEFGHIKLMNPQRSTVWXY")
    filtered = {}
    for seq_id, seq in sequences.items():
        seq = clean_sequence(seq)
        if len(seq) < min_length:
            stats["too_short"] += 1
            continue
        if set(seq) - valid_aa:
            stats["invalid_char"] += 1
            continue
        filtered[seq_id] = seq
    stats["kept"] = len(filtered)
    output_file.parent.mkdir(parents=True, exist_ok=True)
    with output_file.open("w") as f:
        for seq_id, seq in filtered.items():
            f.write(f">{seq_id}\n")
            for i in range(0, len(seq), 80):
                f.write(seq[i : i + 80] + "\n")
    return stats


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--min-length", type=int, default=50)
    ap.add_argument(
        "--indir",
        default=None,
        help="Input proteome dir (default: COMPARATIVE_DIR/01_proteomes)",
    )
    ap.add_argument(
        "--outdir",
        default=None,
        help="Output dir (default: <indir>/filtered)",
    )
    args = ap.parse_args()

    root = project_root()
    comp = Path(os.environ.get("COMPARATIVE_DIR", root / "comparative_genomics"))
    indir = Path(args.indir) if args.indir else comp / "01_proteomes"
    outdir = Path(args.outdir) if args.outdir else indir / "filtered"
    outdir.mkdir(parents=True, exist_ok=True)

    ids = [r["id"] for r in load_species()]
    print(f"Filter proteomes -> {outdir}")
    for sid in ids:
        src = indir / f"{sid}.fa"
        if not src.exists():
            print(f"  SKIP missing {src}")
            continue
        dst = outdir / f"{sid}.fa"
        stats = filter_proteome(src, dst, args.min_length)
        print(f"  {sid}: {stats['kept']}/{stats['total']} kept")


if __name__ == "__main__":
    main()
