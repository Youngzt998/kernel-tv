# PrebuiltMLIRCompiler.cmake — consume an already-built MLIR-based compiler.
#
# tile-smt is the top-level project; each language backend is enabled by
# pointing at that language's *already built* checkout (TRITON_ROOT today,
# TILELANG_ROOT later). This module holds the parts that are the same for every
# such compiler, so a new backend only has to describe what is specific to it.
#
# Why we consume raw object files instead of a package:
#   Triton's core is a set of CMake OBJECT libraries
#   (`add_triton_object` -> `add_library(${name} OBJECT)` with
#   `target_sources(... INTERFACE $<TARGET_OBJECTS:${name}>)`) and the project
#   exports no CMake package. There is nothing to find_package(). What an
#   executable actually links is the raw .o files out of the build tree, so
#   that is what we harvest — and we re-expose them through INTERFACE sources,
#   which is exactly what the OBJECT libraries do in-tree.

# tile_smt_read_cmake_cache(<build-dir> <cache-var> <out-var>)
#
# Read one entry out of a configured CMake build directory's CMakeCache.txt.
# Lets a backend recover how the host compiler was configured (its LLVM, its
# C++ compiler) instead of making the user repeat it.
function(tile_smt_read_cmake_cache build_dir key out_var)
  set(${out_var} "" PARENT_SCOPE)
  set(_cache "${build_dir}/CMakeCache.txt")
  if(NOT EXISTS "${_cache}")
    return()
  endif()
  file(STRINGS "${_cache}" _hit REGEX "^${key}:[^=]*=")
  if(_hit)
    list(GET _hit 0 _hit)
    string(REGEX REPLACE "^${key}:[^=]*=" "" _hit "${_hit}")
    set(${out_var} "${_hit}" PARENT_SCOPE)
  endif()
endfunction()

# tile_smt_resolve_input(<name> <doc>)
#
# Resolve a backend input from, in order: an existing CMake variable (-D...),
# the same-named environment variable, or nothing. Caches the result so the
# environment is only consulted on the first configure.
macro(tile_smt_resolve_input name doc)
  if(NOT DEFINED ${name} AND DEFINED ENV{${name}})
    set(${name} "$ENV{${name}}")
  endif()
  set(${name} "${${name}}" CACHE PATH "${doc}")
endmacro()

# tile_smt_find_mlir(<llvm-syspath>)
#
# Bring in MLIR/LLVM the same way the host compiler does, so our own
# translation units are ABI-compatible with the objects we are about to link
# (LLVM_ENABLE_ASSERTIONS changes ABI, and it travels in LLVM_DEFINITIONS).
macro(tile_smt_find_mlir llvm_syspath)
  if(NOT DEFINED MLIR_DIR OR NOT MLIR_DIR)
    set(MLIR_DIR "${llvm_syspath}/lib/cmake/mlir")
  endif()
  find_package(MLIR REQUIRED CONFIG PATHS "${MLIR_DIR}" NO_DEFAULT_PATH)
  list(APPEND CMAKE_MODULE_PATH "${MLIR_CMAKE_DIR}" "${LLVM_CMAKE_DIR}")
  include(TableGen)
  include(AddLLVM)
  include(AddMLIR)
endmacro()
