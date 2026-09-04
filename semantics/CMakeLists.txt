# tile-smt — MLIR-free core semantic model. Links ONLY Z3 (no MLIR/Triton).
# Z3 is already found by the top-level CMakeLists (z3::libz3 target / Z3_* vars,
# reached through tile_smt_link_z3).

add_library(tile-smt STATIC
  Types.cpp
  AbstractFp.cpp
  Memory.cpp
  Context.cpp
  Equivalence.cpp
)

# The repository root is the include root, so code uses
# #include "semantics/Types.h" while the core lives under semantics/.
target_include_directories(tile-smt PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/..)

# Z3 ONLY — deliberately no Triton objects, no MLIRIR, no MLIRSupport.
tile_smt_link_z3(tile-smt PUBLIC)

if(TILE_SMT_BUILD_TESTS)
  add_subdirectory(test)
endif()
