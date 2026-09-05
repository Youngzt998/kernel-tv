# kernel-smt — MLIR-free core semantic model. Links ONLY Z3 (no MLIR/Triton).
# Z3 is already found by the top-level CMakeLists (z3::libz3 target / Z3_* vars,
# reached through kernel_tv_link_z3).

add_library(kernel-smt STATIC
  Types.cpp
  AbstractFp.cpp
  Memory.cpp
  Context.cpp
  Equivalence.cpp
)

# The repository root is the include root, so code uses
# #include "semantics/Types.h" while the core lives under semantics/.
target_include_directories(kernel-smt PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/..)

# Z3 ONLY — deliberately no Triton objects, no MLIRIR, no MLIRSupport.
kernel_tv_link_z3(kernel-smt PUBLIC)

if(KERNEL_TV_BUILD_TESTS)
  add_subdirectory(test)
endif()
