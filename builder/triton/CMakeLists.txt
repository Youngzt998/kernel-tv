# kernel-tv-builder-triton — Triton-specific builder layer. Handlers for tt.*
# ops built on top of builder/mlir (which provides State / Env / dtypeOf and the
# arith/math/scf handlers the dispatch also calls). The Triton dialect itself
# comes in transitively through builder-mlir's kernel-tv::triton.

add_library(kernel-tv-builder-triton STATIC
  TritonOps.cpp
)

target_include_directories(kernel-tv-builder-triton PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}/../..)

target_link_libraries(kernel-tv-builder-triton PUBLIC
  kernel-tv-builder-mlir   # core + MLIR + State/Env/dtypeOf + arith/math handlers
)
