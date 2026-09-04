"""
Shared glue for the tv evaluation suite.

This module knows two things:
  1. Where the built `triton-tv` / `triton-opt` binaries live.
  2. How to run one validation and read its result.

The `triton-tv` binary contract (see bin/triton-tv.cpp):
  - exit code 0  -> prints "EQUIVALENT"
  - exit code 1  -> prints "NOT EQUIVALENT ..."
  - exit code 2  -> prints "UNKNOWN ..."
  - it also prints timing lines:  "Interpretation: <x> s"  and  "Solver: <x> s"
We read the verdict from the exit code and the timings from stdout.
"""

import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

# This repository's root: <repo>/eval/common.py
REPO_ROOT = Path(__file__).resolve().parents[1]

# Verdict names, keyed by the binary's exit code.
VERDICT_BY_CODE = {0: "EQUIV", 1: "NEQ", 2: "UNKNOWN"}


@dataclass
class Result:
    """Outcome of one `triton-tv src tgt` run."""
    verdict: str        # EQUIV | NEQ | UNKNOWN | ERROR | TIMEOUT
    exit_code: int      # raw process exit code (-1 on timeout/error)
    interp_s: float     # seconds spent interpreting both programs (nan if absent)
    solver_s: float     # seconds spent in Z3 (nan if absent)
    stdout: str


def triton_root():
    """The built Triton checkout this repo's Triton backend is pointed at.

    Same $TRITON_ROOT the CMake build uses (cmake/PrebuiltTriton.cmake), so
    there is one variable to set, not two. Returns None if it is unset.
    """
    root = os.getenv("TRITON_ROOT")
    return Path(root) if root else None


def _triton_build_dir():
    """Triton's CMake build directory, the one its own build uses."""
    root = triton_root()
    if root is None:
        return None
    # Prefer the project's own helper so we match the build exactly.
    sys.path.insert(0, str(root / "python"))
    try:
        import build_helpers  # type: ignore
        return Path(build_helpers.get_cmake_dir())
    except Exception:
        hits = sorted(root.glob("build/cmake.*"))
        return hits[-1] if hits else None


def _from_env(env_var):
    override = os.getenv(env_var)
    if not override:
        return None
    p = Path(override)
    if p.is_file():
        return p
    raise FileNotFoundError(f"{env_var}={override} is not a file")


def find_triton_tv():
    """Locate `triton-tv`, which this repository builds itself."""
    hit = _from_env("TRITON_TV_BIN")
    if hit:
        return hit

    for build in sorted(REPO_ROOT.glob("build*")):
        candidate = build / "triton-tv"
        if candidate.is_file():
            return candidate

    raise FileNotFoundError(
        "could not find 'triton-tv'. Build it first:\n"
        "    TRITON_ROOT=<a built Triton checkout> \\\n"
        "        cmake -S . -B build -G Ninja && ninja -C build triton-tv\n"
        "or point $TRITON_TV_BIN at the binary.")


def find_triton_opt():
    """Locate `triton-opt`, which belongs to the Triton checkout."""
    hit = _from_env("TRITON_OPT_BIN")
    if hit:
        return hit

    bd = _triton_build_dir()
    if bd is not None and (bd / "bin" / "triton-opt").is_file():
        return bd / "bin" / "triton-opt"

    raise FileNotFoundError(
        "could not find 'triton-opt'. Set $TRITON_ROOT to a built Triton "
        "checkout (the same one the CMake build uses), or point "
        "$TRITON_OPT_BIN at the binary.")


def _parse_time(label, text):
    m = re.search(rf"{label}:\s*([0-9.eE+-]+)\s*s", text)
    return float(m.group(1)) if m else float("nan")


def run_validation(binary, src, tgt, timeout=120):
    """Run `triton-tv src tgt` and return a Result."""
    try:
        proc = subprocess.run(
            [str(binary), str(src), str(tgt)],
            capture_output=True, text=True, timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        return Result("TIMEOUT", -1, float("nan"), float("nan"),
                      f"timed out after {timeout}s")

    out = proc.stdout + proc.stderr
    verdict = VERDICT_BY_CODE.get(proc.returncode, "ERROR")
    return Result(
        verdict=verdict,
        exit_code=proc.returncode,
        interp_s=_parse_time("Interpretation", out),
        solver_s=_parse_time("Solver", out),
        stdout=out,
    )
