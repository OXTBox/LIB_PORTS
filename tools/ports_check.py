#!/usr/bin/env python3
"""LIB_PORTS checker.

  python3 -I tools/ports_check.py live    who listens on each registered port now (Windows' netstat);
                                          two listeners on one port, or a listener not in the registry
                                          among 8765-8799, is a problem (exit 1)
  python3 -I tools/ports_check.py scan    port numbers in our code (accept / DevServer.Start / 127.0.0.1:N /
                                          localhost:N / devtoken_N / *_PORT = N) with no registry row (exit 1)
"""
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
LIB = os.path.dirname(HERE)
PROJECTS = os.path.dirname(LIB)
OURS = range(8765, 8800)
SKIP_DIRS = {".git", "node_modules", "__pycache__", "TO_REMOVE", "LIB_LLMOUT", "LIB_LLMIN", "LIB_BUILD",
             "XTJSON", "corpus", "build"}
EXTS = (".livecodescript", ".py", ".sh", ".bat", ".ps1", ".js")
PATTERNS = [r"accept connections on port\s+(\d{4,5})", r"DevServer\.Start\s+(\d{4,5})",
            r"127\.0\.0\.1:(\d{4,5})", r"localhost:(\d{4,5})", r"devtoken_(\d{4,5})",
            r"\b[A-Z_]*PORT\b\s*=\s*(\d{4,5})", r"kBenchPort\s*=\s*(\d{4,5})", r"Client\((\d{4,5})\)"]
PAT = re.compile("|".join(PATTERNS))


def registry():
    rows = {}
    with open(os.path.join(LIB, "ports.tsv"), encoding="utf-8") as f:
        for line in f:
            if not line.strip() or line.startswith("#"):
                continue
            cols = line.rstrip("\n").split("\t")
            if cols[0].isdigit():
                rows[int(cols[0])] = cols[1] if len(cols) > 1 else ""
    return rows


def listeners():
    """{port: set(pid)} from Windows' netstat (WSL can run netstat.exe)."""
    out = subprocess.run(["netstat.exe", "-ano", "-p", "tcp"], capture_output=True, text=True, timeout=30).stdout
    found = {}
    for line in out.splitlines():
        w = line.split()
        if len(w) >= 5 and w[3] == "LISTENING":
            port = int(w[1].rsplit(":", 1)[1])
            found.setdefault(port, set()).add(w[4])
    return found


def live():
    rows, found, bad = registry(), listeners(), 0
    for port in sorted(rows):
        pids = sorted(found.get(port, ()))
        note = ""
        if len(pids) > 1:
            note, bad = "  <- TWO COPIES: close the older one (RULES.md rule 5)", bad + 1
        print("%5d  %-16s %s%s" % (port, rows[port], ",".join(pids) or "-", note))
    for port in sorted(p for p in found if p in OURS and p not in rows):
        print("%5d  %-16s %s  <- not in the registry" % (port, "?", ",".join(sorted(found[port]))))
        bad += 1
    return bad


def scan():
    rows, bad = registry(), 0
    for root, dirs, files in os.walk(PROJECTS):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in files:
            if not name.endswith(EXTS):
                continue
            path = os.path.join(root, name)
            try:
                with open(path, encoding="utf-8", errors="ignore") as f:
                    for n, line in enumerate(f, 1):
                        for m in PAT.finditer(line):
                            port = int(next(g for g in m.groups() if g))
                            if port not in rows:
                                print("%s:%d  port %d has no registry row" % (os.path.relpath(path, PROJECTS), n, port))
                                bad += 1
            except OSError:
                pass
    print("%d unregistered" % bad)
    return bad


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "live"
    sys.exit(1 if {"live": live, "scan": scan}[what]() else 0)
