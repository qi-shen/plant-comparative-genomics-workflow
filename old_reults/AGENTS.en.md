# Coding & plotting conventions

**Language:** [English](AGENTS.en.md) | [中文](AGENTS.zh-CN.md)

- Prefer conda environments; do not rely on system R/Python by default.
- Prefer R for plotting.
- No background grids; no top or right axis spines.

Color palette:

```python
color_palette = {
    1: "#00BFAE",
    2: "#1F77B4",
    3: "#9467BD",
    4: "#FF7F0E",
    5: "#D62728",
    6: "#F08080",
    7: "#8B4513",
    8: "#228B22",
    9: "#90EE90",
    10: "#00008B",
    11: "#DDA0DD",
    12: "#006400",
    13: "#8B0000",
    14: "#ADD8E6",
}
```

Prefer multi-core parallelism, heavy server utilization, background jobs, and periodic progress logs.

Privacy: public docs/commits use sample IDs (T/C/O) only — no real Chinese or Latin species names.
