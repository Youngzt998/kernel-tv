# Handy one-liners. Not a build system -- see README.md.

# Core only (MLIR-free, needs nothing but Z3):
cmake -S . -B build -G Ninja -DZ3_ROOT=/path/to/z3
ninja -C build && ctest --test-dir build --output-on-failure

# With the Triton backend, against an already-built Triton checkout:
TRITON_ROOT=/path/to/triton cmake -S . -B build -G Ninja -DZ3_ROOT=/path/to/z3
ninja -C build triton-tv tv-validator-tests

# Run triton-tv on two (required) mlir files:
build/triton-tv test/TTIR/source/add_kernel_unoptimized.ttir test/TTIR/source/add_kernel.ttir
