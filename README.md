# kernel-tv

SMT translation validation for tile languages. `triton-tv a.ttir b.ttir` proves
two MLIR functions semantically equivalent with Z3.

Exit codes: `0` EQUIVALENT (UNSAT) · `1` NOT EQUIVALENT (SAT, prints a
counterexample) · `2` UNKNOWN. Today it validates Triton TTIR at realistic
tile sizes.

## Naming

Two names, on purpose. **kernel-tv** is the project: this repository, the
`triton-tv` binary, the CMake project and its build helpers. **kernel-smt** is
the SMT semantic modelling underneath it -- the `libkernel-smt.a` core, the
`kernel_smt` C++ namespace, the `kernel-smt-builder-*` layers, and the planned
`kernel-gpu-smt` and `kernel-accel-smt`. A validator is the tool; the semantic
model is what it is built on, and other things can be built on the same model.

## Layout

```
semantics/   the core: hardware- and language-neutral tensor semantics.
             MLIR-free, links only Z3.
builder/     per-language mapping onto the core.
  mlir/        shared MLIR plumbing + arith/math/scf handlers
  triton/      Triton tt.* handlers
bin/         triton-tv.cpp — the validator
eval/        validation gates and the pass-permutation bug hunt
eq_fuzzing/  equivalence fuzzer driving triton-opt
doc/         design, roadmap, code navigation
```

## Building

The build has two tiers.

**Core** — always built, needs only a C++17 compiler and Z3:

```bash
cmake -S . -B build -G Ninja -DZ3_ROOT=/path/to/z3
ninja -C build
ctest --test-dir build --output-on-failure     # 5 Z3-only tests
```

**Triton backend** — adds `builder/`, `triton-tv` and the validator tests.
Enabled by pointing at a Triton checkout that has **already been built**:

```bash
TRITON_ROOT=/path/to/triton \
  cmake -S . -B build -G Ninja -DZ3_ROOT=/path/to/z3
ninja -C build triton-tv tv-validator-tests
```

With `TRITON_ROOT` unset, CMake says so and builds the core only, so the
repository is usable on a machine with no Triton and no LLVM.

Every language backend follows this shape: one environment variable naming an
already-built checkout of that language's compiler. See
`cmake/PrebuiltTriton.cmake`; `cmake/PrebuiltMLIRCompiler.cmake` holds the parts
that are the same for all of them.

### Backend inputs

| Variable | Required | Default |
| --- | --- | --- |
| `TRITON_ROOT` | to enable the backend | — |
| `TRITON_BUILD_DIR` | no | newest `$TRITON_ROOT/build/cmake.*` |
| `LLVM_SYSPATH` | no | recovered from that build's `CMakeCache.txt` |

A `-D` variable of the same name works too and wins over the environment.

Why a built checkout rather than an installed package: Triton's core is a set
of CMake OBJECT libraries and the project exports no CMake package, so there is
nothing to `find_package()`. What an executable links is the raw object files
out of the build tree, and that is what `cmake/PrebuiltTriton.cmake` harvests —
it reads them off `bin/triton-opt`, whose link set is exactly the one
`triton-tv` needs.

### Portability

Nothing in the build is tied to one machine. `TRITON_ROOT` and `Z3_ROOT` are
supplied per checkout; the build tree, `LLVM_SYSPATH` and the include path are
all read off the Triton build you point at, on the machine you are on. The
harvested object paths are absolute, but they live only in your own build
directory, which is never committed -- and a Triton rebuild re-triggers CMake,
so the harvest cannot go stale behind your back.

`eq_fuzzing/env.sh` is the one script that needs anything else, because it has
to find a torch and the CUDA tools: it derives what it can from `TRITON_ROOT`
and Triton's own cache, and takes `EQF_PY`, `EQF_EXTRA_SITE_PACKAGES` and
`TRITON_CACHE_DIR` for the rest.

### Z3

Z3 **4.8.12 or newer** — `semantics/Context.cpp` uses `z3::sgt` / `z3::sge`,
which older `z3++.h` does not declare. Ubuntu 20.04's `libz3-dev` (4.8.7) is too
old; CMake says so rather than failing at compile time. Two easy ways to get a
newer one:

```bash
# the z3-solver wheel ships z3++.h and libz3.so
python3 -m venv .z3 && .z3/bin/pip install z3-solver
cmake -S . -B build -DZ3_ROOT=$(.z3/bin/python -c \
  'import z3, os; print(os.path.dirname(z3.__file__))')
```

or build Z3 from source and pass `-DZ3_ROOT=/path/to/z3/install`.

## Testing

```bash
ctest --test-dir build -R KernelSmt          # core, Z3-only
ctest --test-dir build -R TestTritonTV     # builder, needs the Triton backend
python eval/run_eval.py all                # validator gates
python eval/permute_passes.py              # pass-permutation bug hunt
```

`eval/` and `eq_fuzzing/` find `triton-opt` through the same `$TRITON_ROOT`;
`$TRITON_OPT` and `$TRITON_TV_BIN` override the search directly.

## Where to start reading

`doc/code-navigation.md` — layer map, reading order, key invariants, and the
three-edit recipe for adding an op. `CLAUDE.md` is the working guide.
