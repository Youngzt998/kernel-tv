# PrebuiltMLIRCompiler.cmake — consume an already-built MLIR-based compiler.
#
# kernel-smt is the top-level project; each language backend is enabled by
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

# kernel_smt_read_cmake_cache(<build-dir> <cache-var> <out-var>)
#
# Read one entry out of a configured CMake build directory's CMakeCache.txt.
# Lets a backend recover how the host compiler was configured (its LLVM, its
# C++ compiler) instead of making the user repeat it.
function(kernel_smt_read_cmake_cache build_dir key out_var)
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

# kernel_smt_resolve_input(<name> <doc>)
#
# Resolve a backend input from, in order: an existing CMake variable (-D...),
# the same-named environment variable, or nothing. Caches the result so the
# environment is only consulted on the first configure.
macro(kernel_smt_resolve_input name doc)
  if(NOT DEFINED ${name} AND DEFINED ENV{${name}})
    set(${name} "$ENV{${name}}")
  endif()
  set(${name} "${${name}}" CACHE PATH "${doc}")
endmacro()

# kernel_smt_find_mlir(<llvm-syspath>)
#
# Bring in MLIR/LLVM the same way the host compiler does, so our own
# translation units are ABI-compatible with the objects we are about to link
# (LLVM_ENABLE_ASSERTIONS changes ABI, and it travels in LLVM_DEFINITIONS).
macro(kernel_smt_find_mlir llvm_syspath)
  if(NOT DEFINED MLIR_DIR OR NOT MLIR_DIR)
    set(MLIR_DIR "${llvm_syspath}/lib/cmake/mlir")
  endif()
  find_package(MLIR REQUIRED CONFIG PATHS "${MLIR_DIR}" NO_DEFAULT_PATH)
  list(APPEND CMAKE_MODULE_PATH "${MLIR_CMAKE_DIR}" "${LLVM_CMAKE_DIR}")
  include(TableGen)
  include(AddLLVM)
  include(AddMLIR)
endmacro()

# kernel_smt_ninja_includes(<build-dir> <object-path> <out-var>)
#
# Recover the include path a Ninja build tree actually compiles one object with.
#
# Harvesting object files loses the INTERFACE include directories their CMake
# targets carried, and those matter: a backend's TableGen output lands in its
# own tree (Triton's AMD passes include "TritonAMDGPUTransforms/Passes.h.inc",
# which only resolves through third_party/amd/include). Rather than hardcode a
# list that goes stale as backends come and go, read what the build itself uses.
#
# CMake gives every object edge its own indented `INCLUDES =` line, so filter
# the file down to the build statements we care about plus every INCLUDES line,
# in order, and take the first INCLUDES after our object's statement.
function(kernel_smt_ninja_includes build_dir object out_var)
  set(${out_var} "" PARENT_SCOPE)
  set(_ninja_file "${build_dir}/build.ninja")
  if(NOT EXISTS "${_ninja_file}")
    return()
  endif()

  string(REGEX REPLACE "([.+*?^$()])" "\\\\\\1" _obj_re "${object}")
  file(STRINGS "${_ninja_file}" _lines REGEX "^build ${_obj_re}:|^ +INCLUDES = ")

  set(_armed OFF)
  foreach(_line IN LISTS _lines)
    if(_line MATCHES "^build ")
      set(_armed ON)
    elseif(_armed)
      set(_dirs "")
      # -I<dir>, -I <dir> and -isystem <dir>, quoted or bare.
      string(REGEX MATCHALL "-(I|isystem) *(\"[^\"]+\"|[^ ]+)" _flags "${_line}")
      foreach(_flag IN LISTS _flags)
        string(REGEX REPLACE "^-(I|isystem) *" "" _dir "${_flag}")
        string(REPLACE "\"" "" _dir "${_dir}")
        if(NOT IS_ABSOLUTE "${_dir}")
          set(_dir "${build_dir}/${_dir}")
        endif()
        get_filename_component(_dir "${_dir}" ABSOLUTE)
        if(IS_DIRECTORY "${_dir}")
          list(APPEND _dirs "${_dir}")
        endif()
      endforeach()
      list(REMOVE_DUPLICATES _dirs)
      set(${out_var} "${_dirs}" PARENT_SCOPE)
      return()
    endif()
  endforeach()
endfunction()
