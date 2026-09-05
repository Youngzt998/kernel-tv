# Machine-specific runtime glue for eq_fuzzing on this box.
# Source it, then run: "$EQF_PY" -m eq_fuzzing.runner ...
#
# Why this exists: this repo needs a working `import triton` plus torch, and the
# Triton checkout's own venv usually has triton but not torch. We borrow torch
# from the fbsource `beta` venv (via PYTHONPATH, with the Triton checkout's
# python/ dir FIRST so `import triton` resolves to that checkout) and point
# Triton at the shared CUDA tools under ~/.triton. Runtime-only glue; the
# eq_fuzzing code itself only uses the public Triton API + the triton-opt binary.

# The built Triton checkout -- the same $TRITON_ROOT the CMake build uses.
: "${TRITON_ROOT:?set TRITON_ROOT to a built Triton checkout before sourcing this}"
# This repository.
KERNEL_SMT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# External deps (outside both trees, so necessarily absolute on this box).
BETA_SP=/data/users/youngzt/fbsource/third-party/triton/beta/triton/.venv/lib/python3.12/site-packages

export EQF_PY="$TRITON_ROOT/.venv/bin/python"
# $TRITON_ROOT/python -> triton (that checkout, wins over beta's .pth);
# $KERNEL_SMT_ROOT      -> makes the `eq_fuzzing` package importable;
# $BETA_SP            -> torch + numpy.
export PYTHONPATH="$TRITON_ROOT/python:$KERNEL_SMT_ROOT:$BETA_SP"

# CUDA toolchain (same archives the beta env uses)
export TRITON_PTXAS_PATH="/home/youngzt/.triton/nvidia/nvcc/cuda_nvcc-linux-x86_64-12.9.86-archive/bin/ptxas"
export TRITON_CUOBJDUMP_PATH="/home/youngzt/.triton/nvidia/cuobjdump/cuda_cuobjdump-linux-x86_64-13.1.80-archive/bin/cuobjdump"
export TRITON_NVDISASM_PATH="/home/youngzt/.triton/nvidia/nvdisasm/cuda_nvdisasm-linux-x86_64-13.1.80-archive/bin/nvdisasm"
export TRITON_CUDACRT_PATH="/home/youngzt/.triton/nvidia/nvcc/cuda_crt-linux-x86_64-13.1.80-archive/include"
export TRITON_CUDART_PATH="/home/youngzt/.triton/nvidia/cudart/cuda_cudart-linux-x86_64-13.1.80-archive/include"
