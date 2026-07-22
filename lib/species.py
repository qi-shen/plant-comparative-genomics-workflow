#!/usr/bin/env python3
"""Load config/species.csv for Python scripts."""
from __future__ import annotations

import csv
import os
from pathlib import Path


def project_root() -> Path:
    env = os.environ.get("PROJECT_ROOT")
    if env:
        return Path(env).resolve()
    here = Path(__file__).resolve().parent
    return here.parent


def species_csv() -> Path:
    env = os.environ.get("SPECIES_CSV")
    if env:
        return Path(env)
    return project_root() / "config" / "species.csv"


def load_species(path: Path | None = None) -> list[dict[str, str]]:
    p = path or species_csv()
    with p.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def by_id(sid: str, path: Path | None = None) -> dict[str, str]:
    for row in load_species(path):
        if row.get("id") == sid or row.get("prefix") == sid:
            return row
    raise KeyError(f"species id not found: {sid}")


def resolve(path: str, root: Path | None = None) -> Path:
    root = root or project_root()
    p = Path(path)
    return p if p.is_absolute() else (root / p)
