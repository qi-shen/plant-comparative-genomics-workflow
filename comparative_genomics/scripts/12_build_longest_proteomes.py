#!/usr/bin/env python3
"""
按物种规则从 01_proteomes/*.fa 提取每基因最长蛋白转录本。
输出到 comparative_genomics/01_proteomes_longest/
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Callable, Dict, Tuple


BASE = Path("${PROJECT_ROOT}/comparative_genomics")
IN_DIR = BASE / "01_proteomes"
OUT_DIR = BASE / "01_proteomes_longest"
OUT_DIR.mkdir(parents=True, exist_ok=True)


def root_identity(x: str) -> str:
    return x


def root_by_regex(pattern: str) -> Callable[[str], str]:
    rgx = re.compile(pattern)

    def _f(x: str) -> str:
        m = rgx.match(x)
        return m.group(1) if m else x

    return _f


# 物种专用规则（基于当前ID格式抽样）
RULES: Dict[str, Callable[[str], str]] = {
    # clearly transcript suffix
    "O01": root_by_regex(r"^(O01_transcript:[^.]+)\.\d+$"),
    "C05": root_by_regex(r"^(C05_.+)\.\d+$"),
    "C11": root_by_regex(r"^(C11_[^.]+)\.\d+$"),
    "O02": root_by_regex(r"^(O02_.+)\.t\d+$"),
    "C03": root_by_regex(r"^(C03_TC\d+G\d+)T\d+$"),
    "C09": root_by_regex(r"^(C09_.+)\.t\d+$"),
    "C07": root_by_regex(r"^(C07_.+)\.m\d+$"),
    "C08": root_identity,  # 新版HR基因组无转录本后缀，35926基因=35926蛋白
    "C04": root_by_regex(r"^(C04_.+)-mRNA-\d+$"),
    "C01": root_by_regex(r"^(C01_.+)\.p\d+$"),
    # 这两个按样本看像“evm.model.Chrxx.<gene序号>”，不是转录本后缀，必须保留原ID
    "C02": root_identity,
    "C06": root_identity,
    # 以下多数已是一基因一条，保留原ID最稳妥
    "T01": root_identity,
    "T02": root_identity,
    "C10": root_identity,
}


def read_fasta(path: Path) -> Dict[str, str]:
    seqs: Dict[str, str] = {}
    cur = None
    buf = []
    with path.open(errors="ignore") as f:
        for line in f:
            if line.startswith(">"):
                if cur is not None:
                    seqs[cur] = "".join(buf)
                cur = line[1:].strip().split()[0]
                buf = []
            else:
                buf.append(line.strip())
        if cur is not None:
            seqs[cur] = "".join(buf)
    return seqs


def write_fasta(path: Path, seqs: Dict[str, str], keep_ids: set[str]) -> int:
    n = 0
    with path.open("w") as o:
        for tid, seq in seqs.items():
            if tid not in keep_ids:
                continue
            o.write(f">{tid}\n")
            for i in range(0, len(seq), 80):
                o.write(seq[i : i + 80] + "\n")
            n += 1
    return n


def build_for_species(sp: str, fa: Path) -> Tuple[int, int, float]:
    seqs = read_fasta(fa)
    rule = RULES.get(sp, root_identity)

    best: Dict[str, Tuple[str, int]] = {}
    for tid, seq in seqs.items():
        gid = rule(tid)
        ln = len(seq)
        if gid not in best or ln > best[gid][1] or (ln == best[gid][1] and tid < best[gid][0]):
            best[gid] = (tid, ln)

    keep = {v[0] for v in best.values()}
    out_fa = OUT_DIR / f"{sp}.fa"
    n_out = write_fasta(out_fa, seqs, keep)
    n_in = len(seqs)
    ratio = n_in / max(1, n_out)
    return n_in, n_out, ratio


def main() -> None:
    rows = []
    for fa in sorted(IN_DIR.glob("*.fa")):
        sp = fa.stem
        n_in, n_out, ratio = build_for_species(sp, fa)
        rows.append((sp, n_in, n_out, ratio))
        print(f"{sp}: {n_in} -> {n_out} (avg_isoform_est={ratio:.2f})")

    stats = OUT_DIR / "longest_stats.tsv"
    with stats.open("w") as o:
        o.write("Species\tInputProteins\tLongestProteins\tAvgIsoformEstimate\n")
        for sp, n_in, n_out, ratio in rows:
            o.write(f"{sp}\t{n_in}\t{n_out}\t{ratio:.4f}\n")

    print(f"\n输出目录: {OUT_DIR}")
    print(f"统计文件: {stats}")


if __name__ == "__main__":
    main()

