# Plain C++ unit tests for the translation validator's builder layer.
#
# These use the tiny header-only harness in SimpleTest.h instead of GoogleTest,
# so they build with only the C++ standard library (no FetchContent, no
# network). Each test is a standalone executable; running it runs all of its
# TEST() cases and returns non-zero if any check fails. Tests are registered
# with CTest and grouped under the `tv-validator-tests` build target.

if(NOT TARGET tv-validator-tests)
  add_custom_target(tv-validator-tests)
endif()

# add_tv_test(NAME <name> SRCS <sources...> LIBS <libs...>)
function(add_tv_test)
  cmake_parse_arguments(ARG "" "NAME" "SRCS;LIBS" ${ARGN})

  add_executable(${ARG_NAME} ${ARG_SRCS})

  # current dir -> "SimpleTest.h"; repo root -> "semantics/Memory.h" etc.
  target_include_directories(${ARG_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/../..
  )

  target_link_libraries(${ARG_NAME} PRIVATE ${ARG_LIBS})
  kernel_tv_link_z3(${ARG_NAME} PRIVATE)

  add_test(NAME ${ARG_NAME} COMMAND ${ARG_NAME})
  add_dependencies(tv-validator-tests ${ARG_NAME})
endfunction()

# The Memory unit test moved to the Z3-only core suite
# (semantics/test/MemoryTest.cpp); Memory is now MLIR-free (DType-based) and
# lives in the kernel-smt core, so the test no longer needs MLIR.

# EnvTest exercises the MLIR builder-mlir layer (makeSymbolicValue / dtypeOf /
# Env). It does not use State, so linking builder-mlir is enough (the tt.*
# handlers, referenced only by State's dispatch, are never pulled in).
add_tv_test(
  NAME TestTritonTVEnv
  SRCS EnvTest.cpp
  LIBS kernel-smt-builder-mlir
)

# StateTest drives the full walk (State::interpretOp references the tt.*
# handlers), so it links builder-triton (which pulls in builder-mlir + core).
add_tv_test(
  NAME TestTritonTVState
  SRCS StateTest.cpp
  LIBS kernel-smt-builder-triton
)

# The Abstract-FP unit test moved to the Z3-only core suite
# (semantics/test/AbstractFpTest.cpp); it no longer needs MLIR.
