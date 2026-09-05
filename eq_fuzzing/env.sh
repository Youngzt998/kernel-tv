# Runtime glue for eq_fuzzing: interpreter, PYTHONPATH and CUDA tool paths.
# Source it, then run: "$EQF_PY" -m eq_fuzzing.runner ...
#
# Nothing here is specific to one machine. Everything is either derived from
# $TRITON_ROOT or overridable, so a new box sets variables instead of editing
# this file. What it has to solve: eq_fuzzing needs `import triton` from the
# checkout we validate against AND a torch, and the Triton venv often has the
# first without the second -- so a torch from elsewhere can be layered in.
#
#   TRITON_ROOT            required. The built Triton checkout.
#   EQF_PY                 optional. Interpreter. Default: $TRITON_ROOT/.venv/bin/python.
#   EQF_EXTRA_SITE_PACKAGES optional. Site-packages to borrow torch/numpy from.
#   TRITON_CACHE_DIR       optional. Where the CUDA archives live. Default: ~/.triton.

: "${TRITON_ROOT:?set TRITON_ROOT to a built Triton checkout before sourcing this}"
KERNEL_TV_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export EQF_PY="${EQF_PY:-$TRITON_ROOT/.venv/bin/python}"

# $TRITON_ROOT/python -> triton from that checkout, ahead of anything a
# borrowed site-packages would resolve; then this repo, so `eq_fuzzing` imports.
PYTHONPATH="$TRITON_ROOT/python:$KERNEL_TV_ROOT"
[ -n "$EQF_EXTRA_SITE_PACKAGES" ] && PYTHONPATH="$PYTHONPATH:$EQF_EXTRA_SITE_PACKAGES"
export PYTHONPATH

# CUDA toolchain. Triton downloads these archives into its cache; find whatever
# version is there rather than pinning one. Each is overridable, and an
# unresolved one is left unset so Triton falls back to its own lookup.
_triton_cache="${TRITON_CACHE_DIR:-$HOME/.triton}"
_eqf_find() {  # _eqf_find <var> <glob under the nvidia cache>
  local var="$1" glob="$2" hit
  [ -n "${!var}" ] && return 0
  hit=$(ls -d $_triton_cache/nvidia/$glob 2>/dev/null | sort -V | tail -1)
  [ -n "$hit" ] && export "$var=$hit"
}
_eqf_find TRITON_PTXAS_PATH      'nvcc/cuda_nvcc-*/bin/ptxas'
_eqf_find TRITON_CUOBJDUMP_PATH  'cuobjdump/cuda_cuobjdump-*/bin/cuobjdump'
_eqf_find TRITON_NVDISASM_PATH   'nvdisasm/cuda_nvdisasm-*/bin/nvdisasm'
_eqf_find TRITON_CUDACRT_PATH    'nvcc/cuda_crt-*/include'
_eqf_find TRITON_CUDART_PATH     'cudart/cuda_cudart-*/include'
unset -f _eqf_find
