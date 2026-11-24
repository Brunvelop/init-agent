"""Mechanical check of a plan file against the repository (read-only).

Usage: python3 check_plan.py docs/plans/<slug>.md [--root <repo root, default: cwd>]

Reports, one finding per line (`plan:LINE  KIND  detail`):
  RUTA      a backticked repo path that does not exist (only paths whose top directory exists,
            so files the plan creates elsewhere are not flagged; new files under existing dirs
            are flagged -- ignore those the plan itself creates).
  LINEA     `path:N` or `path:N-M` beyond the end of the file.
  ANCLA     `symbol` ... l.N where the symbol is defined in a cited file more than 5 lines away.
  CMD       an inline backticked `rg ...` / `grep ...` that returns nothing or fails.
  PENDIENTE a line marked "sin verificar": run its check yourself if it is a read.
  NUMERO    a numbered list that skips a number.
Then lists every `path:N` anchor with the text of that line, for a quick eyeball.
Exit 0 = no findings, 1 = findings, 2 = bad usage. Never writes anything.
"""

import os
import re
import shlex
import subprocess
import sys

args = sys.argv[1:]
root = os.getcwd()
if "--root" in args:
    i = args.index("--root")
    root = os.path.abspath(args[i + 1])
    del args[i : i + 2]
if len(args) != 1 or not os.path.isfile(args[0]):
    print(__doc__.strip().splitlines()[2], file=sys.stderr)
    sys.exit(2)

plan_path = args[0]
lines = open(plan_path, encoding="utf8").read().splitlines()
findings = []
anchors = []
_cache = {}


def file_lines(rel):
    if rel not in _cache:
        try:
            _cache[rel] = open(os.path.join(root, rel), encoding="utf8", errors="replace").read().splitlines()
        except OSError:
            _cache[rel] = None
    return _cache[rel]


PATH_RE = re.compile(r"^([\w.\-]+(?:/[\w.\-<>]+)*\.[A-Za-z0-9]{1,6}|[\w.\-]+(?:/[\w.\-]+)+/?)(?::(\d+)(?:-(\d+))?)?$")
cited_files = set()
in_fence = False
for n, line in enumerate(lines, 1):
    if line.lstrip().startswith("```"):
        in_fence = not in_fence
        continue
    if in_fence:
        continue
    for tok in re.findall(r"`([^`\n]+)`", line):
        tok = tok.strip()
        first = tok.split()[0] if tok.split() else ""
        if first in ("rg", "grep") or tok.startswith("git grep "):
            parts = shlex.split(tok) if tok.count('"') % 2 == 0 and tok.count("'") % 2 == 0 else None
            if parts is None or re.search(r"[|;&<>`$]", re.sub(r"'[^']*'|\"[^\"]*\"", "", tok)) or any(
                p.startswith("--pre") for p in parts
            ):
                continue  # not a plain read-only search: do not run it
            try:
                r = subprocess.run(parts, cwd=root, capture_output=True, text=True, timeout=15)
                if r.returncode != 0 or not r.stdout.strip():
                    err = r.stderr.strip().splitlines()[:1]
                    findings.append(f"{plan_path}:{n}  CMD  `{tok}` no devuelve nada" + (f" ({err[0]})" if err else ""))
            except (OSError, subprocess.TimeoutExpired) as e:
                findings.append(f"{plan_path}:{n}  CMD  `{tok}` no se pudo ejecutar ({e})")
            continue
        m = PATH_RE.match(first if " " in tok else tok)
        if not m or "<" in m.group(1) or m.group(1).startswith(("http", "/")):
            continue
        rel = m.group(1).rstrip("/")
        top = rel.split("/")[0]
        if "/" not in rel and not os.path.exists(os.path.join(root, rel)):
            continue  # bare names like `log.jsonl` are often runtime files, not repo paths
        if not os.path.exists(os.path.join(root, top)):
            continue
        if not os.path.exists(os.path.join(root, rel)):
            findings.append(f"{plan_path}:{n}  RUTA  `{rel}` no existe")
            continue
        if os.path.isfile(os.path.join(root, rel)):
            cited_files.add(rel)
        if m.group(2):
            fl = file_lines(rel)
            a, b = int(m.group(2)), int(m.group(3) or m.group(2))
            if fl is not None and b > len(fl):
                findings.append(f"{plan_path}:{n}  LINEA  `{tok}` pero el fichero tiene {len(fl)} líneas")
            elif fl is not None:
                anchors.append(f"{rel}:{a}  {fl[a - 1].strip()[:100]}")

# `symbol` (~l.N) / `symbol` ≈l.N / `symbol` en l.N : compare with the definition in cited files.
DEF = r"(?:function\*?|const|let|var|class|def|type|interface|async function)\s+{0}\b|^\s*(?:export\s+)?(?:async\s+)?{0}\s*\([^)]*\)\s*\{{"
in_fence = False
for n, line in enumerate(lines, 1):
    if line.lstrip().startswith("```"):
        in_fence = not in_fence
        continue
    if in_fence:
        continue
    for m in re.finditer(r"`([A-Za-z_$][\w$]*)(?:\(\))?`[^`\n]{0,40}?(?:~|≈|aprox\.?\s*)?\bl\.\s?(\d+)", line):
        sym, claimed = m.group(1), int(m.group(2))
        if len(sym) < 4:
            continue  # short names (`ids`, `dom`) are usually locals: too noisy
        found = []
        for rel in sorted(cited_files):
            fl = file_lines(rel) or []
            pat = re.compile(DEF.format(re.escape(sym)))
            found += [(rel, i) for i, t in enumerate(fl, 1) if pat.search(t)]
        if found and all(abs(i - claimed) > 5 for _, i in found):
            where = ", ".join(f"{r}:{i}" for r, i in found[:3])
            findings.append(f"{plan_path}:{n}  ANCLA  `{sym}` citado en l.{claimed}, definido en {where}")

for n, line in enumerate(lines, 1):
    if re.search(r"sin verificar", line, re.I):
        findings.append(f"{plan_path}:{n}  PENDIENTE  {line.strip()[:140]}")

prev = None
for n, line in enumerate(lines, 1):
    m = re.match(r"^(\s*)(\d+)\.\s", line)
    if m:
        key = len(m.group(1))
        num = int(m.group(2))
        if prev and prev[0] == key and num not in (prev[1] + 1, 1):
            findings.append(f"{plan_path}:{n}  NUMERO  lista salta de {prev[1]} a {num}")
        prev = (key, num)
    elif line.strip() and not line.startswith((" ", "\t")):
        prev = None

for f in findings:
    print(f)
if anchors:
    print("\n# Anclas path:N (comprueba que la línea es la que el plan describe)")
    for a in anchors:
        print(a)
print(f"\n{len(findings)} hallazgo(s).")
sys.exit(1 if findings else 0)
