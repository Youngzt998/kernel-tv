# kernel-smt — SMT translation validation for tile languages.
#
# This is the top-level project. It builds in two tiers:
#
#   core     semantics/ -> libkernel-smt.a and its unit tests. MLIR-free, links
#            only Z3. Always built; needs nothing but a C++17 compiler and Z3.
#
#   backend  builder/ + bin/triton-tv + test/validator. One per tile language,
#            enabled by pointing at that language's *already built* checkout:
#            TRITON_ROOT today, TILELANG_ROOT once that builder exists.
#            See cmake/PrebuiltTriton.cmake and README.md.
#
# With no backend configured the core still builds and tests clean, so the
# repository is usable on a machine that has no Triton and no LLVM.

cmake_minimum_required(VERSION 3.20)
project(kernel-smt CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
enable_testing()

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# ---------------------------------------------------------------------------
# Z3
#
# 4.8.12 is the floor because z3++.h gained z3::sgt / z3::sge there and
# semantics/Context.cpp uses both. Older headers (Ubuntu 20.04 ships 4.8.7)
# fail to compile with a confusing "'sgt' is not a member of 'z3'".
# ---------------------------------------------------------------------------
set(Z3_ROOT "" CACHE PATH "Path to custom Z3 installation (searched first)")

# Try custom location first, then fall back to system
if(Z3_ROOT)
  find_package(Z3 4.8.12 CONFIG QUIET PATHS "${Z3_ROOT}" NO_DEFAULT_PATH)
  if(NOT Z3_FOUND)
    find_path(Z3_INCLUDE_DIRS NAMES z3++.h PATHS "${Z3_ROOT}/include" NO_DEFAULT_PATH)
    find_library(Z3_LIBRARIES NAMES z3 PATHS "${Z3_ROOT}/lib" NO_DEFAULT_PATH)
  endif()
endif()

# Fall back to system
if(NOT Z3_FOUND AND NOT (Z3_INCLUDE_DIRS AND Z3_LIBRARIES))
  find_package(Z3 4.8.12 CONFIG QUIET)
  if(NOT Z3_FOUND)
    find_path(Z3_INCLUDE_DIRS NAMES z3++.h)
    find_library(Z3_LIBRARIES NAMES z3)
  endif()
endif()

if(NOT Z3_FOUND AND NOT (Z3_INCLUDE_DIRS AND Z3_LIBRARIES))
  message(FATAL_ERROR
    "Z3 not found. Install libz3-dev or set -DZ3_ROOT=/path/to/z3.")
endif()

# find_path/find_library know nothing about versions, so a system Z3 that is
# too old gets past the block above. What we actually need is z3::sgt / z3::sge
# (semantics/Context.cpp), added in Z3 4.8.12 -- so test the header for them
# directly. That works for any layout, including the z3-solver wheel, which
# ships z3++.h and libz3.so but no z3_version.h to read a version out of.
if(NOT Z3_FOUND)
  find_file(Z3_CXX_HEADER z3++.h PATHS ${Z3_INCLUDE_DIRS} NO_DEFAULT_PATH)
  file(STRINGS "${Z3_CXX_HEADER}" _z3_sgt REGEX "expr[ \t]+sgt[ \t]*\\(")

  set(_z3_version_note "")
  find_file(Z3_VERSION_HEADER z3_version.h PATHS ${Z3_INCLUDE_DIRS} NO_DEFAULT_PATH)
  if(Z3_VERSION_HEADER)
    file(STRINGS "${Z3_VERSION_HEADER}" _z3_full REGEX "Z3_FULL_VERSION")
    string(REGEX MATCH "\"([0-9]+\\.[0-9]+\\.[0-9]+)" _m "${_z3_full}")
    set(Z3_VERSION "${CMAKE_MATCH_1}")
    set(_z3_version_note " (${Z3_VERSION})")
  endif()

  if(NOT _z3_sgt)
    message(FATAL_ERROR
      "The Z3 at ${Z3_INCLUDE_DIRS}${_z3_version_note} is too old: its z3++.h "
      "has no z3::sgt / z3::sge, which semantics/Context.cpp uses. Those "
      "arrived in Z3 4.8.12. Install a newer Z3 and pass "
      "-DZ3_ROOT=/path/to/z3 -- see README.md for two ways to get one.")
  endif()
  message(STATUS "kernel-smt: Z3${_z3_version_note} at ${Z3_LIBRARIES}")
endif()

function(kernel_smt_link_z3 target scope)
  if(TARGET z3::libz3)
    target_link_libraries(${target} ${scope} z3::libz3)
  else()
    target_include_directories(${target} ${scope} ${Z3_INCLUDE_DIRS})
    target_link_libraries(${target} ${scope} ${Z3_LIBRARIES})
  endif()
endfunction()

option(KERNEL_SMT_BUILD_TESTS "Build kernel-smt unit tests" ON)

# ---------------------------------------------------------------------------
# Core: MLIR-free semantic model. Links ONLY z3.
# ---------------------------------------------------------------------------
add_subdirectory(semantics)

# ---------------------------------------------------------------------------
# Backends
# ---------------------------------------------------------------------------
include(PrebuiltTriton)

if(NOT TARGET kernel-smt::triton)
  message(STATUS
    "kernel-smt: core only (kernel-smt + kernel-smt-tests). Set "
    "TRITON_ROOT=<a built Triton checkout> to build the Triton backend "
    "and triton-tv. See README.md.")
  return()
endif()

# Builder layer (per-language modeling onto the core):
#   kernel-smt-builder-mlir    — shared MLIR tools + arith/math/scf handlers
#   kernel-smt-builder-triton  — Triton tt.* handlers (links builder-mlir)
# Both compile WITHOUT -fno-exceptions/-fno-rtti so std::throw (Env::lookup) and
# z3++ exceptions work.
add_subdirectory(builder/mlir)
add_subdirectory(builder/triton)

# ---------------------------------------------------------------------------
# triton-tv binary
# ---------------------------------------------------------------------------
add_executable(triton-tv bin/triton-tv.cpp)
# This TU instantiates llvm::cl templates, so it has to agree with how LLVM was
# built about RTTI/exceptions (see cmake/PrebuiltTriton.cmake).
target_compile_options(triton-tv PRIVATE ${KERNEL_SMT_NO_EH_RTTI_FLAGS})
target_link_libraries(triton-tv PRIVATE kernel-smt-builder-triton)
kernel_smt_link_z3(triton-tv PRIVATE)
mlir_check_all_link_libraries(triton-tv)

# Validator unit tests use the header-only harness in test/validator/SimpleTest.h
# (no GoogleTest, no network).
if(KERNEL_SMT_BUILD_TESTS)
  add_subdirectory(test/validator)
endif()
