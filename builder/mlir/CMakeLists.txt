# tile-smt-builder-mlir — shared builder layer for all MLIR-based languages.
# Reads MLIR IR (types, ops) and drives the MLIR-free core (tile-smt) through
# the Context builder API. Holds: dtypeOf, Env (mlir::Value -> Value), the
# MemId-mapping + block-walk driver (State), and the standard-dialect handlers
# (arith / math / scf). Links the core + the language backend.
#
# NOTE: despite the name this layer is not language-neutral yet — DTypeOf, Env
# and State all reach for triton/Dialect/Triton/IR/Types.h (tt.ptr), and State's
# interpretOp dispatch calls the tt.* handlers in builder/triton. Making it
# neutral is a prerequisite for a second language backend; see CLAUDE.md §2.
#
# Compiled WITHOUT -fno-exceptions/-fno-rtti so std::throw (Env::lookup) and the
# z3++ exceptions work normally.

add_library(tile-smt-builder-mlir STATIC
  DTypeOf.cpp
  Env.cpp
  State.cpp
  ArithOps.cpp
)

# The repository root is the include root: code uses
# #include "builder/mlir/State.h", "semantics/Context.h", etc.
target_include_directories(tile-smt-builder-mlir PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}/../..)

target_link_libraries(tile-smt-builder-mlir PUBLIC
  tile-smt          # MLIR-free core (Context / Memory / Value / AbstractFp)
  tile-smt::triton  # Triton objects + MLIR (see cmake/PrebuiltTriton.cmake)
)
