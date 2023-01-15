#
# target tagion/iwasm/compilation/aot_llvm.d
#
C_AOT_LLVM := tagion/iwasm/compilation/aot_llvm.c
TARGET_CFILES += tagion/iwasm/compilation/aot_llvm.c
AOT_LLVM := tagion/iwasm/compilation/aot_llvm.d
TARGET_DFILES += tagion/iwasm/compilation/aot_llvm.d

tagion/iwasm/compilation/aot_llvm.c: ../wasm-micro-runtime/core/iwasm/compilation/aot_llvm.c

tagion/iwasm/compilation/aot_llvm.d: tagion/iwasm/compilation/aot_llvm.c

aot_llvm: $(AOT_LLVM)

ALL_DTARGETS += aot_llvm

#
# target tagion/iwasm/compilation/aot_emit_aot_file.d
#
C_AOT_EMIT_AOT_FILE := tagion/iwasm/compilation/aot_emit_aot_file.c
TARGET_CFILES += tagion/iwasm/compilation/aot_emit_aot_file.c
AOT_EMIT_AOT_FILE := tagion/iwasm/compilation/aot_emit_aot_file.d
TARGET_DFILES += tagion/iwasm/compilation/aot_emit_aot_file.d

tagion/iwasm/compilation/aot_emit_aot_file.c: ../wasm-micro-runtime/core/iwasm/compilation/aot_emit_aot_file.c

tagion/iwasm/compilation/aot_emit_aot_file.d: tagion/iwasm/compilation/aot_emit_aot_file.c

aot_emit_aot_file: $(AOT_EMIT_AOT_FILE)

ALL_DTARGETS += aot_emit_aot_file

#
# target tagion/iwasm/compilation/aot_emit_conversion.d
#
C_AOT_EMIT_CONVERSION := tagion/iwasm/compilation/aot_emit_conversion.c
TARGET_CFILES += tagion/iwasm/compilation/aot_emit_conversion.c
AOT_EMIT_CONVERSION := tagion/iwasm/compilation/aot_emit_conversion.d
TARGET_DFILES += tagion/iwasm/compilation/aot_emit_conversion.d

tagion/iwasm/compilation/aot_emit_conversion.c: ../wasm-micro-runtime/core/iwasm/compilation/aot_emit_conversion.c

tagion/iwasm/compilation/aot_emit_conversion.d: tagion/iwasm/compilation/aot_emit_conversion.c

aot_emit_conversion: $(AOT_EMIT_CONVERSION)

ALL_DTARGETS += aot_emit_conversion

#
# target tagion/iwasm/compilation/aot_emit_control.d
#
C_AOT_EMIT_CONTROL := tagion/iwasm/compilation/aot_emit_control.c
TARGET_CFILES += tagion/iwasm/compilation/aot_emit_control.c
AOT_EMIT_CONTROL := tagion/iwasm/compilation/aot_emit_control.d
TARGET_DFILES += tagion/iwasm/compilation/aot_emit_control.d

tagion/iwasm/compilation/aot_emit_control.c: ../wasm-micro-runtime/core/iwasm/compilation/aot_emit_control.c

tagion/iwasm/compilation/aot_emit_control.d: tagion/iwasm/compilation/aot_emit_control.c

aot_emit_control: $(AOT_EMIT_CONTROL)

ALL_DTARGETS += aot_emit_control

#
# target tagion/iwasm/compilation/aot_emit_exception.d
#
C_AOT_EMIT_EXCEPTION := tagion/iwasm/compilation/aot_emit_exception.c
TARGET_CFILES += tagion/iwasm/compilation/aot_emit_exception.c
AOT_EMIT_EXCEPTION := tagion/iwasm/compilation/aot_emit_exception.d
TARGET_DFILES += tagion/iwasm/compilation/aot_emit_exception.d

tagion/iwasm/compilation/aot_emit_exception.c: ../wasm-micro-runtime/core/iwasm/compilation/aot_emit_exception.c

tagion/iwasm/compilation/aot_emit_exception.d: tagion/iwasm/compilation/aot_emit_exception.c

aot_emit_exception: $(AOT_EMIT_EXCEPTION)

ALL_DTARGETS += aot_emit_exception

#
# target tagion/iwasm/compilation/simd/simd_comparisons.d
#
C_SIMD_COMPARISONS := tagion/iwasm/compilation/simd/simd_comparisons.c
TARGET_CFILES += tagion/iwasm/compilation/simd/simd_comparisons.c
SIMD_COMPARISONS := tagion/iwasm/compilation/simd/simd_comparisons.d
TARGET_DFILES += tagion/iwasm/compilation/simd/simd_comparisons.d

tagion/iwasm/compilation/simd/simd_comparisons.c: ../wasm-micro-runtime/core/iwasm/compilation/simd/simd_comparisons.c

tagion/iwasm/compilation/simd/simd_comparisons.d: tagion/iwasm/compilation/simd/simd_comparisons.c

simd_comparisons: $(SIMD_COMPARISONS)

ALL_DTARGETS += simd_comparisons

#
# target tagion/iwasm/compilation/simd/simd_load_store.d
#
C_SIMD_LOAD_STORE := tagion/iwasm/compilation/simd/simd_load_store.c
TARGET_CFILES += tagion/iwasm/compilation/simd/simd_load_store.c
SIMD_LOAD_STORE := tagion/iwasm/compilation/simd/simd_load_store.d
TARGET_DFILES += tagion/iwasm/compilation/simd/simd_load_store.d

tagion/iwasm/compilation/simd/simd_load_store.c: ../wasm-micro-runtime/core/iwasm/compilation/simd/simd_load_store.c

tagion/iwasm/compilation/simd/simd_load_store.d: tagion/iwasm/compilation/simd/simd_load_store.c

simd_load_store: $(SIMD_LOAD_STORE)

ALL_DTARGETS += simd_load_store

#
# target tagion/iwasm/compilation/simd/simd_construct_values.d
#
C_SIMD_CONSTRUCT_VALUES := tagion/iwasm/compilation/simd/simd_construct_values.c
TARGET_CFILES += tagion/iwasm/compilation/simd/simd_construct_values.c
SIMD_CONSTRUCT_VALUES := tagion/iwasm/compilation/simd/simd_construct_values.d
TARGET_DFILES += tagion/iwasm/compilation/simd/simd_construct_values.d

tagion/iwasm/compilation/simd/simd_construct_values.c: ../wasm-micro-runtime/core/iwasm/compilation/simd/simd_construct_values.c

tagion/iwasm/compilation/simd/simd_construct_values.d: tagion/iwasm/compilation/simd/simd_construct_values.c

simd_construct_values: $(SIMD_CONSTRUCT_VALUES)

ALL_DTARGETS += simd_construct_values

#
# target tagion/iwasm/compilation/simd/simd_int_arith.d
#
C_SIMD_INT_ARITH := tagion/iwasm/compilation/simd/simd_int_arith.c
TARGET_CFILES += tagion/iwasm/compilation/simd/simd_int_arith.c
SIMD_INT_ARITH := tagion/iwasm/compilation/simd/simd_int_arith.d
TARGET_DFILES += tagion/iwasm/compilation/simd/simd_int_arith.d

tagion/iwasm/compilation/simd/simd_int_arith.c: ../wasm-micro-runtime/core/iwasm/compilation/simd/simd_int_arith.c

tagion/iwasm/compilation/simd/simd_int_arith.d: tagion/iwasm/compilation/simd/simd_int_arith.c

simd_int_arith: $(SIMD_INT_ARITH)

ALL_DTARGETS += simd_int_arith

#
# target tagion/iwasm/compilation/simd/simd_bitwise_ops.d
#
C_SIMD_BITWISE_OPS := tagion/iwasm/compilation/simd/simd_bitwise_ops.c
TARGET_CFILES += tagion/iwasm/compilation/simd/simd_bitwise_ops.c
SIMD_BITWISE_OPS := tagion/iwasm/compilation/simd/simd_bitwise_ops.d
TARGET_DFILES += tagion/iwasm/compilation/simd/simd_bitwise_ops.d

tagion/iwasm/compilation/simd/simd_bitwise_ops.c: ../wasm-micro-runtime/core/iwasm/compilation/simd/simd_bitwise_ops.c

tagion/iwasm/compilation/simd/simd_bitwise_ops.d: tagion/iwasm/compilation/simd/simd_bitwise_ops.c

simd_bitwise_ops: $(SIMD_BITWISE_OPS)

ALL_DTARGETS += simd_bitwise_ops

#
# target tagion/iwasm/compilation/simd/simd_floating_point.d
#
C_SIMD_FLOATING_POINT := tagion/iwasm/compilation/simd/simd_floating_point.c
TARGET_CFILES += tagion/iwasm/compilation/simd/simd_floating_point.c
SIMD_FLOATING_POINT := tagion/iwasm/compilation/simd/simd_floating_point.d
TARGET_DFILES += tagion/iwasm/compilation/simd/simd_floating_point.d

tagion/iwasm/compilation/simd/simd_floating_point.c: ../wasm-micro-runtime/core/iwasm/compilation/simd/simd_floating_point.c

tagion/iwasm/compilation/simd/simd_floating_point.d: tagion/iwasm/compilation/simd/simd_floating_point.c

simd_floating_point: $(SIMD_FLOATING_POINT)

ALL_DTARGETS += simd_floating_point

#
# target tagion/iwasm/compilation/simd/simd_common.d
#
C_SIMD_COMMON := tagion/iwasm/compilation/simd/simd_common.c
TARGET_CFILES += tagion/iwasm/compilation/simd/simd_common.c
SIMD_COMMON := tagion/iwasm/compilation/simd/simd_common.d
TARGET_DFILES += tagion/iwasm/compilation/simd/simd_common.d

tagion/iwasm/compilation/simd/simd_common.c: ../wasm-micro-runtime/core/iwasm/compilation/simd/simd_common.c

tagion/iwasm/compilation/simd/simd_common.d: tagion/iwasm/compilation/simd/simd_common.c

simd_common: $(SIMD_COMMON)

ALL_DTARGETS += simd_common

#
# target tagion/iwasm/compilation/simd/simd_bit_shifts.d
#
C_SIMD_BIT_SHIFTS := tagion/iwasm/compilation/simd/simd_bit_shifts.c
TARGET_CFILES += tagion/iwasm/compilation/simd/simd_bit_shifts.c
SIMD_BIT_SHIFTS := tagion/iwasm/compilation/simd/simd_bit_shifts.d
TARGET_DFILES += tagion/iwasm/compilation/simd/simd_bit_shifts.d

tagion/iwasm/compilation/simd/simd_bit_shifts.c: ../wasm-micro-runtime/core/iwasm/compilation/simd/simd_bit_shifts.c

tagion/iwasm/compilation/simd/simd_bit_shifts.d: tagion/iwasm/compilation/simd/simd_bit_shifts.c

simd_bit_shifts: $(SIMD_BIT_SHIFTS)

ALL_DTARGETS += simd_bit_shifts

#
# target tagion/iwasm/compilation/simd/simd_sat_int_arith.d
#
C_SIMD_SAT_INT_ARITH := tagion/iwasm/compilation/simd/simd_sat_int_arith.c
TARGET_CFILES += tagion/iwasm/compilation/simd/simd_sat_int_arith.c
SIMD_SAT_INT_ARITH := tagion/iwasm/compilation/simd/simd_sat_int_arith.d
TARGET_DFILES += tagion/iwasm/compilation/simd/simd_sat_int_arith.d

tagion/iwasm/compilation/simd/simd_sat_int_arith.c: ../wasm-micro-runtime/core/iwasm/compilation/simd/simd_sat_int_arith.c

tagion/iwasm/compilation/simd/simd_sat_int_arith.d: tagion/iwasm/compilation/simd/simd_sat_int_arith.c

simd_sat_int_arith: $(SIMD_SAT_INT_ARITH)

ALL_DTARGETS += simd_sat_int_arith

#
# target tagion/iwasm/compilation/simd/simd_bitmask_extracts.d
#
C_SIMD_BITMASK_EXTRACTS := tagion/iwasm/compilation/simd/simd_bitmask_extracts.c
TARGET_CFILES += tagion/iwasm/compilation/simd/simd_bitmask_extracts.c
SIMD_BITMASK_EXTRACTS := tagion/iwasm/compilation/simd/simd_bitmask_extracts.d
TARGET_DFILES += tagion/iwasm/compilation/simd/simd_bitmask_extracts.d

tagion/iwasm/compilation/simd/simd_bitmask_extracts.c: ../wasm-micro-runtime/core/iwasm/compilation/simd/simd_bitmask_extracts.c

tagion/iwasm/compilation/simd/simd_bitmask_extracts.d: tagion/iwasm/compilation/simd/simd_bitmask_extracts.c

simd_bitmask_extracts: $(SIMD_BITMASK_EXTRACTS)

ALL_DTARGETS += simd_bitmask_extracts

#
# target tagion/iwasm/compilation/simd/simd_access_lanes.d
#
C_SIMD_ACCESS_LANES := tagion/iwasm/compilation/simd/simd_access_lanes.c
TARGET_CFILES += tagion/iwasm/compilation/simd/simd_access_lanes.c
SIMD_ACCESS_LANES := tagion/iwasm/compilation/simd/simd_access_lanes.d
TARGET_DFILES += tagion/iwasm/compilation/simd/simd_access_lanes.d

tagion/iwasm/compilation/simd/simd_access_lanes.c: ../wasm-micro-runtime/core/iwasm/compilation/simd/simd_access_lanes.c

tagion/iwasm/compilation/simd/simd_access_lanes.d: tagion/iwasm/compilation/simd/simd_access_lanes.c

simd_access_lanes: $(SIMD_ACCESS_LANES)

ALL_DTARGETS += simd_access_lanes

#
# target tagion/iwasm/compilation/simd/simd_conversions.d
#
C_SIMD_CONVERSIONS := tagion/iwasm/compilation/simd/simd_conversions.c
TARGET_CFILES += tagion/iwasm/compilation/simd/simd_conversions.c
SIMD_CONVERSIONS := tagion/iwasm/compilation/simd/simd_conversions.d
TARGET_DFILES += tagion/iwasm/compilation/simd/simd_conversions.d

tagion/iwasm/compilation/simd/simd_conversions.c: ../wasm-micro-runtime/core/iwasm/compilation/simd/simd_conversions.c

tagion/iwasm/compilation/simd/simd_conversions.d: tagion/iwasm/compilation/simd/simd_conversions.c

simd_conversions: $(SIMD_CONVERSIONS)

ALL_DTARGETS += simd_conversions

#
# target tagion/iwasm/compilation/simd/simd_bool_reductions.d
#
C_SIMD_BOOL_REDUCTIONS := tagion/iwasm/compilation/simd/simd_bool_reductions.c
TARGET_CFILES += tagion/iwasm/compilation/simd/simd_bool_reductions.c
SIMD_BOOL_REDUCTIONS := tagion/iwasm/compilation/simd/simd_bool_reductions.d
TARGET_DFILES += tagion/iwasm/compilation/simd/simd_bool_reductions.d

tagion/iwasm/compilation/simd/simd_bool_reductions.c: ../wasm-micro-runtime/core/iwasm/compilation/simd/simd_bool_reductions.c

tagion/iwasm/compilation/simd/simd_bool_reductions.d: tagion/iwasm/compilation/simd/simd_bool_reductions.c

simd_bool_reductions: $(SIMD_BOOL_REDUCTIONS)

ALL_DTARGETS += simd_bool_reductions

#
# target tagion/iwasm/compilation/aot_emit_function.d
#
C_AOT_EMIT_FUNCTION := tagion/iwasm/compilation/aot_emit_function.c
TARGET_CFILES += tagion/iwasm/compilation/aot_emit_function.c
AOT_EMIT_FUNCTION := tagion/iwasm/compilation/aot_emit_function.d
TARGET_DFILES += tagion/iwasm/compilation/aot_emit_function.d

tagion/iwasm/compilation/aot_emit_function.c: ../wasm-micro-runtime/core/iwasm/compilation/aot_emit_function.c

tagion/iwasm/compilation/aot_emit_function.d: tagion/iwasm/compilation/aot_emit_function.c

aot_emit_function: $(AOT_EMIT_FUNCTION)

ALL_DTARGETS += aot_emit_function

#
# target tagion/iwasm/compilation/aot_emit_variable.d
#
C_AOT_EMIT_VARIABLE := tagion/iwasm/compilation/aot_emit_variable.c
TARGET_CFILES += tagion/iwasm/compilation/aot_emit_variable.c
AOT_EMIT_VARIABLE := tagion/iwasm/compilation/aot_emit_variable.d
TARGET_DFILES += tagion/iwasm/compilation/aot_emit_variable.d

tagion/iwasm/compilation/aot_emit_variable.c: ../wasm-micro-runtime/core/iwasm/compilation/aot_emit_variable.c

tagion/iwasm/compilation/aot_emit_variable.d: tagion/iwasm/compilation/aot_emit_variable.c

aot_emit_variable: $(AOT_EMIT_VARIABLE)

ALL_DTARGETS += aot_emit_variable

#
# target tagion/iwasm/compilation/aot_emit_const.d
#
C_AOT_EMIT_CONST := tagion/iwasm/compilation/aot_emit_const.c
TARGET_CFILES += tagion/iwasm/compilation/aot_emit_const.c
AOT_EMIT_CONST := tagion/iwasm/compilation/aot_emit_const.d
TARGET_DFILES += tagion/iwasm/compilation/aot_emit_const.d

tagion/iwasm/compilation/aot_emit_const.c: ../wasm-micro-runtime/core/iwasm/compilation/aot_emit_const.c

tagion/iwasm/compilation/aot_emit_const.d: tagion/iwasm/compilation/aot_emit_const.c

aot_emit_const: $(AOT_EMIT_CONST)

ALL_DTARGETS += aot_emit_const

#
# target tagion/iwasm/compilation/aot.d
#
C_AOT := tagion/iwasm/compilation/aot.c
TARGET_CFILES += tagion/iwasm/compilation/aot.c
AOT := tagion/iwasm/compilation/aot.d
TARGET_DFILES += tagion/iwasm/compilation/aot.d

tagion/iwasm/compilation/aot.c: ../wasm-micro-runtime/core/iwasm/compilation/aot.c

tagion/iwasm/compilation/aot.d: tagion/iwasm/compilation/aot.c

aot: $(AOT)

ALL_DTARGETS += aot

#
# target tagion/iwasm/compilation/aot_emit_memory.d
#
C_AOT_EMIT_MEMORY := tagion/iwasm/compilation/aot_emit_memory.c
TARGET_CFILES += tagion/iwasm/compilation/aot_emit_memory.c
AOT_EMIT_MEMORY := tagion/iwasm/compilation/aot_emit_memory.d
TARGET_DFILES += tagion/iwasm/compilation/aot_emit_memory.d

tagion/iwasm/compilation/aot_emit_memory.c: ../wasm-micro-runtime/core/iwasm/compilation/aot_emit_memory.c

tagion/iwasm/compilation/aot_emit_memory.d: tagion/iwasm/compilation/aot_emit_memory.c

aot_emit_memory: $(AOT_EMIT_MEMORY)

ALL_DTARGETS += aot_emit_memory

#
# target tagion/iwasm/compilation/aot_emit_parametric.d
#
C_AOT_EMIT_PARAMETRIC := tagion/iwasm/compilation/aot_emit_parametric.c
TARGET_CFILES += tagion/iwasm/compilation/aot_emit_parametric.c
AOT_EMIT_PARAMETRIC := tagion/iwasm/compilation/aot_emit_parametric.d
TARGET_DFILES += tagion/iwasm/compilation/aot_emit_parametric.d

tagion/iwasm/compilation/aot_emit_parametric.c: ../wasm-micro-runtime/core/iwasm/compilation/aot_emit_parametric.c

tagion/iwasm/compilation/aot_emit_parametric.d: tagion/iwasm/compilation/aot_emit_parametric.c

aot_emit_parametric: $(AOT_EMIT_PARAMETRIC)

ALL_DTARGETS += aot_emit_parametric

#
# target tagion/iwasm/compilation/aot_emit_numberic.d
#
C_AOT_EMIT_NUMBERIC := tagion/iwasm/compilation/aot_emit_numberic.c
TARGET_CFILES += tagion/iwasm/compilation/aot_emit_numberic.c
AOT_EMIT_NUMBERIC := tagion/iwasm/compilation/aot_emit_numberic.d
TARGET_DFILES += tagion/iwasm/compilation/aot_emit_numberic.d

tagion/iwasm/compilation/aot_emit_numberic.c: ../wasm-micro-runtime/core/iwasm/compilation/aot_emit_numberic.c

tagion/iwasm/compilation/aot_emit_numberic.d: tagion/iwasm/compilation/aot_emit_numberic.c

aot_emit_numberic: $(AOT_EMIT_NUMBERIC)

ALL_DTARGETS += aot_emit_numberic

#
# target tagion/iwasm/compilation/aot_emit_table.d
#
C_AOT_EMIT_TABLE := tagion/iwasm/compilation/aot_emit_table.c
TARGET_CFILES += tagion/iwasm/compilation/aot_emit_table.c
AOT_EMIT_TABLE := tagion/iwasm/compilation/aot_emit_table.d
TARGET_DFILES += tagion/iwasm/compilation/aot_emit_table.d

tagion/iwasm/compilation/aot_emit_table.c: ../wasm-micro-runtime/core/iwasm/compilation/aot_emit_table.c

tagion/iwasm/compilation/aot_emit_table.d: tagion/iwasm/compilation/aot_emit_table.c

aot_emit_table: $(AOT_EMIT_TABLE)

ALL_DTARGETS += aot_emit_table

#
# target tagion/iwasm/compilation/aot_compiler.d
#
C_AOT_COMPILER := tagion/iwasm/compilation/aot_compiler.c
TARGET_CFILES += tagion/iwasm/compilation/aot_compiler.c
AOT_COMPILER := tagion/iwasm/compilation/aot_compiler.d
TARGET_DFILES += tagion/iwasm/compilation/aot_compiler.d

tagion/iwasm/compilation/aot_compiler.c: ../wasm-micro-runtime/core/iwasm/compilation/aot_compiler.c

tagion/iwasm/compilation/aot_compiler.d: tagion/iwasm/compilation/aot_compiler.c

aot_compiler: $(AOT_COMPILER)

ALL_DTARGETS += aot_compiler

#
# target tagion/iwasm/compilation/aot_emit_compare.d
#
C_AOT_EMIT_COMPARE := tagion/iwasm/compilation/aot_emit_compare.c
TARGET_CFILES += tagion/iwasm/compilation/aot_emit_compare.c
AOT_EMIT_COMPARE := tagion/iwasm/compilation/aot_emit_compare.d
TARGET_DFILES += tagion/iwasm/compilation/aot_emit_compare.d

tagion/iwasm/compilation/aot_emit_compare.c: ../wasm-micro-runtime/core/iwasm/compilation/aot_emit_compare.c

tagion/iwasm/compilation/aot_emit_compare.d: tagion/iwasm/compilation/aot_emit_compare.c

aot_emit_compare: $(AOT_EMIT_COMPARE)

ALL_DTARGETS += aot_emit_compare

#
# target tagion/iwasm/interpreter/wasm_runtime.d
#
C_WASM_RUNTIME := tagion/iwasm/interpreter/wasm_runtime.c
TARGET_CFILES += tagion/iwasm/interpreter/wasm_runtime.c
WASM_RUNTIME := tagion/iwasm/interpreter/wasm_runtime.d
TARGET_DFILES += tagion/iwasm/interpreter/wasm_runtime.d

tagion/iwasm/interpreter/wasm_runtime.c: ../wasm-micro-runtime/core/iwasm/interpreter/wasm_runtime.c

tagion/iwasm/interpreter/wasm_runtime.d: tagion/iwasm/interpreter/wasm_runtime.c

wasm_runtime: $(WASM_RUNTIME)

ALL_DTARGETS += wasm_runtime

#
# target tagion/iwasm/interpreter/wasm_interp_fast.d
#
C_WASM_INTERP_FAST := tagion/iwasm/interpreter/wasm_interp_fast.c
TARGET_CFILES += tagion/iwasm/interpreter/wasm_interp_fast.c
WASM_INTERP_FAST := tagion/iwasm/interpreter/wasm_interp_fast.d
TARGET_DFILES += tagion/iwasm/interpreter/wasm_interp_fast.d

tagion/iwasm/interpreter/wasm_interp_fast.c: ../wasm-micro-runtime/core/iwasm/interpreter/wasm_interp_fast.c

tagion/iwasm/interpreter/wasm_interp_fast.d: tagion/iwasm/interpreter/wasm_interp_fast.c

wasm_interp_fast: $(WASM_INTERP_FAST)

ALL_DTARGETS += wasm_interp_fast

#
# target tagion/iwasm/interpreter/wasm_loader.d
#
C_WASM_LOADER := tagion/iwasm/interpreter/wasm_loader.c
TARGET_CFILES += tagion/iwasm/interpreter/wasm_loader.c
WASM_LOADER := tagion/iwasm/interpreter/wasm_loader.d
TARGET_DFILES += tagion/iwasm/interpreter/wasm_loader.d

tagion/iwasm/interpreter/wasm_loader.c: ../wasm-micro-runtime/core/iwasm/interpreter/wasm_loader.c

tagion/iwasm/interpreter/wasm_loader.d: tagion/iwasm/interpreter/wasm_loader.c

wasm_loader: $(WASM_LOADER)

ALL_DTARGETS += wasm_loader

#
# target tagion/iwasm/interpreter/wasm_mini_loader.d
#
C_WASM_MINI_LOADER := tagion/iwasm/interpreter/wasm_mini_loader.c
TARGET_CFILES += tagion/iwasm/interpreter/wasm_mini_loader.c
WASM_MINI_LOADER := tagion/iwasm/interpreter/wasm_mini_loader.d
TARGET_DFILES += tagion/iwasm/interpreter/wasm_mini_loader.d

tagion/iwasm/interpreter/wasm_mini_loader.c: ../wasm-micro-runtime/core/iwasm/interpreter/wasm_mini_loader.c

tagion/iwasm/interpreter/wasm_mini_loader.d: tagion/iwasm/interpreter/wasm_mini_loader.c

wasm_mini_loader: $(WASM_MINI_LOADER)

ALL_DTARGETS += wasm_mini_loader

#
# target tagion/iwasm/interpreter/wasm_interp_classic.d
#
C_WASM_INTERP_CLASSIC := tagion/iwasm/interpreter/wasm_interp_classic.c
TARGET_CFILES += tagion/iwasm/interpreter/wasm_interp_classic.c
WASM_INTERP_CLASSIC := tagion/iwasm/interpreter/wasm_interp_classic.d
TARGET_DFILES += tagion/iwasm/interpreter/wasm_interp_classic.d

tagion/iwasm/interpreter/wasm_interp_classic.c: ../wasm-micro-runtime/core/iwasm/interpreter/wasm_interp_classic.c

tagion/iwasm/interpreter/wasm_interp_classic.d: tagion/iwasm/interpreter/wasm_interp_classic.c

wasm_interp_classic: $(WASM_INTERP_CLASSIC)

ALL_DTARGETS += wasm_interp_classic

#
# target tagion/iwasm/fast_jit/jit_compiler.d
#
C_JIT_COMPILER := tagion/iwasm/fast_jit/jit_compiler.c
TARGET_CFILES += tagion/iwasm/fast_jit/jit_compiler.c
JIT_COMPILER := tagion/iwasm/fast_jit/jit_compiler.d
TARGET_DFILES += tagion/iwasm/fast_jit/jit_compiler.d

tagion/iwasm/fast_jit/jit_compiler.c: ../wasm-micro-runtime/core/iwasm/fast-jit/jit_compiler.c

tagion/iwasm/fast_jit/jit_compiler.d: tagion/iwasm/fast_jit/jit_compiler.c

jit_compiler: $(JIT_COMPILER)

ALL_DTARGETS += jit_compiler

#
# target tagion/iwasm/fast_jit/jit_frontend.d
#
C_JIT_FRONTEND := tagion/iwasm/fast_jit/jit_frontend.c
TARGET_CFILES += tagion/iwasm/fast_jit/jit_frontend.c
JIT_FRONTEND := tagion/iwasm/fast_jit/jit_frontend.d
TARGET_DFILES += tagion/iwasm/fast_jit/jit_frontend.d

tagion/iwasm/fast_jit/jit_frontend.c: ../wasm-micro-runtime/core/iwasm/fast-jit/jit_frontend.c

tagion/iwasm/fast_jit/jit_frontend.d: tagion/iwasm/fast_jit/jit_frontend.c

jit_frontend: $(JIT_FRONTEND)

ALL_DTARGETS += jit_frontend

#
# target tagion/iwasm/fast_jit/jit_codecache.d
#
C_JIT_CODECACHE := tagion/iwasm/fast_jit/jit_codecache.c
TARGET_CFILES += tagion/iwasm/fast_jit/jit_codecache.c
JIT_CODECACHE := tagion/iwasm/fast_jit/jit_codecache.d
TARGET_DFILES += tagion/iwasm/fast_jit/jit_codecache.d

tagion/iwasm/fast_jit/jit_codecache.c: ../wasm-micro-runtime/core/iwasm/fast-jit/jit_codecache.c

tagion/iwasm/fast_jit/jit_codecache.d: tagion/iwasm/fast_jit/jit_codecache.c

jit_codecache: $(JIT_CODECACHE)

ALL_DTARGETS += jit_codecache

#
# target tagion/iwasm/fast_jit/jit_ir.d
#
C_JIT_IR := tagion/iwasm/fast_jit/jit_ir.c
TARGET_CFILES += tagion/iwasm/fast_jit/jit_ir.c
JIT_IR := tagion/iwasm/fast_jit/jit_ir.d
TARGET_DFILES += tagion/iwasm/fast_jit/jit_ir.d

tagion/iwasm/fast_jit/jit_ir.c: ../wasm-micro-runtime/core/iwasm/fast-jit/jit_ir.c

tagion/iwasm/fast_jit/jit_ir.d: tagion/iwasm/fast_jit/jit_ir.c

jit_ir: $(JIT_IR)

ALL_DTARGETS += jit_ir

#
# target tagion/iwasm/fast_jit/fe/jit_emit_parametric.d
#
C_JIT_EMIT_PARAMETRIC := tagion/iwasm/fast_jit/fe/jit_emit_parametric.c
TARGET_CFILES += tagion/iwasm/fast_jit/fe/jit_emit_parametric.c
JIT_EMIT_PARAMETRIC := tagion/iwasm/fast_jit/fe/jit_emit_parametric.d
TARGET_DFILES += tagion/iwasm/fast_jit/fe/jit_emit_parametric.d

tagion/iwasm/fast_jit/fe/jit_emit_parametric.c: ../wasm-micro-runtime/core/iwasm/fast-jit/fe/jit_emit_parametric.c

tagion/iwasm/fast_jit/fe/jit_emit_parametric.d: tagion/iwasm/fast_jit/fe/jit_emit_parametric.c

jit_emit_parametric: $(JIT_EMIT_PARAMETRIC)

ALL_DTARGETS += jit_emit_parametric

#
# target tagion/iwasm/fast_jit/fe/jit_emit_memory.d
#
C_JIT_EMIT_MEMORY := tagion/iwasm/fast_jit/fe/jit_emit_memory.c
TARGET_CFILES += tagion/iwasm/fast_jit/fe/jit_emit_memory.c
JIT_EMIT_MEMORY := tagion/iwasm/fast_jit/fe/jit_emit_memory.d
TARGET_DFILES += tagion/iwasm/fast_jit/fe/jit_emit_memory.d

tagion/iwasm/fast_jit/fe/jit_emit_memory.c: ../wasm-micro-runtime/core/iwasm/fast-jit/fe/jit_emit_memory.c

tagion/iwasm/fast_jit/fe/jit_emit_memory.d: tagion/iwasm/fast_jit/fe/jit_emit_memory.c

jit_emit_memory: $(JIT_EMIT_MEMORY)

ALL_DTARGETS += jit_emit_memory

#
# target tagion/iwasm/fast_jit/fe/jit_emit_control.d
#
C_JIT_EMIT_CONTROL := tagion/iwasm/fast_jit/fe/jit_emit_control.c
TARGET_CFILES += tagion/iwasm/fast_jit/fe/jit_emit_control.c
JIT_EMIT_CONTROL := tagion/iwasm/fast_jit/fe/jit_emit_control.d
TARGET_DFILES += tagion/iwasm/fast_jit/fe/jit_emit_control.d

tagion/iwasm/fast_jit/fe/jit_emit_control.c: ../wasm-micro-runtime/core/iwasm/fast-jit/fe/jit_emit_control.c

tagion/iwasm/fast_jit/fe/jit_emit_control.d: tagion/iwasm/fast_jit/fe/jit_emit_control.c

jit_emit_control: $(JIT_EMIT_CONTROL)

ALL_DTARGETS += jit_emit_control

#
# target tagion/iwasm/fast_jit/fe/jit_emit_table.d
#
C_JIT_EMIT_TABLE := tagion/iwasm/fast_jit/fe/jit_emit_table.c
TARGET_CFILES += tagion/iwasm/fast_jit/fe/jit_emit_table.c
JIT_EMIT_TABLE := tagion/iwasm/fast_jit/fe/jit_emit_table.d
TARGET_DFILES += tagion/iwasm/fast_jit/fe/jit_emit_table.d

tagion/iwasm/fast_jit/fe/jit_emit_table.c: ../wasm-micro-runtime/core/iwasm/fast-jit/fe/jit_emit_table.c

tagion/iwasm/fast_jit/fe/jit_emit_table.d: tagion/iwasm/fast_jit/fe/jit_emit_table.c

jit_emit_table: $(JIT_EMIT_TABLE)

ALL_DTARGETS += jit_emit_table

#
# target tagion/iwasm/fast_jit/fe/jit_emit_compare.d
#
C_JIT_EMIT_COMPARE := tagion/iwasm/fast_jit/fe/jit_emit_compare.c
TARGET_CFILES += tagion/iwasm/fast_jit/fe/jit_emit_compare.c
JIT_EMIT_COMPARE := tagion/iwasm/fast_jit/fe/jit_emit_compare.d
TARGET_DFILES += tagion/iwasm/fast_jit/fe/jit_emit_compare.d

tagion/iwasm/fast_jit/fe/jit_emit_compare.c: ../wasm-micro-runtime/core/iwasm/fast-jit/fe/jit_emit_compare.c

tagion/iwasm/fast_jit/fe/jit_emit_compare.d: tagion/iwasm/fast_jit/fe/jit_emit_compare.c

jit_emit_compare: $(JIT_EMIT_COMPARE)

ALL_DTARGETS += jit_emit_compare

#
# target tagion/iwasm/fast_jit/fe/jit_emit_function.d
#
C_JIT_EMIT_FUNCTION := tagion/iwasm/fast_jit/fe/jit_emit_function.c
TARGET_CFILES += tagion/iwasm/fast_jit/fe/jit_emit_function.c
JIT_EMIT_FUNCTION := tagion/iwasm/fast_jit/fe/jit_emit_function.d
TARGET_DFILES += tagion/iwasm/fast_jit/fe/jit_emit_function.d

tagion/iwasm/fast_jit/fe/jit_emit_function.c: ../wasm-micro-runtime/core/iwasm/fast-jit/fe/jit_emit_function.c

tagion/iwasm/fast_jit/fe/jit_emit_function.d: tagion/iwasm/fast_jit/fe/jit_emit_function.c

jit_emit_function: $(JIT_EMIT_FUNCTION)

ALL_DTARGETS += jit_emit_function

#
# target tagion/iwasm/fast_jit/fe/jit_emit_const.d
#
C_JIT_EMIT_CONST := tagion/iwasm/fast_jit/fe/jit_emit_const.c
TARGET_CFILES += tagion/iwasm/fast_jit/fe/jit_emit_const.c
JIT_EMIT_CONST := tagion/iwasm/fast_jit/fe/jit_emit_const.d
TARGET_DFILES += tagion/iwasm/fast_jit/fe/jit_emit_const.d

tagion/iwasm/fast_jit/fe/jit_emit_const.c: ../wasm-micro-runtime/core/iwasm/fast-jit/fe/jit_emit_const.c

tagion/iwasm/fast_jit/fe/jit_emit_const.d: tagion/iwasm/fast_jit/fe/jit_emit_const.c

jit_emit_const: $(JIT_EMIT_CONST)

ALL_DTARGETS += jit_emit_const

#
# target tagion/iwasm/fast_jit/fe/jit_emit_variable.d
#
C_JIT_EMIT_VARIABLE := tagion/iwasm/fast_jit/fe/jit_emit_variable.c
TARGET_CFILES += tagion/iwasm/fast_jit/fe/jit_emit_variable.c
JIT_EMIT_VARIABLE := tagion/iwasm/fast_jit/fe/jit_emit_variable.d
TARGET_DFILES += tagion/iwasm/fast_jit/fe/jit_emit_variable.d

tagion/iwasm/fast_jit/fe/jit_emit_variable.c: ../wasm-micro-runtime/core/iwasm/fast-jit/fe/jit_emit_variable.c

tagion/iwasm/fast_jit/fe/jit_emit_variable.d: tagion/iwasm/fast_jit/fe/jit_emit_variable.c

jit_emit_variable: $(JIT_EMIT_VARIABLE)

ALL_DTARGETS += jit_emit_variable

#
# target tagion/iwasm/fast_jit/fe/jit_emit_conversion.d
#
C_JIT_EMIT_CONVERSION := tagion/iwasm/fast_jit/fe/jit_emit_conversion.c
TARGET_CFILES += tagion/iwasm/fast_jit/fe/jit_emit_conversion.c
JIT_EMIT_CONVERSION := tagion/iwasm/fast_jit/fe/jit_emit_conversion.d
TARGET_DFILES += tagion/iwasm/fast_jit/fe/jit_emit_conversion.d

tagion/iwasm/fast_jit/fe/jit_emit_conversion.c: ../wasm-micro-runtime/core/iwasm/fast-jit/fe/jit_emit_conversion.c

tagion/iwasm/fast_jit/fe/jit_emit_conversion.d: tagion/iwasm/fast_jit/fe/jit_emit_conversion.c

jit_emit_conversion: $(JIT_EMIT_CONVERSION)

ALL_DTARGETS += jit_emit_conversion

#
# target tagion/iwasm/fast_jit/fe/jit_emit_numberic.d
#
C_JIT_EMIT_NUMBERIC := tagion/iwasm/fast_jit/fe/jit_emit_numberic.c
TARGET_CFILES += tagion/iwasm/fast_jit/fe/jit_emit_numberic.c
JIT_EMIT_NUMBERIC := tagion/iwasm/fast_jit/fe/jit_emit_numberic.d
TARGET_DFILES += tagion/iwasm/fast_jit/fe/jit_emit_numberic.d

tagion/iwasm/fast_jit/fe/jit_emit_numberic.c: ../wasm-micro-runtime/core/iwasm/fast-jit/fe/jit_emit_numberic.c

tagion/iwasm/fast_jit/fe/jit_emit_numberic.d: tagion/iwasm/fast_jit/fe/jit_emit_numberic.c

jit_emit_numberic: $(JIT_EMIT_NUMBERIC)

ALL_DTARGETS += jit_emit_numberic

#
# target tagion/iwasm/fast_jit/fe/jit_emit_exception.d
#
C_JIT_EMIT_EXCEPTION := tagion/iwasm/fast_jit/fe/jit_emit_exception.c
TARGET_CFILES += tagion/iwasm/fast_jit/fe/jit_emit_exception.c
JIT_EMIT_EXCEPTION := tagion/iwasm/fast_jit/fe/jit_emit_exception.d
TARGET_DFILES += tagion/iwasm/fast_jit/fe/jit_emit_exception.d

tagion/iwasm/fast_jit/fe/jit_emit_exception.c: ../wasm-micro-runtime/core/iwasm/fast-jit/fe/jit_emit_exception.c

tagion/iwasm/fast_jit/fe/jit_emit_exception.d: tagion/iwasm/fast_jit/fe/jit_emit_exception.c

jit_emit_exception: $(JIT_EMIT_EXCEPTION)

ALL_DTARGETS += jit_emit_exception

#
# target tagion/iwasm/fast_jit/jit_dump.d
#
C_JIT_DUMP := tagion/iwasm/fast_jit/jit_dump.c
TARGET_CFILES += tagion/iwasm/fast_jit/jit_dump.c
JIT_DUMP := tagion/iwasm/fast_jit/jit_dump.d
TARGET_DFILES += tagion/iwasm/fast_jit/jit_dump.d

tagion/iwasm/fast_jit/jit_dump.c: ../wasm-micro-runtime/core/iwasm/fast-jit/jit_dump.c

tagion/iwasm/fast_jit/jit_dump.d: tagion/iwasm/fast_jit/jit_dump.c

jit_dump: $(JIT_DUMP)

ALL_DTARGETS += jit_dump

#
# target tagion/iwasm/fast_jit/jit_utils.d
#
C_JIT_UTILS := tagion/iwasm/fast_jit/jit_utils.c
TARGET_CFILES += tagion/iwasm/fast_jit/jit_utils.c
JIT_UTILS := tagion/iwasm/fast_jit/jit_utils.d
TARGET_DFILES += tagion/iwasm/fast_jit/jit_utils.d

tagion/iwasm/fast_jit/jit_utils.c: ../wasm-micro-runtime/core/iwasm/fast-jit/jit_utils.c

tagion/iwasm/fast_jit/jit_utils.d: tagion/iwasm/fast_jit/jit_utils.c

jit_utils: $(JIT_UTILS)

ALL_DTARGETS += jit_utils

#
# target tagion/iwasm/fast_jit/jit_codegen.d
#
C_JIT_CODEGEN := tagion/iwasm/fast_jit/jit_codegen.c
TARGET_CFILES += tagion/iwasm/fast_jit/jit_codegen.c
JIT_CODEGEN := tagion/iwasm/fast_jit/jit_codegen.d
TARGET_DFILES += tagion/iwasm/fast_jit/jit_codegen.d

tagion/iwasm/fast_jit/jit_codegen.c: ../wasm-micro-runtime/core/iwasm/fast-jit/jit_codegen.c

tagion/iwasm/fast_jit/jit_codegen.d: tagion/iwasm/fast_jit/jit_codegen.c

jit_codegen: $(JIT_CODEGEN)

ALL_DTARGETS += jit_codegen

#
# target tagion/iwasm/fast_jit/jit_regalloc.d
#
C_JIT_REGALLOC := tagion/iwasm/fast_jit/jit_regalloc.c
TARGET_CFILES += tagion/iwasm/fast_jit/jit_regalloc.c
JIT_REGALLOC := tagion/iwasm/fast_jit/jit_regalloc.d
TARGET_DFILES += tagion/iwasm/fast_jit/jit_regalloc.d

tagion/iwasm/fast_jit/jit_regalloc.c: ../wasm-micro-runtime/core/iwasm/fast-jit/jit_regalloc.c

tagion/iwasm/fast_jit/jit_regalloc.d: tagion/iwasm/fast_jit/jit_regalloc.c

jit_regalloc: $(JIT_REGALLOC)

ALL_DTARGETS += jit_regalloc

#
# target tagion/iwasm/common/wasm_shared_memory.d
#
C_WASM_SHARED_MEMORY := tagion/iwasm/common/wasm_shared_memory.c
TARGET_CFILES += tagion/iwasm/common/wasm_shared_memory.c
WASM_SHARED_MEMORY := tagion/iwasm/common/wasm_shared_memory.d
TARGET_DFILES += tagion/iwasm/common/wasm_shared_memory.d

tagion/iwasm/common/wasm_shared_memory.c: ../wasm-micro-runtime/core/iwasm/common/wasm_shared_memory.c

tagion/iwasm/common/wasm_shared_memory.d: tagion/iwasm/common/wasm_shared_memory.c

wasm_shared_memory: $(WASM_SHARED_MEMORY)

ALL_DTARGETS += wasm_shared_memory

#
# target tagion/iwasm/common/wasm_application.d
#
C_WASM_APPLICATION := tagion/iwasm/common/wasm_application.c
TARGET_CFILES += tagion/iwasm/common/wasm_application.c
WASM_APPLICATION := tagion/iwasm/common/wasm_application.d
TARGET_DFILES += tagion/iwasm/common/wasm_application.d

tagion/iwasm/common/wasm_application.c: ../wasm-micro-runtime/core/iwasm/common/wasm_application.c

tagion/iwasm/common/wasm_application.d: tagion/iwasm/common/wasm_application.c

wasm_application: $(WASM_APPLICATION)

ALL_DTARGETS += wasm_application

#
# target tagion/iwasm/common/wasm_c_api.d
#
C_WASM_C_API := tagion/iwasm/common/wasm_c_api.c
TARGET_CFILES += tagion/iwasm/common/wasm_c_api.c
WASM_C_API := tagion/iwasm/common/wasm_c_api.d
TARGET_DFILES += tagion/iwasm/common/wasm_c_api.d

tagion/iwasm/common/wasm_c_api.c: ../wasm-micro-runtime/core/iwasm/common/wasm_c_api.c

tagion/iwasm/common/wasm_c_api.d: tagion/iwasm/common/wasm_c_api.c

wasm_c_api: $(WASM_C_API)

ALL_DTARGETS += wasm_c_api

#
# target tagion/iwasm/common/wasm_exec_env.d
#
C_WASM_EXEC_ENV := tagion/iwasm/common/wasm_exec_env.c
TARGET_CFILES += tagion/iwasm/common/wasm_exec_env.c
WASM_EXEC_ENV := tagion/iwasm/common/wasm_exec_env.d
TARGET_DFILES += tagion/iwasm/common/wasm_exec_env.d

tagion/iwasm/common/wasm_exec_env.c: ../wasm-micro-runtime/core/iwasm/common/wasm_exec_env.c

tagion/iwasm/common/wasm_exec_env.d: tagion/iwasm/common/wasm_exec_env.c

wasm_exec_env: $(WASM_EXEC_ENV)

ALL_DTARGETS += wasm_exec_env

#
# target tagion/iwasm/common/arch/invokeNative_general.d
#
C_INVOKENATIVE_GENERAL := tagion/iwasm/common/arch/invokeNative_general.c
TARGET_CFILES += tagion/iwasm/common/arch/invokeNative_general.c
INVOKENATIVE_GENERAL := tagion/iwasm/common/arch/invokeNative_general.d
TARGET_DFILES += tagion/iwasm/common/arch/invokeNative_general.d

tagion/iwasm/common/arch/invokeNative_general.c: ../wasm-micro-runtime/core/iwasm/common/arch/invokeNative_general.c

tagion/iwasm/common/arch/invokeNative_general.d: tagion/iwasm/common/arch/invokeNative_general.c

invokenative_general: $(INVOKENATIVE_GENERAL)

ALL_DTARGETS += invokenative_general

#
# target tagion/iwasm/common/wasm_native.d
#
C_WASM_NATIVE := tagion/iwasm/common/wasm_native.c
TARGET_CFILES += tagion/iwasm/common/wasm_native.c
WASM_NATIVE := tagion/iwasm/common/wasm_native.d
TARGET_DFILES += tagion/iwasm/common/wasm_native.d

tagion/iwasm/common/wasm_native.c: ../wasm-micro-runtime/core/iwasm/common/wasm_native.c

tagion/iwasm/common/wasm_native.d: tagion/iwasm/common/wasm_native.c

wasm_native: $(WASM_NATIVE)

ALL_DTARGETS += wasm_native

#
# target tagion/iwasm/common/wasm_runtime_common.d
#
C_WASM_RUNTIME_COMMON := tagion/iwasm/common/wasm_runtime_common.c
TARGET_CFILES += tagion/iwasm/common/wasm_runtime_common.c
WASM_RUNTIME_COMMON := tagion/iwasm/common/wasm_runtime_common.d
TARGET_DFILES += tagion/iwasm/common/wasm_runtime_common.d

tagion/iwasm/common/wasm_runtime_common.c: ../wasm-micro-runtime/core/iwasm/common/wasm_runtime_common.c

tagion/iwasm/common/wasm_runtime_common.d: tagion/iwasm/common/wasm_runtime_common.c

wasm_runtime_common: $(WASM_RUNTIME_COMMON)

ALL_DTARGETS += wasm_runtime_common

#
# target tagion/iwasm/common/wasm_memory.d
#
C_WASM_MEMORY := tagion/iwasm/common/wasm_memory.c
TARGET_CFILES += tagion/iwasm/common/wasm_memory.c
WASM_MEMORY := tagion/iwasm/common/wasm_memory.d
TARGET_DFILES += tagion/iwasm/common/wasm_memory.d

tagion/iwasm/common/wasm_memory.c: ../wasm-micro-runtime/core/iwasm/common/wasm_memory.c

tagion/iwasm/common/wasm_memory.d: tagion/iwasm/common/wasm_memory.c

wasm_memory: $(WASM_MEMORY)

ALL_DTARGETS += wasm_memory

#
# target tagion/iwasm/aot/aot_runtime.d
#
C_AOT_RUNTIME := tagion/iwasm/aot/aot_runtime.c
TARGET_CFILES += tagion/iwasm/aot/aot_runtime.c
AOT_RUNTIME := tagion/iwasm/aot/aot_runtime.d
TARGET_DFILES += tagion/iwasm/aot/aot_runtime.d

tagion/iwasm/aot/aot_runtime.c: ../wasm-micro-runtime/core/iwasm/aot/aot_runtime.c

tagion/iwasm/aot/aot_runtime.d: tagion/iwasm/aot/aot_runtime.c

aot_runtime: $(AOT_RUNTIME)

ALL_DTARGETS += aot_runtime

#
# target tagion/iwasm/aot/arch/aot_reloc_aarch64.d
#
C_AOT_RELOC_AARCH64 := tagion/iwasm/aot/arch/aot_reloc_aarch64.c
TARGET_CFILES += tagion/iwasm/aot/arch/aot_reloc_aarch64.c
AOT_RELOC_AARCH64 := tagion/iwasm/aot/arch/aot_reloc_aarch64.d
TARGET_DFILES += tagion/iwasm/aot/arch/aot_reloc_aarch64.d

tagion/iwasm/aot/arch/aot_reloc_aarch64.c: ../wasm-micro-runtime/core/iwasm/aot/arch/aot_reloc_aarch64.c

tagion/iwasm/aot/arch/aot_reloc_aarch64.d: tagion/iwasm/aot/arch/aot_reloc_aarch64.c

aot_reloc_aarch64: $(AOT_RELOC_AARCH64)

ALL_DTARGETS += aot_reloc_aarch64

#
# target tagion/iwasm/aot/arch/aot_reloc_mips.d
#
C_AOT_RELOC_MIPS := tagion/iwasm/aot/arch/aot_reloc_mips.c
TARGET_CFILES += tagion/iwasm/aot/arch/aot_reloc_mips.c
AOT_RELOC_MIPS := tagion/iwasm/aot/arch/aot_reloc_mips.d
TARGET_DFILES += tagion/iwasm/aot/arch/aot_reloc_mips.d

tagion/iwasm/aot/arch/aot_reloc_mips.c: ../wasm-micro-runtime/core/iwasm/aot/arch/aot_reloc_mips.c

tagion/iwasm/aot/arch/aot_reloc_mips.d: tagion/iwasm/aot/arch/aot_reloc_mips.c

aot_reloc_mips: $(AOT_RELOC_MIPS)

ALL_DTARGETS += aot_reloc_mips

#
# target tagion/iwasm/aot/arch/aot_reloc_x86_32.d
#
C_AOT_RELOC_X86_32 := tagion/iwasm/aot/arch/aot_reloc_x86_32.c
TARGET_CFILES += tagion/iwasm/aot/arch/aot_reloc_x86_32.c
AOT_RELOC_X86_32 := tagion/iwasm/aot/arch/aot_reloc_x86_32.d
TARGET_DFILES += tagion/iwasm/aot/arch/aot_reloc_x86_32.d

tagion/iwasm/aot/arch/aot_reloc_x86_32.c: ../wasm-micro-runtime/core/iwasm/aot/arch/aot_reloc_x86_32.c

tagion/iwasm/aot/arch/aot_reloc_x86_32.d: tagion/iwasm/aot/arch/aot_reloc_x86_32.c

aot_reloc_x86_32: $(AOT_RELOC_X86_32)

ALL_DTARGETS += aot_reloc_x86_32

#
# target tagion/iwasm/aot/arch/aot_reloc_arc.d
#
C_AOT_RELOC_ARC := tagion/iwasm/aot/arch/aot_reloc_arc.c
TARGET_CFILES += tagion/iwasm/aot/arch/aot_reloc_arc.c
AOT_RELOC_ARC := tagion/iwasm/aot/arch/aot_reloc_arc.d
TARGET_DFILES += tagion/iwasm/aot/arch/aot_reloc_arc.d

tagion/iwasm/aot/arch/aot_reloc_arc.c: ../wasm-micro-runtime/core/iwasm/aot/arch/aot_reloc_arc.c

tagion/iwasm/aot/arch/aot_reloc_arc.d: tagion/iwasm/aot/arch/aot_reloc_arc.c

aot_reloc_arc: $(AOT_RELOC_ARC)

ALL_DTARGETS += aot_reloc_arc

#
# target tagion/iwasm/aot/arch/aot_reloc_thumb.d
#
C_AOT_RELOC_THUMB := tagion/iwasm/aot/arch/aot_reloc_thumb.c
TARGET_CFILES += tagion/iwasm/aot/arch/aot_reloc_thumb.c
AOT_RELOC_THUMB := tagion/iwasm/aot/arch/aot_reloc_thumb.d
TARGET_DFILES += tagion/iwasm/aot/arch/aot_reloc_thumb.d

tagion/iwasm/aot/arch/aot_reloc_thumb.c: ../wasm-micro-runtime/core/iwasm/aot/arch/aot_reloc_thumb.c

tagion/iwasm/aot/arch/aot_reloc_thumb.d: tagion/iwasm/aot/arch/aot_reloc_thumb.c

aot_reloc_thumb: $(AOT_RELOC_THUMB)

ALL_DTARGETS += aot_reloc_thumb

#
# target tagion/iwasm/aot/arch/aot_reloc_riscv.d
#
C_AOT_RELOC_RISCV := tagion/iwasm/aot/arch/aot_reloc_riscv.c
TARGET_CFILES += tagion/iwasm/aot/arch/aot_reloc_riscv.c
AOT_RELOC_RISCV := tagion/iwasm/aot/arch/aot_reloc_riscv.d
TARGET_DFILES += tagion/iwasm/aot/arch/aot_reloc_riscv.d

tagion/iwasm/aot/arch/aot_reloc_riscv.c: ../wasm-micro-runtime/core/iwasm/aot/arch/aot_reloc_riscv.c

tagion/iwasm/aot/arch/aot_reloc_riscv.d: tagion/iwasm/aot/arch/aot_reloc_riscv.c

aot_reloc_riscv: $(AOT_RELOC_RISCV)

ALL_DTARGETS += aot_reloc_riscv

#
# target tagion/iwasm/aot/arch/aot_reloc_xtensa.d
#
C_AOT_RELOC_XTENSA := tagion/iwasm/aot/arch/aot_reloc_xtensa.c
TARGET_CFILES += tagion/iwasm/aot/arch/aot_reloc_xtensa.c
AOT_RELOC_XTENSA := tagion/iwasm/aot/arch/aot_reloc_xtensa.d
TARGET_DFILES += tagion/iwasm/aot/arch/aot_reloc_xtensa.d

tagion/iwasm/aot/arch/aot_reloc_xtensa.c: ../wasm-micro-runtime/core/iwasm/aot/arch/aot_reloc_xtensa.c

tagion/iwasm/aot/arch/aot_reloc_xtensa.d: tagion/iwasm/aot/arch/aot_reloc_xtensa.c

aot_reloc_xtensa: $(AOT_RELOC_XTENSA)

ALL_DTARGETS += aot_reloc_xtensa

#
# target tagion/iwasm/aot/arch/aot_reloc_arm.d
#
C_AOT_RELOC_ARM := tagion/iwasm/aot/arch/aot_reloc_arm.c
TARGET_CFILES += tagion/iwasm/aot/arch/aot_reloc_arm.c
AOT_RELOC_ARM := tagion/iwasm/aot/arch/aot_reloc_arm.d
TARGET_DFILES += tagion/iwasm/aot/arch/aot_reloc_arm.d

tagion/iwasm/aot/arch/aot_reloc_arm.c: ../wasm-micro-runtime/core/iwasm/aot/arch/aot_reloc_arm.c

tagion/iwasm/aot/arch/aot_reloc_arm.d: tagion/iwasm/aot/arch/aot_reloc_arm.c

aot_reloc_arm: $(AOT_RELOC_ARM)

ALL_DTARGETS += aot_reloc_arm

#
# target tagion/iwasm/aot/arch/aot_reloc_x86_64.d
#
C_AOT_RELOC_X86_64 := tagion/iwasm/aot/arch/aot_reloc_x86_64.c
TARGET_CFILES += tagion/iwasm/aot/arch/aot_reloc_x86_64.c
AOT_RELOC_X86_64 := tagion/iwasm/aot/arch/aot_reloc_x86_64.d
TARGET_DFILES += tagion/iwasm/aot/arch/aot_reloc_x86_64.d

tagion/iwasm/aot/arch/aot_reloc_x86_64.c: ../wasm-micro-runtime/core/iwasm/aot/arch/aot_reloc_x86_64.c

tagion/iwasm/aot/arch/aot_reloc_x86_64.d: tagion/iwasm/aot/arch/aot_reloc_x86_64.c

aot_reloc_x86_64: $(AOT_RELOC_X86_64)

ALL_DTARGETS += aot_reloc_x86_64

#
# target tagion/iwasm/aot/aot_intrinsic.d
#
C_AOT_INTRINSIC := tagion/iwasm/aot/aot_intrinsic.c
TARGET_CFILES += tagion/iwasm/aot/aot_intrinsic.c
AOT_INTRINSIC := tagion/iwasm/aot/aot_intrinsic.d
TARGET_DFILES += tagion/iwasm/aot/aot_intrinsic.d

tagion/iwasm/aot/aot_intrinsic.c: ../wasm-micro-runtime/core/iwasm/aot/aot_intrinsic.c

tagion/iwasm/aot/aot_intrinsic.d: tagion/iwasm/aot/aot_intrinsic.c

aot_intrinsic: $(AOT_INTRINSIC)

ALL_DTARGETS += aot_intrinsic

#
# target tagion/iwasm/aot/debug_/elf_parser.d
#
C_ELF_PARSER := tagion/iwasm/aot/debug_/elf_parser.c
TARGET_CFILES += tagion/iwasm/aot/debug_/elf_parser.c
ELF_PARSER := tagion/iwasm/aot/debug_/elf_parser.d
TARGET_DFILES += tagion/iwasm/aot/debug_/elf_parser.d

tagion/iwasm/aot/debug_/elf_parser.c: ../wasm-micro-runtime/core/iwasm/aot/debug/elf_parser.c

tagion/iwasm/aot/debug_/elf_parser.d: tagion/iwasm/aot/debug_/elf_parser.c

elf_parser: $(ELF_PARSER)

ALL_DTARGETS += elf_parser

#
# target tagion/iwasm/aot/debug_/jit_debug.d
#
C_JIT_DEBUG := tagion/iwasm/aot/debug_/jit_debug.c
TARGET_CFILES += tagion/iwasm/aot/debug_/jit_debug.c
JIT_DEBUG := tagion/iwasm/aot/debug_/jit_debug.d
TARGET_DFILES += tagion/iwasm/aot/debug_/jit_debug.d

tagion/iwasm/aot/debug_/jit_debug.c: ../wasm-micro-runtime/core/iwasm/aot/debug/jit_debug.c

tagion/iwasm/aot/debug_/jit_debug.d: tagion/iwasm/aot/debug_/jit_debug.c

jit_debug: $(JIT_DEBUG)

ALL_DTARGETS += jit_debug

#
# target tagion/iwasm/aot/aot_loader.d
#
C_AOT_LOADER := tagion/iwasm/aot/aot_loader.c
TARGET_CFILES += tagion/iwasm/aot/aot_loader.c
AOT_LOADER := tagion/iwasm/aot/aot_loader.d
TARGET_DFILES += tagion/iwasm/aot/aot_loader.d

tagion/iwasm/aot/aot_loader.c: ../wasm-micro-runtime/core/iwasm/aot/aot_loader.c

tagion/iwasm/aot/aot_loader.d: tagion/iwasm/aot/aot_loader.c

aot_loader: $(AOT_LOADER)

ALL_DTARGETS += aot_loader

#
# target tagion/iwasm/libraries/lib_pthread/lib_pthread_wrapper.d
#
C_LIB_PTHREAD_WRAPPER := tagion/iwasm/libraries/lib_pthread/lib_pthread_wrapper.c
TARGET_CFILES += tagion/iwasm/libraries/lib_pthread/lib_pthread_wrapper.c
LIB_PTHREAD_WRAPPER := tagion/iwasm/libraries/lib_pthread/lib_pthread_wrapper.d
TARGET_DFILES += tagion/iwasm/libraries/lib_pthread/lib_pthread_wrapper.d

tagion/iwasm/libraries/lib_pthread/lib_pthread_wrapper.c: ../wasm-micro-runtime/core/iwasm/libraries/lib-pthread/lib_pthread_wrapper.c

tagion/iwasm/libraries/lib_pthread/lib_pthread_wrapper.d: tagion/iwasm/libraries/lib_pthread/lib_pthread_wrapper.c

lib_pthread_wrapper: $(LIB_PTHREAD_WRAPPER)

ALL_DTARGETS += lib_pthread_wrapper

#
# target tagion/iwasm/libraries/lib_socket/src/wasi/wasi_socket_ext.d
#
C_WASI_SOCKET_EXT := tagion/iwasm/libraries/lib_socket/src/wasi/wasi_socket_ext.c
TARGET_CFILES += tagion/iwasm/libraries/lib_socket/src/wasi/wasi_socket_ext.c
WASI_SOCKET_EXT := tagion/iwasm/libraries/lib_socket/src/wasi/wasi_socket_ext.d
TARGET_DFILES += tagion/iwasm/libraries/lib_socket/src/wasi/wasi_socket_ext.d

tagion/iwasm/libraries/lib_socket/src/wasi/wasi_socket_ext.c: ../wasm-micro-runtime/core/iwasm/libraries/lib-socket/src/wasi/wasi_socket_ext.c

tagion/iwasm/libraries/lib_socket/src/wasi/wasi_socket_ext.d: tagion/iwasm/libraries/lib_socket/src/wasi/wasi_socket_ext.c

wasi_socket_ext: $(WASI_SOCKET_EXT)

ALL_DTARGETS += wasi_socket_ext

#
# target tagion/iwasm/libraries/libc_builtin/libc_builtin_wrapper.d
#
C_LIBC_BUILTIN_WRAPPER := tagion/iwasm/libraries/libc_builtin/libc_builtin_wrapper.c
TARGET_CFILES += tagion/iwasm/libraries/libc_builtin/libc_builtin_wrapper.c
LIBC_BUILTIN_WRAPPER := tagion/iwasm/libraries/libc_builtin/libc_builtin_wrapper.d
TARGET_DFILES += tagion/iwasm/libraries/libc_builtin/libc_builtin_wrapper.d

tagion/iwasm/libraries/libc_builtin/libc_builtin_wrapper.c: ../wasm-micro-runtime/core/iwasm/libraries/libc-builtin/libc_builtin_wrapper.c

tagion/iwasm/libraries/libc_builtin/libc_builtin_wrapper.d: tagion/iwasm/libraries/libc_builtin/libc_builtin_wrapper.c

libc_builtin_wrapper: $(LIBC_BUILTIN_WRAPPER)

ALL_DTARGETS += libc_builtin_wrapper

#
# target tagion/iwasm/libraries/thread_mgr/thread_manager.d
#
C_THREAD_MANAGER := tagion/iwasm/libraries/thread_mgr/thread_manager.c
TARGET_CFILES += tagion/iwasm/libraries/thread_mgr/thread_manager.c
THREAD_MANAGER := tagion/iwasm/libraries/thread_mgr/thread_manager.d
TARGET_DFILES += tagion/iwasm/libraries/thread_mgr/thread_manager.d

tagion/iwasm/libraries/thread_mgr/thread_manager.c: ../wasm-micro-runtime/core/iwasm/libraries/thread-mgr/thread_manager.c

tagion/iwasm/libraries/thread_mgr/thread_manager.d: tagion/iwasm/libraries/thread_mgr/thread_manager.c

thread_manager: $(THREAD_MANAGER)

ALL_DTARGETS += thread_manager

#
# target tagion/iwasm/libraries/debug_engine/gdbserver.d
#
C_GDBSERVER := tagion/iwasm/libraries/debug_engine/gdbserver.c
TARGET_CFILES += tagion/iwasm/libraries/debug_engine/gdbserver.c
GDBSERVER := tagion/iwasm/libraries/debug_engine/gdbserver.d
TARGET_DFILES += tagion/iwasm/libraries/debug_engine/gdbserver.d

tagion/iwasm/libraries/debug_engine/gdbserver.c: ../wasm-micro-runtime/core/iwasm/libraries/debug-engine/gdbserver.c

tagion/iwasm/libraries/debug_engine/gdbserver.d: tagion/iwasm/libraries/debug_engine/gdbserver.c

gdbserver: $(GDBSERVER)

ALL_DTARGETS += gdbserver

#
# target tagion/iwasm/libraries/debug_engine/packets.d
#
C_PACKETS := tagion/iwasm/libraries/debug_engine/packets.c
TARGET_CFILES += tagion/iwasm/libraries/debug_engine/packets.c
PACKETS := tagion/iwasm/libraries/debug_engine/packets.d
TARGET_DFILES += tagion/iwasm/libraries/debug_engine/packets.d

tagion/iwasm/libraries/debug_engine/packets.c: ../wasm-micro-runtime/core/iwasm/libraries/debug-engine/packets.c

tagion/iwasm/libraries/debug_engine/packets.d: tagion/iwasm/libraries/debug_engine/packets.c

packets: $(PACKETS)

ALL_DTARGETS += packets

#
# target tagion/iwasm/libraries/debug_engine/handler.d
#
C_HANDLER := tagion/iwasm/libraries/debug_engine/handler.c
TARGET_CFILES += tagion/iwasm/libraries/debug_engine/handler.c
HANDLER := tagion/iwasm/libraries/debug_engine/handler.d
TARGET_DFILES += tagion/iwasm/libraries/debug_engine/handler.d

tagion/iwasm/libraries/debug_engine/handler.c: ../wasm-micro-runtime/core/iwasm/libraries/debug-engine/handler.c

tagion/iwasm/libraries/debug_engine/handler.d: tagion/iwasm/libraries/debug_engine/handler.c

handler: $(HANDLER)

ALL_DTARGETS += handler

#
# target tagion/iwasm/libraries/debug_engine/debug_engine.d
#
C_DEBUG_ENGINE := tagion/iwasm/libraries/debug_engine/debug_engine.c
TARGET_CFILES += tagion/iwasm/libraries/debug_engine/debug_engine.c
DEBUG_ENGINE := tagion/iwasm/libraries/debug_engine/debug_engine.d
TARGET_DFILES += tagion/iwasm/libraries/debug_engine/debug_engine.d

tagion/iwasm/libraries/debug_engine/debug_engine.c: ../wasm-micro-runtime/core/iwasm/libraries/debug-engine/debug_engine.c

tagion/iwasm/libraries/debug_engine/debug_engine.d: tagion/iwasm/libraries/debug_engine/debug_engine.c

debug_engine: $(DEBUG_ENGINE)

ALL_DTARGETS += debug_engine

#
# target tagion/iwasm/libraries/debug_engine/utils.d
#
C_UTILS := tagion/iwasm/libraries/debug_engine/utils.c
TARGET_CFILES += tagion/iwasm/libraries/debug_engine/utils.c
UTILS := tagion/iwasm/libraries/debug_engine/utils.d
TARGET_DFILES += tagion/iwasm/libraries/debug_engine/utils.d

tagion/iwasm/libraries/debug_engine/utils.c: ../wasm-micro-runtime/core/iwasm/libraries/debug-engine/utils.c

tagion/iwasm/libraries/debug_engine/utils.d: tagion/iwasm/libraries/debug_engine/utils.c

utils: $(UTILS)

ALL_DTARGETS += utils

#
# target tagion/iwasm/libraries/libc_wasi/sandboxed_system_primitives/src/posix.d
#
C_POSIX := tagion/iwasm/libraries/libc_wasi/sandboxed_system_primitives/src/posix.c
TARGET_CFILES += tagion/iwasm/libraries/libc_wasi/sandboxed_system_primitives/src/posix.c
POSIX := tagion/iwasm/libraries/libc_wasi/sandboxed_system_primitives/src/posix.d
TARGET_DFILES += tagion/iwasm/libraries/libc_wasi/sandboxed_system_primitives/src/posix.d

tagion/iwasm/libraries/libc_wasi/sandboxed_system_primitives/src/posix.c: ../wasm-micro-runtime/core/iwasm/libraries/libc-wasi/sandboxed-system-primitives/src/posix.c

tagion/iwasm/libraries/libc_wasi/sandboxed_system_primitives/src/posix.d: tagion/iwasm/libraries/libc_wasi/sandboxed_system_primitives/src/posix.c

posix: $(POSIX)

ALL_DTARGETS += posix

#
# target tagion/iwasm/libraries/libc_wasi/sandboxed_system_primitives/src/str.d
#
C_STR := tagion/iwasm/libraries/libc_wasi/sandboxed_system_primitives/src/str.c
TARGET_CFILES += tagion/iwasm/libraries/libc_wasi/sandboxed_system_primitives/src/str.c
STR := tagion/iwasm/libraries/libc_wasi/sandboxed_system_primitives/src/str.d
TARGET_DFILES += tagion/iwasm/libraries/libc_wasi/sandboxed_system_primitives/src/str.d

tagion/iwasm/libraries/libc_wasi/sandboxed_system_primitives/src/str.c: ../wasm-micro-runtime/core/iwasm/libraries/libc-wasi/sandboxed-system-primitives/src/str.c

tagion/iwasm/libraries/libc_wasi/sandboxed_system_primitives/src/str.d: tagion/iwasm/libraries/libc_wasi/sandboxed_system_primitives/src/str.c

str: $(STR)

ALL_DTARGETS += str

#
# target tagion/iwasm/libraries/libc_wasi/sandboxed_system_primitives/src/random.d
#
C_RANDOM := tagion/iwasm/libraries/libc_wasi/sandboxed_system_primitives/src/random.c
TARGET_CFILES += tagion/iwasm/libraries/libc_wasi/sandboxed_system_primitives/src/random.c
RANDOM := tagion/iwasm/libraries/libc_wasi/sandboxed_system_primitives/src/random.d
TARGET_DFILES += tagion/iwasm/libraries/libc_wasi/sandboxed_system_primitives/src/random.d

tagion/iwasm/libraries/libc_wasi/sandboxed_system_primitives/src/random.c: ../wasm-micro-runtime/core/iwasm/libraries/libc-wasi/sandboxed-system-primitives/src/random.c

tagion/iwasm/libraries/libc_wasi/sandboxed_system_primitives/src/random.d: tagion/iwasm/libraries/libc_wasi/sandboxed_system_primitives/src/random.c

random: $(RANDOM)

ALL_DTARGETS += random

#
# target tagion/iwasm/libraries/libc_wasi/libc_wasi_wrapper.d
#
C_LIBC_WASI_WRAPPER := tagion/iwasm/libraries/libc_wasi/libc_wasi_wrapper.c
TARGET_CFILES += tagion/iwasm/libraries/libc_wasi/libc_wasi_wrapper.c
LIBC_WASI_WRAPPER := tagion/iwasm/libraries/libc_wasi/libc_wasi_wrapper.d
TARGET_DFILES += tagion/iwasm/libraries/libc_wasi/libc_wasi_wrapper.d

tagion/iwasm/libraries/libc_wasi/libc_wasi_wrapper.c: ../wasm-micro-runtime/core/iwasm/libraries/libc-wasi/libc_wasi_wrapper.c

tagion/iwasm/libraries/libc_wasi/libc_wasi_wrapper.d: tagion/iwasm/libraries/libc_wasi/libc_wasi_wrapper.c

libc_wasi_wrapper: $(LIBC_WASI_WRAPPER)

ALL_DTARGETS += libc_wasi_wrapper

#
# target tagion/iwasm/libraries/libc_uvwasi/libc_uvwasi_wrapper.d
#
C_LIBC_UVWASI_WRAPPER := tagion/iwasm/libraries/libc_uvwasi/libc_uvwasi_wrapper.c
TARGET_CFILES += tagion/iwasm/libraries/libc_uvwasi/libc_uvwasi_wrapper.c
LIBC_UVWASI_WRAPPER := tagion/iwasm/libraries/libc_uvwasi/libc_uvwasi_wrapper.d
TARGET_DFILES += tagion/iwasm/libraries/libc_uvwasi/libc_uvwasi_wrapper.d

tagion/iwasm/libraries/libc_uvwasi/libc_uvwasi_wrapper.c: ../wasm-micro-runtime/core/iwasm/libraries/libc-uvwasi/libc_uvwasi_wrapper.c

tagion/iwasm/libraries/libc_uvwasi/libc_uvwasi_wrapper.d: tagion/iwasm/libraries/libc_uvwasi/libc_uvwasi_wrapper.c

libc_uvwasi_wrapper: $(LIBC_UVWASI_WRAPPER)

ALL_DTARGETS += libc_uvwasi_wrapper

#
# target tagion/iwasm/libraries/lib_rats/lib_rats_wrapper.d
#
C_LIB_RATS_WRAPPER := tagion/iwasm/libraries/lib_rats/lib_rats_wrapper.c
TARGET_CFILES += tagion/iwasm/libraries/lib_rats/lib_rats_wrapper.c
LIB_RATS_WRAPPER := tagion/iwasm/libraries/lib_rats/lib_rats_wrapper.d
TARGET_DFILES += tagion/iwasm/libraries/lib_rats/lib_rats_wrapper.d

tagion/iwasm/libraries/lib_rats/lib_rats_wrapper.c: ../wasm-micro-runtime/core/iwasm/libraries/lib-rats/lib_rats_wrapper.c

tagion/iwasm/libraries/lib_rats/lib_rats_wrapper.d: tagion/iwasm/libraries/lib_rats/lib_rats_wrapper.c

lib_rats_wrapper: $(LIB_RATS_WRAPPER)

ALL_DTARGETS += lib_rats_wrapper

#
# target tagion/iwasm/libraries/wasi_nn/test/test_tensorflow.d
#
C_TEST_TENSORFLOW := tagion/iwasm/libraries/wasi_nn/test/test_tensorflow.c
TARGET_CFILES += tagion/iwasm/libraries/wasi_nn/test/test_tensorflow.c
TEST_TENSORFLOW := tagion/iwasm/libraries/wasi_nn/test/test_tensorflow.d
TARGET_DFILES += tagion/iwasm/libraries/wasi_nn/test/test_tensorflow.d

tagion/iwasm/libraries/wasi_nn/test/test_tensorflow.c: ../wasm-micro-runtime/core/iwasm/libraries/wasi-nn/test/test_tensorflow.c

tagion/iwasm/libraries/wasi_nn/test/test_tensorflow.d: tagion/iwasm/libraries/wasi_nn/test/test_tensorflow.c

test_tensorflow: $(TEST_TENSORFLOW)

ALL_DTARGETS += test_tensorflow

#
# target tagion/iwasm/libraries/wasi_nn/wasi_nn_native.d
#
C_WASI_NN_NATIVE := tagion/iwasm/libraries/wasi_nn/wasi_nn_native.c
TARGET_CFILES += tagion/iwasm/libraries/wasi_nn/wasi_nn_native.c
WASI_NN_NATIVE := tagion/iwasm/libraries/wasi_nn/wasi_nn_native.d
TARGET_DFILES += tagion/iwasm/libraries/wasi_nn/wasi_nn_native.d

tagion/iwasm/libraries/wasi_nn/wasi_nn_native.c: ../wasm-micro-runtime/core/iwasm/libraries/wasi-nn/wasi_nn_native.c

tagion/iwasm/libraries/wasi_nn/wasi_nn_native.d: tagion/iwasm/libraries/wasi_nn/wasi_nn_native.c

wasi_nn_native: $(WASI_NN_NATIVE)

ALL_DTARGETS += wasi_nn_native

#
# target tagion/iwasm/libraries/libc_emcc/libc_emcc_wrapper.d
#
C_LIBC_EMCC_WRAPPER := tagion/iwasm/libraries/libc_emcc/libc_emcc_wrapper.c
TARGET_CFILES += tagion/iwasm/libraries/libc_emcc/libc_emcc_wrapper.c
LIBC_EMCC_WRAPPER := tagion/iwasm/libraries/libc_emcc/libc_emcc_wrapper.d
TARGET_DFILES += tagion/iwasm/libraries/libc_emcc/libc_emcc_wrapper.d

tagion/iwasm/libraries/libc_emcc/libc_emcc_wrapper.c: ../wasm-micro-runtime/core/iwasm/libraries/libc-emcc/libc_emcc_wrapper.c

tagion/iwasm/libraries/libc_emcc/libc_emcc_wrapper.d: tagion/iwasm/libraries/libc_emcc/libc_emcc_wrapper.c

libc_emcc_wrapper: $(LIBC_EMCC_WRAPPER)

ALL_DTARGETS += libc_emcc_wrapper

