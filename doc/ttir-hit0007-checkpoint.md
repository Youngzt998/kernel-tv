# HIT-0007 offline checker checkpoint

## November 2 execution update

The older pending-build statements below are historical. The full adapter now
builds against Triton `3277063a6660954e0e59563f28a77677c12a65d7`, matching LLVM
`b010a18d2b648cab83c83967ff26b8fde11acdc6` and persistent Z3 4.15.4. All seven
core/adapter suites pass. CMake enables C as well as C++ because the matching
LLVM package performs C configuration checks.

Real CLI controls establish integer identity/rewrite/inequality, bounded static
loop support and conservative unsupported behavior. The reduced FPA pair
produces a conditional divergence diagnostic with UNKNOWN; an independent
exact-rational RNE evaluator confirms NaN versus negative infinity. The pinned
compiler's `--triton-combine` output matches the archived candidate in generic
MLIR printing. The full original pair exceeds a 60-second external budget and
remains inconclusive. The solver timeout alone does not bound interpretation.

The pre-change baseline incorrectly accepts functions returning different
values because returned values are not modeled. The CLI now rejects non-void
function results and mismatched argument types as UNKNOWN; input/parse failures
also use UNKNOWN rather than the non-equivalence exit. These guards do not add
function-return semantics or prove equivalence for additional inputs.

Frozen controls are in `../eval/pilot/`. Full build, pass replay, independent
reference and baseline-comparison evidence are in
`../../../research/experiments/2026-11-02-pilot/`. No historical GPU claim is
established by these CPU results. Dot-order and NaN-payload limitations remain.

## Motivation and goal

The saved HIT-0007 TTIR pair moves a loop-carried accumulator from
`addf(dot(A, B, 0), acc)` to `dot(A, B, acc)`. A CPU witness shows that an
ordered IEEE-FMA chain can change a NaN into an infinity. Before spending GPU
time, we want the checker to read the saved IR and produce a trustworthy
verdict or an explicit `UNKNOWN` with its missing assumption named.

The project's comparison policy is exact output bits, including NaN payloads
and signed zero. A solver result under Z3 FPA alone is not a final bit-exact
verdict because Z3 does not retain NaN payloads. Also, TTIR's `tt.dot` does not
promise the exact summation order assumed by the current FMA model. This model
therefore tests a stated lowering policy, not the general TTIR contract.

## One path to the goal

1. **Mechanism:** inspect the archived pair and establish the numerical
   accumulator-order witness. Done; see [the mechanism review](ttir-bug-mechanisms.md).
2. **Core:** implement 2-D views/broadcast, signed division/remainder, and an
   ascending-K rounded FMA dot in the MLIR-free core. Done; the five core test
   suites pass, including a 1x2 by 2x1 NaN-versus-infinity regression.
3. **IR adapter:** wire those operations and bounded static `scf.for` unrolling
   into the TTIR interpreter. Code written; compilation and builder tests are
   pending a built Triton/MLIR checkout. The current Mac checkout has none.
4. **Offline end-to-end check:** build `triton-tv` against a pinned Triton
   checkout, run a small IR pair and then the archived pair with
   `--fp-mode=fpa --assume-dot-ordered-fma --timeout-ms=30000`. The flag names
   the ordered-FMA assumption. Capture the parsed IR, compiler revision, command,
   solver output, and a reduced failure if the full pair times out. No GPU is
   required for this step.
5. **Sound verdict:** replay any solver witness using concrete binary32 values
   and verify an output *class* difference such as NaN versus infinity. Add a
   payload-preserving representation before claiming bit-exact equivalence or
   resolving the three payload-only parked cases. Until then, FPA returns
   `UNKNOWN` from the binary even if the solver finds a possible divergence.
6. **Runtime reproduction:** only after the offline check is understood, rerun
   the archived report on one H100 with its pinned Triton and CUDA toolchain.
   Capture inputs, output bits, TTIR/TTGIR, generated code, and the environment.

## Current evidence and resource boundary

On 2026-10-12, the core built with `/usr/bin/c++` on macOS and Z3 5.1.0;
`ctest --test-dir build -R KernelSmt --output-on-failure` passed 5/5 suites.
The temporary Z3 path is `/private/tmp/kernel-tv-z3-venv`; it is a local test
dependency, not a reproducible project installation. The TTIR adapter and CLI
changes have not been compiled because this machine has no built Triton/MLIR
dependency. No GPU run or compiler-pass reproduction is claimed.

The next resource needed is a **CPU build environment with a pinned, built
Triton checkout and its matching LLVM/MLIR**, plus Z3. A GPU is not needed for
that build, the IR pass, or the solver check. The later faithful runtime rerun
needs one NVIDIA H100 (`sm_90a`), matching Triton
`3.8.0+git3277063a`, CUDA 12.9 `ptxas`, and a compatible driver.
