#include "builder/mlir/DTypeOf.h"

#include "mlir/IR/BuiltinTypes.h"
#include "triton/Dialect/Triton/IR/Types.h"
#include "llvm/Support/Casting.h"
#include "llvm/Support/ErrorHandling.h"

using namespace Semantics;

kernel_tv::DType Semantics::dtypeOf(mlir::Type type) {
  if (auto intTy = llvm::dyn_cast<mlir::IntegerType>(type)) {
    switch (intTy.getWidth()) {
    case 1:
      return kernel_tv::DType::I1;
    case 8:
      return kernel_tv::DType::I8;
    case 16:
      return kernel_tv::DType::I16;
    case 32:
      return kernel_tv::DType::I32;
    case 64:
      return kernel_tv::DType::I64;
    default:
      llvm_unreachable("dtypeOf: unsupported integer width");
    }
  }
  if (auto floatTy = llvm::dyn_cast<mlir::FloatType>(type))
    return dtypeOf(floatTy);
  if (llvm::isa<mlir::triton::PointerType>(type))
    return kernel_tv::DType::Ptr;
  llvm_unreachable("dtypeOf: unsupported mlir::Type");
}

kernel_tv::DType Semantics::dtypeOf(mlir::FloatType type) {
  if (llvm::isa<mlir::Float16Type>(type))
    return kernel_tv::DType::F16;
  if (llvm::isa<mlir::BFloat16Type>(type))
    return kernel_tv::DType::BF16;
  if (llvm::isa<mlir::Float32Type>(type))
    return kernel_tv::DType::F32;
  if (llvm::isa<mlir::Float64Type>(type))
    return kernel_tv::DType::F64;
  llvm_unreachable("dtypeOf: unsupported mlir::FloatType");
}
