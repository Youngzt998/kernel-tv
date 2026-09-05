# Z3-only unit tests for the kernel-smt core. Each test links ONLY `kernel-smt`
# (which brings the repository include root + Z3); NO MLIR/Triton. Grouped
# under the `kernel-smt-tests` build target and registered with CTest.

if(NOT TARGET kernel-smt-tests)
  add_custom_target(kernel-smt-tests)
endif()

function(add_kernel_smt_test name)
  cmake_parse_arguments(ARG "" "" "SRCS" ${ARGN})
  add_executable(${name} ${ARG_SRCS})
  target_include_directories(${name} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})  # SimpleTest.h
  target_link_libraries(${name} PRIVATE kernel-smt)                          # core + Z3 (no MLIR)
  add_test(NAME ${name} COMMAND ${name})
  add_dependencies(kernel-smt-tests ${name})
endfunction()

add_kernel_smt_test(KernelSmtTypesTest SRCS TypesTest.cpp)
add_kernel_smt_test(KernelSmtAbstractFpTest SRCS AbstractFpTest.cpp)
add_kernel_smt_test(KernelSmtMemoryTest SRCS MemoryTest.cpp)
add_kernel_smt_test(KernelSmtContextTest SRCS ContextTest.cpp)
add_kernel_smt_test(KernelSmtEquivalenceTest SRCS EquivalenceTest.cpp)
