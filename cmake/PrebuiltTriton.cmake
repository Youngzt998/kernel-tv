# PrebuiltTriton.cmake — enable the Triton backend from an already-built Triton.
#
# Defines the imported target `tile-smt::triton` if (and only if) TRITON_ROOT
# points at a Triton checkout that has been built. If it does not, this module
# stays silent and the top-level CMakeLists builds the core only.
#
# Inputs (a -D... variable wins, otherwise the same-named environment variable):
#   TRITON_ROOT       the Triton source checkout.        Required to enable.
#   TRITON_BUILD_DIR  its CMake build tree.              Default: auto-detected.
#   LLVM_SYSPATH      the LLVM/MLIR Triton was built against.
#                     Default: recovered from TRITON_BUILD_DIR/CMakeCache.txt.
#
# Escape hatch, for a build tree we cannot read automatically:
#   TILE_SMT_TRITON_OBJECTS   a ;-list of .o/.a files to link, used verbatim.

include(PrebuiltMLIRCompiler)

tile_smt_resolve_input(TRITON_ROOT      "Triton source checkout (enables the Triton backend)")
tile_smt_resolve_input(TRITON_BUILD_DIR "Triton CMake build tree (default: <TRITON_ROOT>/build/cmake.*)")
tile_smt_resolve_input(LLVM_SYSPATH     "LLVM/MLIR install Triton was built against")

if(NOT TRITON_ROOT)
  return()
endif()

get_filename_component(TRITON_ROOT "${TRITON_ROOT}" ABSOLUTE)
if(NOT EXISTS "${TRITON_ROOT}/bin/RegisterTritonDialects.h")
  message(FATAL_ERROR
    "TRITON_ROOT=${TRITON_ROOT} does not look like a Triton checkout "
    "(no bin/RegisterTritonDialects.h).")
endif()

# --- Locate the build tree ---------------------------------------------------
# setup.py names it build/cmake.<platform>-cpython-<ver>; take the newest if a
# checkout has several (e.g. after a Python upgrade).
if(NOT TRITON_BUILD_DIR)
  file(GLOB _candidates "${TRITON_ROOT}/build/cmake.*")
  list(FILTER _candidates EXCLUDE REGEX "\\.(txt|log)$")
  foreach(_c IN LISTS _candidates)
    if(EXISTS "${_c}/CMakeCache.txt")
      list(APPEND _built "${_c}")
    endif()
  endforeach()
  list(SORT _built)
  list(REVERSE _built)
  list(GET _built 0 TRITON_BUILD_DIR)
endif()

if(NOT TRITON_BUILD_DIR OR NOT EXISTS "${TRITON_BUILD_DIR}/CMakeCache.txt")
  message(FATAL_ERROR
    "TRITON_ROOT=${TRITON_ROOT} is not built: no CMake build tree under "
    "${TRITON_ROOT}/build/cmake.*. Build Triton first "
    "(make dev-install-llvm, or pip install -e . --no-build-isolation), "
    "or point TRITON_BUILD_DIR at the build tree.")
endif()
get_filename_component(TRITON_BUILD_DIR "${TRITON_BUILD_DIR}" ABSOLUTE)

# --- Recover the LLVM Triton was built against -------------------------------
if(NOT LLVM_SYSPATH)
  tile_smt_read_cmake_cache("${TRITON_BUILD_DIR}" "MLIR_DIR" _cached_mlir_dir)
  if(_cached_mlir_dir)
    set(MLIR_DIR "${_cached_mlir_dir}")
  else()
    tile_smt_read_cmake_cache("${TRITON_BUILD_DIR}" "LLVM_LIBRARY_DIR" _llvm_libdir)
    if(NOT _llvm_libdir)
      message(FATAL_ERROR
        "Could not recover LLVM from ${TRITON_BUILD_DIR}/CMakeCache.txt "
        "(no MLIR_DIR or LLVM_LIBRARY_DIR). Set LLVM_SYSPATH explicitly.")
    endif()
    set(MLIR_DIR "${_llvm_libdir}/cmake/mlir")
  endif()
endif()

tile_smt_find_mlir("${LLVM_SYSPATH}")
message(STATUS "tile-smt: Triton backend from ${TRITON_ROOT}")
message(STATUS "tile-smt:   build tree ${TRITON_BUILD_DIR}")
message(STATUS "tile-smt:   MLIR ${MLIR_DIR} (LLVM ${LLVM_PACKAGE_VERSION})")

# --- Harvest what triton-opt links -------------------------------------------
# `bin/triton-opt` links exactly the set triton-tv needs: compare Triton's
# bin/CMakeLists.txt against the triton-tv target below — same ${triton_libs},
# same four TritonTest* libraries, differing only in which MLIR driver library
# they pull in. So rather than guess which objects make up ${triton_libs}, ask
# the build system what it actually links, and drop triton-opt's own main().
set(_tt_objs "")
set(_tt_how "")

if(TILE_SMT_TRITON_OBJECTS)
  set(_tt_objs "${TILE_SMT_TRITON_OBJECTS}")
  set(_tt_how "TILE_SMT_TRITON_OBJECTS")
endif()

if(NOT _tt_objs AND EXISTS "${TRITON_BUILD_DIR}/build.ninja")
  find_program(TILE_SMT_NINJA NAMES ninja ninja-build)
  if(TILE_SMT_NINJA)
    execute_process(
      COMMAND "${TILE_SMT_NINJA}" -C "${TRITON_BUILD_DIR}" -t query bin/triton-opt
      OUTPUT_VARIABLE _query RESULT_VARIABLE _query_rc ERROR_QUIET)
    if(_query_rc EQUAL 0)
      string(REPLACE "\n" ";" _query_lines "${_query}")
      foreach(_line IN LISTS _query_lines)
        string(STRIP "${_line}" _line)
        if(_line STREQUAL "outputs:")
          break()  # past the inputs; the rest are triton-opt's dependents
        endif()
        string(REGEX REPLACE "^\\|+[ \t]*" "" _line "${_line}")  # ninja dep markers
        if(NOT _line MATCHES "\\.(o|a)$")
          continue()
        endif()
        if(NOT IS_ABSOLUTE "${_line}")
          set(_line "${TRITON_BUILD_DIR}/${_line}")
        endif()
        if(EXISTS "${_line}")
          list(APPEND _tt_objs "${_line}")
        endif()
      endforeach()
      if(_tt_objs)
        set(_tt_how "ninja -t query bin/triton-opt")
      endif()
    endif()
  endif()
endif()

if(NOT _tt_objs)
  # Fallback: take every object under the directories that hold library targets
  # and leave out the ones that carry a main() or a Python module init.
  file(GLOB_RECURSE _tt_objs
       "${TRITON_BUILD_DIR}/lib/*.o"
       "${TRITON_BUILD_DIR}/include/*.o"
       "${TRITON_BUILD_DIR}/third_party/*.o"
       "${TRITON_BUILD_DIR}/test/lib/*.o")
  file(GLOB_RECURSE _tt_archives
       "${TRITON_BUILD_DIR}/lib/*.a"
       "${TRITON_BUILD_DIR}/third_party/*.a"
       "${TRITON_BUILD_DIR}/test/lib/*.a")
  list(APPEND _tt_objs ${_tt_archives})
  set(_tt_how "glob of ${TRITON_BUILD_DIR}")
endif()

# triton-opt's own translation unit defines main(); ours does.
list(FILTER _tt_objs EXCLUDE REGEX "/triton-opt\\.cpp\\.o$")
list(REMOVE_DUPLICATES _tt_objs)

# Split the harvest: a sources list only understands .o (CMake tags those as
# external objects), and silently drops a .a. Archives have to be linked, and
# they have to come after the objects that reference them, which is what
# INTERFACE link libraries give us. Keep only Triton's own archives here --
# LLVM's arrive properly ordered through the MLIR targets below.
set(_tt_archives "${_tt_objs}")
list(FILTER _tt_objs EXCLUDE REGEX "\\.a$")
list(FILTER _tt_archives INCLUDE REGEX "\\.a$")
list(FILTER _tt_archives INCLUDE REGEX "^${TRITON_BUILD_DIR}/")

list(LENGTH _tt_objs _tt_count)

# Triton is ~300 translation units. A handful means we found the wrong thing,
# and a short link line fails later with a wall of undefined symbols instead of
# pointing at the cause, so refuse here.
if(_tt_count LESS 50)
  message(FATAL_ERROR
    "Only found ${_tt_count} Triton link inputs in ${TRITON_BUILD_DIR} "
    "(via ${_tt_how}). Expected a few hundred. Is Triton actually built? "
    "If the build tree is unusual, pass the list as -DTILE_SMT_TRITON_OBJECTS=...")
endif()
list(LENGTH _tt_archives _tt_archive_count)
message(STATUS
  "tile-smt:   ${_tt_count} Triton objects + ${_tt_archive_count} archives (${_tt_how})")

# --- The backend target ------------------------------------------------------
# INTERFACE sources re-expose the harvested objects the same way Triton's OBJECT
# libraries do in-tree (`target_sources(... INTERFACE $<TARGET_OBJECTS:...>)`),
# so anything linking this target gets them on its link line.
add_library(tile-smt-triton INTERFACE)
add_library(tile-smt::triton ALIAS tile-smt-triton)

target_sources(tile-smt-triton INTERFACE ${_tt_objs})

# Take the include path off triton-opt too, for the same reason we take its
# objects: each backend adds directories of its own (the AMD passes need
# third_party/amd/include for their TableGen output, and the Meta fork adds tlx
# the same way), and those rode on CMake targets we are not importing. The
# explicit entries below are the ones we rely on by name, as a floor in case the
# build tree cannot be read.
tile_smt_ninja_includes("${TRITON_BUILD_DIR}"
  "bin/CMakeFiles/triton-opt.dir/triton-opt.cpp.o" _tt_includes)
if(_tt_includes)
  list(LENGTH _tt_includes _tt_inc_count)
  message(STATUS "tile-smt:   ${_tt_inc_count} include dirs (from triton-opt)")
endif()

target_include_directories(tile-smt-triton SYSTEM INTERFACE
  ${_tt_includes}
  ${TRITON_ROOT}                      # "bin/RegisterTritonDialects.h"
  ${TRITON_ROOT}/include              # "triton/Dialect/..."
  ${TRITON_BUILD_DIR}/include         # TableGen'd *.h.inc
  ${TRITON_ROOT}/third_party          # "amd/include/...", "nvidia/include/..."
  ${TRITON_BUILD_DIR}/third_party     # TableGen'd *.h.inc for the backends
  ${MLIR_INCLUDE_DIRS}
  ${LLVM_INCLUDE_DIRS}
)

# Mirror how Triton compiles (root CMakeLists.txt): the same LLVM definitions —
# LLVM_ENABLE_ASSERTIONS travels in here and changes ABI, so it has to match the
# objects we just harvested — and the same visibility/format-macro flags.
# We deliberately do NOT pass Triton's -fno-exceptions/-fno-rtti: the builder
# layer needs std::throw (Env::lookup) and z3++ exceptions, exactly as in-tree.
separate_arguments(_llvm_defs NATIVE_COMMAND "${LLVM_DEFINITIONS}")
target_compile_definitions(tile-smt-triton INTERFACE ${_llvm_defs})
target_compile_options(tile-smt-triton INTERFACE
  -D__STDC_FORMAT_MACROS -fPIC -fvisibility=hidden)

# LLVM is normally built without RTTI or exceptions, and a translation unit that
# instantiates its templates (llvm::cl::opt, say) must agree or the link fails
# on a missing typeinfo. Triton spells this TRITON_DISABLE_EH_RTTI_FLAGS and
# applies it to tools but not to code that needs to throw; we read the setting
# off the LLVM we found instead of hardcoding it, and expose it for the few
# targets that want it. The builder layer deliberately does NOT use it: it
# throws (Env::lookup) and z3++ throws.
set(TILE_SMT_NO_EH_RTTI_FLAGS "")
if(NOT LLVM_ENABLE_RTTI)
  list(APPEND TILE_SMT_NO_EH_RTTI_FLAGS -fno-rtti)
endif()
if(NOT LLVM_ENABLE_EH)
  list(APPEND TILE_SMT_NO_EH_RTTI_FLAGS -fno-exceptions)
endif()

target_link_libraries(tile-smt-triton INTERFACE
  ${_tt_archives}   # libTritonTest*.a -- RegisterTritonDialects.h registers them
  MLIRIR
  MLIRPass
  MLIRParser
  MLIRSupport
  MLIRRegisterAllDialects
  MLIRRegisterAllPasses
  MLIRTransforms
)
