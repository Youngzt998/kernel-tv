# Z3-only unit tests for the kernel-tv core. Each test links ONLY `kernel-tv`
# (which brings the repository include root + Z3); NO MLIR/Triton. Grouped
# under the `kernel-tv-tests` build target and registered with CTest.

if(NOT TARGET kernel-tv-tests)
  add_custom_target(kernel-tv-tests)
endif()

function(add_kernel_tv_test name)
  cmake_parse_arguments(ARG "" "" "SRCS" ${ARGN})
  add_executable(${name} ${ARG_SRCS})
  target_include_directories(${name} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})  # SimpleTest.h
  target_link_libraries(${name} PRIVATE kernel-tv)                          # core + Z3 (no MLIR)
  add_test(NAME ${name} COMMAND ${name})
  add_dependencies(kernel-tv-tests ${name})
endfunction()

add_kernel_tv_test(KernelTvTypesTest SRCS TypesTest.cpp)
add_kernel_tv_test(KernelTvAbstractFpTest SRCS AbstractFpTest.cpp)
add_kernel_tv_test(KernelTvMemoryTest SRCS MemoryTest.cpp)
add_kernel_tv_test(KernelTvContextTest SRCS ContextTest.cpp)
add_kernel_tv_test(KernelTvEquivalenceTest SRCS EquivalenceTest.cpp)
