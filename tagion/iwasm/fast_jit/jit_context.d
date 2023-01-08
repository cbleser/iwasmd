module tagion.iwasm.fast_jit.jit_context;
@nogc:
nothrow:
import core.stdc.stdint : uintptr_t;
import core.stdc.stdarg : va_list;
import tagion.iwasm.fast_jit.jit_ir;
import tagion.iwasm.fast_jit.jit_frame;
import tagion.iwasm.fast_jit.jit_utils;

import tagion.iwasm.interpreter.wasm : WASMModule, WASMFunction;
import tagion.iwasm.share.utils.bh_assert;
enum ErrorCode : int {
    None,
    Stack_Overflow,
}

struct Error {
    enum MSG_MAX_SIZE = 128;
    import core.sys.posix.setjmp;

    jmp_buf jmp_err;
    size_t line;
    string file;
    static char[MSG_MAX_SIZE] error_msg;
    void opCall(ErrorCode err, string msg, string file = __FILE__, const size_t line = __LINE__) {
        const len = min(error_msg.length, msg.length);
        error_msg[0 .. len] = msg[0 .. len];
        this.line = line;
        this.file = file;
        longjmp(jmp_err, cast(int) err);
    }

    int setError() {
        return setjmp(jmp_err);
    }
}
//bool pop_value(ubyte type, JitReg* p_value) {
//    return pop_value(type, p_value);
//}

/**
 * The JIT compilation context for one compilation process of a
 * compilation unit.
 */
struct JitCompContext {
@nogc:
nothrow:
    private bool pop_value(ubyte type, JitReg* p_value) {
        JitValue* jit_value = null;
        JitReg value = 0;
        if (!jit_block_stack_top(&block_stack)) {
            jit_set_last_error("WASM block stack underflow");
            return false;
        }
        if (!jit_block_stack_top(&block_stack).value_stack.value_list_end) {
            jit_set_last_error("WASM data stack underflow");
            return false;
        }
        jit_value = jit_value_stack_pop(

                &jit_block_stack_top(&block_stack).value_stack);
        bh_assert(jit_value !is null);
        if (jit_value.type != to_stack_value_type(type)) {
            jit_set_last_error("invalid WASM stack data type");
            jit_free(jit_value);
            return false;
        }
        switch (jit_value.type) {
        case VALUE_TYPE_I32:
            value = jit_frame.pop_i32;
            break;
        case VALUE_TYPE_I64:
            value = jit_frame.pop_i64;
            break;
        case VALUE_TYPE_F32:
            value = jit_frame.pop_f32;
            break;
        case VALUE_TYPE_F64:
            value = jit_frame.pop_f64;
            break;
        default:
            bh_assert(0);
            break;
        }
        bh_assert(jit_frame.sp == jit_value.value);
        bh_assert(value == jit_value.value.reg);

        *p_value = value;
        jit_free(jit_value);
        return true;
    }

    /*
	Returns: true on fail
*/

    bool pop_i32(ref JitReg value) {
        return !pop_value(VALUE_TYPE_I32, &value);
    }
    /* Error long-jumper */
    private Error _error;
    void error(ErrorCode err, string msg, string file = __FILE__, const size_t line = __LINE__) {
        _error(err, msg, file, line);
    }
    /* Hard register information of each kind. */
    const(JitHardRegInfo)* hreg_info;
    /* No. of the pass to be applied. */
    ubyte cur_pass_no;
    /* The current wasm module */
    WASMModule* cur_wasm_module;
    /* The current wasm function */
    WASMFunction* cur_wasm_func;
    /* The current wasm function index */
    uint cur_wasm_func_idx;
    /* The block stack */
    JitBlockStack block_stack;
    bool mem_space_unchanged;
    /* Entry and exit labels of the compilation unit, whose numbers must
       be 0 and 1 respectively (see JIT_FOREACH_BLOCK). */
    JitReg entry_label;
    JitReg exit_label;
    JitBasicBlock** exce_basic_blocks;
    JitIncomingInsnList* incoming_insns_for_exec_bbs;
    /* The current basic block to generate instructions */
    JitBasicBlock* cur_basic_block;
    /* Registers of frame pointer, exec_env and CMP result. */
    JitReg fp_reg;
    JitReg exec_env_reg;
    JitReg cmp_reg;
    /* WASM module instance */
    JitReg module_inst_reg;
    /* WASM module */
    JitReg module_reg;
    /* module_inst->import_func_ptrs */
    JitReg import_func_ptrs_reg;
    /* module_inst->fast_jit_func_ptrs */
    JitReg fast_jit_func_ptrs_reg;
    /* module_inst->func_type_indexes */
    JitReg func_type_indexes_reg;
    /* Boundary of auxiliary stack */
    JitReg aux_stack_bound_reg;
    /* Bottom of auxiliary stack */
    JitReg aux_stack_bottom_reg;
    /* Data of memory instances */
    JitMemRegs* memory_regs;
    /* Data of table instances */
    JitTableRegs* table_regs;
    /* Current frame information for translation */
    JitFrame* jit_frame;
    /* The total frame size of current function */
    uint total_frame_size;
    /* The spill cache offset to the interp frame */
    uint spill_cache_offset;
    /* The spill cache size */
    uint spill_cache_size;
    /* The offset of jitted_return_address in the frame, which is set by
       the pass frontend and used by the pass codegen. */
    uint jitted_return_address_offset;
    /* Begin and end addresses of the jitted code produced by the pass
       codegen and consumed by the region registration after codegen and
       the pass dump. */
    void* jitted_addr_begin;
    void* jitted_addr_end;
    char[128] last_error = 0;
    /* Below fields are all private.  Don't access them directly. */
    /* Reference count of the compilation context. */
    ushort _reference_count;
    /* Constant values. */
    struct __const_val {
        /* Number of constant values of each kind. */
        uint[JIT_REG_KIND_L32] _num;
        /* Capacity of register annotations of each kind. */
        uint[JIT_REG_KIND_L32] _capacity;
        /* Constant vallues of each kind. */
        ubyte*[JIT_REG_KIND_L32] _value;
        /* Next element on the list of values with the same hash code. */
        JitReg*[JIT_REG_KIND_L32] _next;
        /* Size of the hash table. */
        uint _hash_table_size;
        /* Map values to JIT register. */
        JitReg* _hash_table;
    }

    __const_val _const_val;
    /* Annotations of labels, registers and instructions. */
    struct __ann {
        /* Number of all ever created labels. */
        uint _label_num;
        /* Capacity of label annotations. */
        uint _label_capacity;
        /* Number of all ever created instructions. */
        uint _insn_num;
        /* Capacity of instruction annotations. */
        uint _insn_capacity;
        /* Number of ever created registers of each kind. */
        uint[JIT_REG_KIND_L32] _reg_num;
        /* Capacity of register annotations of each kind. */
        uint[JIT_REG_KIND_L32] _reg_capacity;
        /* Storage of annotations. */
        /*
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
        /**
 * @file   jit-ir.def
 *
 * @brief  Definition of JIT IR instructions and annotations.
 */
        /**
 * @def INSN (NAME, OPND_KIND, OPND_NUM, FIRST_USE)
 *
 * Definition of IR instructions
 *
 * @param NAME name of the opcode
 * @param OPND_KIND kind of the operand(s)
 * @param OPND_NUM number of the operand(s)
 * @param FIRST_USE index of the first use register
 *
 * @p OPND_KIND and @p OPND_NUM together determine the format of an
 * instruction.  There are four kinds of formats:
 *
 * 1) Reg: fixed-number register operands, @p OPND_NUM specifies the
 * number of operands;
 *
 * 2) VReg: variable-number register operands, @p OPND_NUM specifies
 * the number of fixed register operands;
 *
 * 3) TableSwitch: tableswitch instruction's format, @p OPND_NUM must
 * be 1;
 *
 * 4) LookupSwitch: lookupswitch instruction's format, @p OPND_NUM
 * must be 1.
 *
 * Instruction operands are all registers and they are organized in an
 * order that all registers defined by the instruction, if any, appear
 * before the registers used by the instruction. The @p FIRST_USE is
 * the index of the first use register in the register vector sorted
 * in this order. Use @c jit_insn_opnd_regs to get the register
 * vector in this order and use @c jit_insn_opnd_first_use to get the
 * index of the first use register.
 *
 * Every instruction with name @p NAME has the following definitions:
 *
 * @c JEFF_OP_NAME: the enum opcode of insn NAME
 * @c jit_insn_new_NAME (...): creates a new instance of insn NAME
 *
 * An instruction is deleted by function:
 *
 * @c jit_insn_delete (@p insn)
 *
 * In the scope of this IR's terminology, operand and argument have
 * different meanings. The operand is a general notation, which
 * denotes every raw operand of an instruction, while the argument
 * only denotes the variable part of operands of instructions of VReg
 * kind. For example, a VReg instruction phi node "r0 = phi(r1, r2)"
 * has three operands opnd[0]: r0, opnd[1]: r1 and opnd[2]: r2, but
 * only two arguments arg[0]: r1 and arg[1]: r2.  Operands or
 * arguments of instructions with various formats can be access
 * through the following APIs:
 *
 * @c jit_insn_opnd (@p insn, @p n): for Reg_N formats
 * @c jit_insn_opndv (@p insn, @p n): for VReg_N formats
 * @c jit_insn_opndv_num (@p insn): for VReg_N formats
 * @c jit_insn_opndts (@p insn): for TableSwitch_1 format
 * @c jit_insn_opndls (@p insn): for LookupSwitch_1 format
 */
        /* Move and conversion instructions that transfer values among
   registers of the same kind (move) or different kinds (convert) */

        /* conversion. will extend or truncate */

        /**
 * Re-interpret binary presentations:
 *   *(i32 *)&f32, *(i64 *)&f64, *(f32 *)&i32, *(f64 *)&i64
 */

        /* Arithmetic and bitwise instructions: */

        /* Select instruction: */

        /* Memory access instructions: */

        /* Control instructions */

        /* Call and return instructions */

        /**
 * @def ANN_LABEL (TYPE, NAME)
 *
 * Definition of label annotations.
 *
 * @param TYPE type of the annotation
 * @param NAME name of the annotation
 *
 * Each defined annotation with name NAME has the following APIs:
 *
 * @c jit_annl_NAME (cc, label): accesses the annotation NAME of
 * label @p label
 * @c jit_annl_enable_NAME (cc): enables the annotation NAME
 * @c jit_annl_disable_NAME (cc): disables the annotation NAME
 * @c jit_annl_is_enabled_NAME (cc): check whether the annotation NAME
 * is enabled
 */
        /* Basic Block of a label.  */
        JitBasicBlock** _label_basic_block;
        /* Predecessor number of the block that is only used in
   update_cfg for updating the CFG.  */
        ushort* _label_pred_num;
        /* Execution frequency of a block.  We can split critical edges with
   empty blocks so we don't need to store frequencies of edges.  */
        ushort* _label_freq;
        /* Begin bytecode instruction pointer of the block.  */
        ubyte** _label_begin_bcip;
        /* End bytecode instruction pointer of the block.  */
        ubyte** _label_end_bcip;
        /* Stack pointer offset at the end of the block.  */
        ushort* _label_end_sp;
        /* The label of the next physically adjacent block.  */
        JitReg* _label_next_label;
        /* Compiled code address of the block.  */
        void** _label_jitted_addr;
        /**
 * @def ANN_INSN (TYPE, NAME)
 *
 * Definition of instruction annotations.
 *
 * @param TYPE type of the annotation
 * @param NAME name of the annotation
 *
 * Each defined annotation with name NAME has the following APIs:
 *
 * @c jit_anni_NAME (cc, insn): accesses the annotation NAME of
 * instruction @p insn
 * @c jit_anni_enable_NAME (cc): enables the annotation NAME
 * @c jit_anni_disable_NAME (cc): disables the annotation NAME
 * @c jit_anni_is_enabled_NAME (cc): check whether the annotation NAME
 * is enabled
 */
        /* A annotation for linking instructions with the same hash
   value, which is only used by the compilation context's hash table
   of instructions.  */
        JitInsn** _insn__hash_link;
        /**
 * @def ANN_REG (TYPE, NAME)
 *
 * Definition of register annotations.
 *
 * @param TYPE type of the annotation
 * @param NAME name of the annotation
 *
 * Each defined annotation with name NAME has the following APIs:
 *
 * @c jit_annr_NAME (cc, reg): accesses the annotation NAME of
 * register @p reg
 * @c jit_annr_enable_NAME (cc): enables the annotation NAME
 * @c jit_annr_disable_NAME (cc): disables the annotation NAME
 * @c jit_annr_is_enabled_NAME (cc): check whether the annotation NAME
 * is enabled
 */
        /* Defining instruction of registers satisfying SSA property.  */
pragma(msg, "fixed(cbr): changed from JitInsn**[JIT_REG_KIND_L32] JitInsn*[JIT_REG_KIND_L32]"); 
JitInsn*[JIT_REG_KIND_L32] _reg_def_insn;
        /* Flags of annotations. */
        /*
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
        /**
 * @file   jit-ir.def
 *
 * @brief  Definition of JIT IR instructions and annotations.
 */
        /**
 * @def INSN (NAME, OPND_KIND, OPND_NUM, FIRST_USE)
 *
 * Definition of IR instructions
 *
 * @param NAME name of the opcode
 * @param OPND_KIND kind of the operand(s)
 * @param OPND_NUM number of the operand(s)
 * @param FIRST_USE index of the first use register
 *
 * @p OPND_KIND and @p OPND_NUM together determine the format of an
 * instruction.  There are four kinds of formats:
 *
 * 1) Reg: fixed-number register operands, @p OPND_NUM specifies the
 * number of operands;
 *
 * 2) VReg: variable-number register operands, @p OPND_NUM specifies
 * the number of fixed register operands;
 *
 * 3) TableSwitch: tableswitch instruction's format, @p OPND_NUM must
 * be 1;
 *
 * 4) LookupSwitch: lookupswitch instruction's format, @p OPND_NUM
 * must be 1.
 *
 * Instruction operands are all registers and they are organized in an
 * order that all registers defined by the instruction, if any, appear
 * before the registers used by the instruction. The @p FIRST_USE is
 * the index of the first use register in the register vector sorted
 * in this order. Use @c jit_insn_opnd_regs to get the register
 * vector in this order and use @c jit_insn_opnd_first_use to get the
 * index of the first use register.
 *
 * Every instruction with name @p NAME has the following definitions:
 *
 * @c JEFF_OP_NAME: the enum opcode of insn NAME
 * @c jit_insn_new_NAME (...): creates a new instance of insn NAME
 *
 * An instruction is deleted by function:
 *
 * @c jit_insn_delete (@p insn)
 *
 * In the scope of this IR's terminology, operand and argument have
 * different meanings. The operand is a general notation, which
 * denotes every raw operand of an instruction, while the argument
 * only denotes the variable part of operands of instructions of VReg
 * kind. For example, a VReg instruction phi node "r0 = phi(r1, r2)"
 * has three operands opnd[0]: r0, opnd[1]: r1 and opnd[2]: r2, but
 * only two arguments arg[0]: r1 and arg[1]: r2.  Operands or
 * arguments of instructions with various formats can be access
 * through the following APIs:
 *
 * @c jit_insn_opnd (@p insn, @p n): for Reg_N formats
 * @c jit_insn_opndv (@p insn, @p n): for VReg_N formats
 * @c jit_insn_opndv_num (@p insn): for VReg_N formats
 * @c jit_insn_opndts (@p insn): for TableSwitch_1 format
 * @c jit_insn_opndls (@p insn): for LookupSwitch_1 format
 */
        /* Move and conversion instructions that transfer values among
   registers of the same kind (move) or different kinds (convert) */

        /* conversion. will extend or truncate */

        /**
 * Re-interpret binary presentations:
 *   *(i32 *)&f32, *(i64 *)&f64, *(f32 *)&i32, *(f64 *)&i64
 */

        /* Arithmetic and bitwise instructions: */

        /* Select instruction: */

        /* Memory access instructions: */

        /* Control instructions */

        /* Call and return instructions */

        /**
 * @def ANN_LABEL (TYPE, NAME)
 *
 * Definition of label annotations.
 *
 * @param TYPE type of the annotation
 * @param NAME name of the annotation
 *
 * Each defined annotation with name NAME has the following APIs:
 *
 * @c jit_annl_NAME (cc, label): accesses the annotation NAME of
 * label @p label
 * @c jit_annl_enable_NAME (cc): enables the annotation NAME
 * @c jit_annl_disable_NAME (cc): disables the annotation NAME
 * @c jit_annl_is_enabled_NAME (cc): check whether the annotation NAME
 * is enabled
 */
        /* Basic Block of a label.  */
        uint _label_basic_block_enabled; /*: 1 !!*/
        /* Predecessor number of the block that is only used in
   update_cfg for updating the CFG.  */
        uint _label_pred_num_enabled; /*: 1 !!*/
        /* Execution frequency of a block.  We can split critical edges with
   empty blocks so we don't need to store frequencies of edges.  */
        uint _label_freq_enabled; /*: 1 !!*/
        /* Begin bytecode instruction pointer of the block.  */
        uint _label_begin_bcip_enabled; /*: 1 !!*/
        /* End bytecode instruction pointer of the block.  */
        uint _label_end_bcip_enabled; /*: 1 !!*/
        /* Stack pointer offset at the end of the block.  */
        uint _label_end_sp_enabled; /*: 1 !!*/
        /* The label of the next physically adjacent block.  */
        uint _label_next_label_enabled; /*: 1 !!*/
        /* Compiled code address of the block.  */
        uint _label_jitted_addr_enabled; /*: 1 !!*/
        /**
 * @def ANN_INSN (TYPE, NAME)
 *
 * Definition of instruction annotations.
 *
 * @param TYPE type of the annotation
 * @param NAME name of the annotation
 *
 * Each defined annotation with name NAME has the following APIs:
 *
 * @c jit_anni_NAME (cc, insn): accesses the annotation NAME of
 * instruction @p insn
 * @c jit_anni_enable_NAME (cc): enables the annotation NAME
 * @c jit_anni_disable_NAME (cc): disables the annotation NAME
 * @c jit_anni_is_enabled_NAME (cc): check whether the annotation NAME
 * is enabled
 */
        /* A annotation for linking instructions with the same hash
   value, which is only used by the compilation context's hash table
   of instructions.  */
        uint _insn__hash_link_enabled; /*: 1 !!*/
        /**
 * @def ANN_REG (TYPE, NAME)
 *
 * Definition of register annotations.
 *
 * @param TYPE type of the annotation
 * @param NAME name of the annotation
 *
 * Each defined annotation with name NAME has the following APIs:
 *
 * @c jit_annr_NAME (cc, reg): accesses the annotation NAME of
 * register @p reg
 * @c jit_annr_enable_NAME (cc): enables the annotation NAME
 * @c jit_annr_disable_NAME (cc): disables the annotation NAME
 * @c jit_annr_is_enabled_NAME (cc): check whether the annotation NAME
 * is enabled
 */
        /* Defining instruction of registers satisfying SSA property.  */
        uint _reg_def_insn_enabled; /*: 1 !!*/
    }

    __ann _ann;
    /* Instruction hash table. */
    struct __insn_hash_table {
        /* Size of the hash table. */
        uint _size;
        /* The hash table. */
        JitInsn** _table;
    }

    __insn_hash_table _insn_hash_table;
    /* indicate if the last comparision is about floating-point numbers or not
     */
    bool last_cmp_on_fp;
    bool push_value(ubyte type, JitReg value) {
        JitValue* jit_value = void;
        if (!jit_block_stack_top(&block_stack)) {
            jit_set_last_error("WASM block stack underflow");
            return false;
        }
        if (((jit_value = jit_calloc_value(JitValue.sizeof)) is null)) {
            jit_set_last_error("allocate memory failed");
            return false;
        }
        bh_assert(value);
        jit_value.type = to_stack_value_type(type);
        jit_value.value = jit_frame.sp;
        jit_value_stack_push(&jit_block_stack_top(&block_stack).value_stack,
                jit_value);
        switch (jit_value.type) {
        case VALUE_TYPE_I32:
            jit_frame.push_i32(value);
            break;
        case VALUE_TYPE_I64:
            jit_frame.push_i64(value);
            break;
        case VALUE_TYPE_F32:
            jit_frame.push_f32(value);
            break;
        case VALUE_TYPE_F64:
            jit_frame.push_f64(value);
            break;
        default:
            break;
        }
        return true;
    }

    void jit_set_last_error_v(const(char)* format_, va_list args) {
        va_start(args, format_);
        vsnprintf(last_error.ptr, last_error.length, format_, args);
        va_end(args);
    }

    void jit_set_last_error(const(char)* error) {
        if (error) {
            snprintf(last_error.ptr, last_error.length, "Error: %s", error);
        }
        last_error[0] = '\0';
    }
    /**
 * Create a new instruction in the compilation context and normalize
 * the instruction (constant folding and simplification etc.). If the
 * instruction hashing is enabled (anni__hash_link is enabled), try to
 * find the existing equivalent insruction first before adding a new
 * one to the compilation contest.
 *
 * @param cc the compilationo context
 * @param result returned result of the instruction. If the value is
 * non-zero, it is the result of the constant-folding or an exsiting
 * equivalent instruction, in which case no instruction is added into
 * the compilation context. Otherwise, a new normalized instruction
 * has been added into the compilation context.
 * @param NAME instruction name
 *
 * @return a new or existing instruction in the compilation context
 */
    /**
 * Helper function for GEN_INSN
 *
 * @param cc compilation context
 * @param block the current block
 * @param insn the new instruction
 *
 * @return the new instruction if inserted, NULL otherwise
 */
    JitInsn* _gen_insn(JitInsn* insn) {
        if (insn)
            jit_basic_block_append_insn(cur_basic_block, insn);
        else
            jit_set_last_error("generate insn failed");
        return insn;
    }
    /**
 * Generate and append an instruction to the current block.
 */
    /**
 * Create a constant register without relocation info.
 *
 * @param Type type of the register
 * @param val the constant value
 *
 * @return the constant register if succeeds, 0 otherwise
 */
    /**
 * Create a new virtual register in the compilation context.
 *
 * @param cc the compilation context
 * @param kind kind of the register
 *
 * @return a new label in the compilation context
 */
    //    JitReg new_reg(uint kind);
    /*
 * Create virtual registers with specific types in the compilation
 * context. They are more convenient than the above one.
 */
    JitReg new_reg_I32() {
        return new_reg(JIT_REG_KIND_I32);
    }

    JitReg new_reg_I64() {
        return new_reg(JIT_REG_KIND_I64);
    }

    static if (uintptr_t.max == ulong.max) {
        alias new_reg_ptr = new_reg_I64;
    }
    else {
        alias new_reg_ptr = new_reg_I32;
    }
    JitReg new_reg_F32() {
        return new_reg(JIT_REG_KIND_F32);
    }

    JitReg new_reg_F64() {
        return new_reg(JIT_REG_KIND_F64);
    }

    JitReg new_reg_V64() {
        return new_reg(JIT_REG_KIND_V64);
    }

    JitReg new_reg_V128() {
        return new_reg(JIT_REG_KIND_V128);
    }

    JitReg new_reg_V256() {
        return new_reg(JIT_REG_KIND_V256);
    }
    /**
 * Get the hard register numbe of the given kind
 *
 * @param cc the compilation context
 * @param kind the register kind
 *
 * @return number of hard registers of the given kind
 */
    uint hreg_num(uint kind) {
        bh_assert(kind < JIT_REG_KIND_L32);
        return hreg_info.info[kind].num;
    }
    /**
 * Check whether a given register is a hard register.
 *
 * @param cc the compilation context
 * @param reg the register which must be a variable
 *
 * @return true if the register is a hard register
 */
    bool is_hreg(JitReg reg) {
        uint kind = jit_reg_kind(reg);
        uint no = jit_reg_no(reg);
        bh_assert(jit_reg_is_variable(reg));
        return no < hreg_info.info[kind].num;
    }
    /**
 * Check whether the given hard register is fixed.
 *
 * @param cc the compilation context
 * @param reg the hard register
 *
 * @return true if the hard register is fixed
 */
    bool is_hreg_fixed(JitReg reg) {
        uint kind = jit_reg_kind(reg);
        uint no = jit_reg_no(reg);
        bh_assert(is_hreg(reg));
        return !!hreg_info.info[kind].fixed[no];
    }
    /**
 * Check whether the given hard register is caller-saved-native.
 *
 * @param cc the compilation context
 * @param reg the hard register
 *
 * @return true if the hard register is caller-saved-native
 */
    bool is_hreg_caller_saved_native(JitReg reg) {
        uint kind = jit_reg_kind(reg);
        uint no = jit_reg_no(reg);
        bh_assert(is_hreg(reg));
        return !!hreg_info.info[kind].caller_saved_native[no];
    }
    /**
 * Check whether the given hard register is caller-saved-jitted.
 *
 * @param cc the compilation context
 * @param reg the hard register
 *
 * @return true if the hard register is caller-saved-jitted
 */
    bool is_hreg_caller_saved_jitted(JitReg reg) {
        uint kind = jit_reg_kind(reg);
        uint no = jit_reg_no(reg);
        bh_assert(is_hreg(reg));
        return !!hreg_info.info[kind].caller_saved_jitted[no];
    }
    /**
 * Return the entry block of the compilation context.
 *
 * @param cc the compilation context
 *
 * @return the entry block of the compilation context
 */
    JitBasicBlock* entry_basic_block() {
        return *(jit_annl_basic_block(entry_label));
    }
    /**
 * Return the exit block of the compilation context.
 *
 * @param cc the compilation context
 *
 * @return the exit block of the compilation context
 */
    JitBasicBlock* exit_basic_block() {
        return *(jit_annl_basic_block(exit_label));
    }

    JitReg new_reg(uint kind) {
        uint num = reg_num(kind);
        uint capacity = _ann._reg_capacity[kind];
        bool successful = true;
        bh_assert(num <= capacity);
        if (num == capacity) {
            capacity = (capacity == 0 /* Initialize the capacity to be larger than hard
                           register number.  */
                    ? hreg_info.info[kind].num + 16 : capacity + capacity / 2);
            /*
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
            /**
 * @file   jit-ir.def
 *
 * @brief  Definition of JIT IR instructions and annotations.
 */
            /**
 * @def INSN (NAME, OPND_KIND, OPND_NUM, FIRST_USE)
 *
 * Definition of IR instructions
 *
 * @param NAME name of the opcode
 * @param OPND_KIND kind of the operand(s)
 * @param OPND_NUM number of the operand(s)
 * @param FIRST_USE index of the first use register
 *
 * @p OPND_KIND and @p OPND_NUM together determine the format of an
 * instruction.  There are four kinds of formats:
 *
 * 1) Reg: fixed-number register operands, @p OPND_NUM specifies the
 * number of operands;
 *
 * 2) VReg: variable-number register operands, @p OPND_NUM specifies
 * the number of fixed register operands;
 *
 * 3) TableSwitch: tableswitch instruction's format, @p OPND_NUM must
 * be 1;
 *
 * 4) LookupSwitch: lookupswitch instruction's format, @p OPND_NUM
 * must be 1.
 *
 * Instruction operands are all registers and they are organized in an
 * order that all registers defined by the instruction, if any, appear
 * before the registers used by the instruction. The @p FIRST_USE is
 * the index of the first use register in the register vector sorted
 * in this order. Use @c jit_insn_opnd_regs to get the register
 * vector in this order and use @c jit_insn_opnd_first_use to get the
 * index of the first use register.
 *
 * Every instruction with name @p NAME has the following definitions:
 *
 * @c JEFF_OP_NAME: the enum opcode of insn NAME
 * @c jit_insn_new_NAME (...): creates a new instance of insn NAME
 *
 * An instruction is deleted by function:
 *
 * @c jit_insn_delete (@p insn)
 *
 * In the scope of this IR's terminology, operand and argument have
 * different meanings. The operand is a general notation, which
 * denotes every raw operand of an instruction, while the argument
 * only denotes the variable part of operands of instructions of VReg
 * kind. For example, a VReg instruction phi node "r0 = phi(r1, r2)"
 * has three operands opnd[0]: r0, opnd[1]: r1 and opnd[2]: r2, but
 * only two arguments arg[0]: r1 and arg[1]: r2.  Operands or
 * arguments of instructions with various formats can be access
 * through the following APIs:
 *
 * @c jit_insn_opnd (@p insn, @p n): for Reg_N formats
 * @c jit_insn_opndv (@p insn, @p n): for VReg_N formats
 * @c jit_insn_opndv_num (@p insn): for VReg_N formats
 * @c jit_insn_opndts (@p insn): for TableSwitch_1 format
 * @c jit_insn_opndls (@p insn): for LookupSwitch_1 format
 */
            /* Move and conversion instructions that transfer values among
   registers of the same kind (move) or different kinds (convert) */
            /* conversion. will extend or truncate */
            /**
 * Re-interpret binary presentations:
 *   *(i32 *)&f32, *(i64 *)&f64, *(f32 *)&i32, *(f64 *)&i64
 */
            /* Arithmetic and bitwise instructions: */
            /* Select instruction: */
            /* Memory access instructions: */
            /* Control instructions */
            /* Call and return instructions */
            /**
 * @def ANN_LABEL (TYPE, NAME)
 *
 * Definition of label annotations.
 *
 * @param TYPE type of the annotation
 * @param NAME name of the annotation
 *
 * Each defined annotation with name NAME has the following APIs:
 *
 * @c jit_annl_NAME (cc, label): accesses the annotation NAME of
 * label @p label
 * @c jit_annl_enable_NAME (cc): enables the annotation NAME
 * @c jit_annl_disable_NAME (cc): disables the annotation NAME
 * @c jit_annl_is_enabled_NAME (cc): check whether the annotation NAME
 * is enabled
 */
            /* Basic Block of a label.  */
            /* Predecessor number of the block that is only used in
   update_cfg for updating the CFG.  */
            /* Execution frequency of a block.  We can split critical edges with
   empty blocks so we don't need to store frequencies of edges.  */
            /* Begin bytecode instruction pointer of the block.  */
            /* End bytecode instruction pointer of the block.  */
            /* Stack pointer offset at the end of the block.  */
            /* The label of the next physically adjacent block.  */
            /* Compiled code address of the block.  */
            /**
 * @def ANN_INSN (TYPE, NAME)
 *
 * Definition of instruction annotations.
 *
 * @param TYPE type of the annotation
 * @param NAME name of the annotation
 *
 * Each defined annotation with name NAME has the following APIs:
 *
 * @c jit_anni_NAME (cc, insn): accesses the annotation NAME of
 * instruction @p insn
 * @c jit_anni_enable_NAME (cc): enables the annotation NAME
 * @c jit_anni_disable_NAME (cc): disables the annotation NAME
 * @c jit_anni_is_enabled_NAME (cc): check whether the annotation NAME
 * is enabled
 */
            /* A private annotation for linking instructions with the same hash
   value, which is only used by the compilation context's hash table
   of instructions.  */
            /**
 * @def ANN_REG (TYPE, NAME)
 *
 * Definition of register annotations.
 *
 * @param TYPE type of the annotation
 * @param NAME name of the annotation
 *
 * Each defined annotation with name NAME has the following APIs:
 *
 * @c jit_annr_NAME (cc, reg): accesses the annotation NAME of
 * register @p reg
 * @c jit_annr_enable_NAME (cc): enables the annotation NAME
 * @c jit_annr_disable_NAME (cc): disables the annotation NAME
 * @c jit_annr_is_enabled_NAME (cc): check whether the annotation NAME
 * is enabled
 */
            /* Defining instruction of registers satisfying SSA property.  */
            if (successful && _ann._reg_def_insn_enabled) {
			pragma(msg, typeof(_ann._reg_def_insn[kind]));
			pragma(msg, typeof(_ann._reg_def_insn));
                JitInsn* ptr = jit_realloc(_ann._reg_def_insn[kind], JitInsn.sizeof * capacity, JitInsn.sizeof * num);
                if (ptr)
                    _ann._reg_def_insn[kind] = ptr;
                else
                    successful = false;
            }
            if (!successful) {
                jit_set_last_error("create register failed");
                return 0;
            }
            _ann._reg_capacity[kind] = capacity;
        }
        _ann._reg_num[kind] = num + 1;
        return jit_reg_new(kind, num);
    }
    /*
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
    /**
 * @file   jit-ir.def
 *
 * @brief  Definition of JIT IR instructions and annotations.
 */
    /**
 * @def INSN (NAME, OPND_KIND, OPND_NUM, FIRST_USE)
 *
 * Definition of IR instructions
 *
 * @param NAME name of the opcode
 * @param OPND_KIND kind of the operand(s)
 * @param OPND_NUM number of the operand(s)
 * @param FIRST_USE index of the first use register
 *
 * @p OPND_KIND and @p OPND_NUM together determine the format of an
 * instruction.  There are four kinds of formats:
 *
 * 1) Reg: fixed-number register operands, @p OPND_NUM specifies the
 * number of operands;
 *
 * 2) VReg: variable-number register operands, @p OPND_NUM specifies
 * the number of fixed register operands;
 *
 * 3) TableSwitch: tableswitch instruction's format, @p OPND_NUM must
 * be 1;
 *
 * 4) LookupSwitch: lookupswitch instruction's format, @p OPND_NUM
 * must be 1.
 *
 * Instruction operands are all registers and they are organized in an
 * order that all registers defined by the instruction, if any, appear
 * before the registers used by the instruction. The @p FIRST_USE is
 * the index of the first use register in the register vector sorted
 * in this order. Use @c jit_insn_opnd_regs to get the register
 * vector in this order and use @c jit_insn_opnd_first_use to get the
 * index of the first use register.
 *
 * Every instruction with name @p NAME has the following definitions:
 *
 * @c JEFF_OP_NAME: the enum opcode of insn NAME
 * @c jit_insn_new_NAME (...): creates a new instance of insn NAME
 *
 * An instruction is deleted by function:
 *
 * @c jit_insn_delete (@p insn)
 *
 * In the scope of this IR's terminology, operand and argument have
 * different meanings. The operand is a general notation, which
 * denotes every raw operand of an instruction, while the argument
 * only denotes the variable part of operands of instructions of VReg
 * kind. For example, a VReg instruction phi node "r0 = phi(r1, r2)"
 * has three operands opnd[0]: r0, opnd[1]: r1 and opnd[2]: r2, but
 * only two arguments arg[0]: r1 and arg[1]: r2.  Operands or
 * arguments of instructions with various formats can be access
 * through the following APIs:
 *
 * @c jit_insn_opnd (@p insn, @p n): for Reg_N formats
 * @c jit_insn_opndv (@p insn, @p n): for VReg_N formats
 * @c jit_insn_opndv_num (@p insn): for VReg_N formats
 * @c jit_insn_opndts (@p insn): for TableSwitch_1 format
 * @c jit_insn_opndls (@p insn): for LookupSwitch_1 format
 */
    /* Move and conversion instructions that transfer values among
   registers of the same kind (move) or different kinds (convert) */
    /* conversion. will extend or truncate */
    /**
 * Re-interpret binary presentations:
 *   *(i32 *)&f32, *(i64 *)&f64, *(f32 *)&i32, *(f64 *)&i64
 */
    /* Arithmetic and bitwise instructions: */
    /* Select instruction: */
    /* Memory access instructions: */
    /* Control instructions */
    /* Call and return instructions */
    /**
 * @def ANN_LABEL (TYPE, NAME)
 *
 * Definition of label annotations.
 *
 * @param TYPE type of the annotation
 * @param NAME name of the annotation
 *
 * Each defined annotation with name NAME has the following APIs:
 *
 * @c jit_annl_NAME (cc, label): accesses the annotation NAME of
 * label @p label
 * @c jit_annl_enable_NAME (cc): enables the annotation NAME
 * @c jit_annl_disable_NAME (cc): disables the annotation NAME
 * @c jit_annl_is_enabled_NAME (cc): check whether the annotation NAME
 * is enabled
 */
    /**
 * @def ANN_LABEL (TYPE, NAME)
 *
 * Definition of label annotations.
 *
 * @param TYPE type of the annotation
 * @param NAME name of the annotation
 *
 * Each defined annotation with name NAME has the following APIs:
 *
 * @c jit_annl_NAME (cc, label): accesses the annotation NAME of
 * label @p label
 * @c jit_annl_enable_NAME (cc): enables the annotation NAME
 * @c jit_annl_disable_NAME (cc): disables the annotation NAME
 * @c jit_annl_is_enabled_NAME (cc): check whether the annotation NAME
 * is enabled
 */
    /* Basic Block of a label.  */
    JitBasicBlock** jit_annl_basic_block(JitReg label) {
        uint idx = jit_reg_no(label);
        bh_assert(jit_reg_kind(label) == JIT_REG_KIND_L32);
        bh_assert(idx < _ann._label_num);
        bh_assert(_ann._label_basic_block_enabled);
        return &_ann._label_basic_block[idx];
    }
    /* Predecessor number of the block that is only used in
   update_cfg for updating the CFG.  */
    ushort* jit_annl_pred_num(JitReg label) {
        uint idx = jit_reg_no(label);
        bh_assert(jit_reg_kind(label) == JIT_REG_KIND_L32);
        bh_assert(idx < _ann._label_num);
        bh_assert(_ann._label_pred_num_enabled);
        return &_ann._label_pred_num[idx];
    }
    /* Execution frequency of a block.  We can split critical edges with
   empty blocks so we don't need to store frequencies of edges.  */
    ushort* jit_annl_freq(JitReg label) {
        uint idx = jit_reg_no(label);
        bh_assert(jit_reg_kind(label) == JIT_REG_KIND_L32);
        bh_assert(idx < _ann._label_num);
        bh_assert(_ann._label_freq_enabled);
        return &_ann._label_freq[idx];
    }
    /* Begin bytecode instruction pointer of the block.  */
    ubyte** jit_annl_begin_bcip(JitReg label) {
        uint idx = jit_reg_no(label);
        bh_assert(jit_reg_kind(label) == JIT_REG_KIND_L32);
        bh_assert(idx < _ann._label_num);
        bh_assert(_ann._label_begin_bcip_enabled);
        return &_ann._label_begin_bcip[idx];
    }
    /* End bytecode instruction pointer of the block.  */
    ubyte** jit_annl_end_bcip(JitReg label) {
        uint idx = jit_reg_no(label);
        bh_assert(jit_reg_kind(label) == JIT_REG_KIND_L32);
        bh_assert(idx < _ann._label_num);
        bh_assert(_ann._label_end_bcip_enabled);
        return &_ann._label_end_bcip[idx];
    }
    /* Stack pointer offset at the end of the block.  */
    ushort* jit_annl_end_sp(JitReg label) {
        uint idx = jit_reg_no(label);
        bh_assert(jit_reg_kind(label) == JIT_REG_KIND_L32);
        bh_assert(idx < _ann._label_num);
        bh_assert(_ann._label_end_sp_enabled);
        return &_ann._label_end_sp[idx];
    }
    /* The label of the next physically adjacent block.  */
    JitReg* jit_annl_next_label(JitReg label) {
        uint idx = jit_reg_no(label);
        bh_assert(jit_reg_kind(label) == JIT_REG_KIND_L32);
        bh_assert(idx < _ann._label_num);
        bh_assert(_ann._label_next_label_enabled);
        return &_ann._label_next_label[idx];
    }
    /* Compiled code address of the block.  */
    void** jit_annl_jitted_addr(JitReg label) {
        uint idx = jit_reg_no(label);
        bh_assert(jit_reg_kind(label) == JIT_REG_KIND_L32);
        bh_assert(idx < _ann._label_num);
        bh_assert(_ann._label_jitted_addr_enabled);
        return &_ann._label_jitted_addr[idx];
    }
    /**
 * @def ANN_INSN (TYPE, NAME)
 *
 * Definition of instruction annotations.
 *
 * @param TYPE type of the annotation
 * @param NAME name of the annotation
 *
 * Each defined annotation with name NAME has the following APIs:
 *
 * @c jit_anni_NAME (cc, insn): accesses the annotation NAME of
 * instruction @p insn
 * @c jit_anni_enable_NAME (cc): enables the annotation NAME
 * @c jit_anni_disable_NAME (cc): disables the annotation NAME
 * @c jit_anni_is_enabled_NAME (cc): check whether the annotation NAME
 * is enabled
 */
    /* A annotation for linking instructions with the same hash
   value, which is only used by the compilation context's hash table
   of instructions.  */
    JitInsn** jit_anni__hash_link(JitInsn* insn) {
        uint uid = insn.uid;
        bh_assert(uid < _ann._insn_num);
        bh_assert(_ann._insn__hash_link_enabled);
        return &_ann._insn__hash_link[uid];
    }
    /**
 * @def ANN_REG (TYPE, NAME)
 *
 * Definition of register annotations.
 *
 * @param TYPE type of the annotation
 * @param NAME name of the annotation
 *
 * Each defined annotation with name NAME has the following APIs:
 *
 * @c jit_annr_NAME (cc, reg): accesses the annotation NAME of
 * register @p reg
 * @c jit_annr_enable_NAME (cc): enables the annotation NAME
 * @c jit_annr_disable_NAME (cc): disables the annotation NAME
 * @c jit_annr_is_enabled_NAME (cc): check whether the annotation NAME
 * is enabled
 */
    /* Defining instruction of registers satisfying SSA property.  */
    JitInsn** jit_annr_def_insn(JitReg reg) {
        uint kind = jit_reg_kind(reg);
        uint no = jit_reg_no(reg);
        bh_assert(kind < JIT_REG_KIND_L32);
        bh_assert(no < _ann._reg_num[kind]);
        bh_assert(_ann._reg_def_insn_enabled);
        return &_ann._reg_def_insn[kind][no];
    }
    /* Basic Block of a label.  */
    bool jit_annl_enable_basic_block() {
        if (_ann._label_basic_block_enabled)
            return true;
        if (_ann._label_capacity > 0 && ((_ann._label_basic_block = jit_calloc(_ann._label_capacity * (JitBasicBlock*)
                .sizeof)) == 0)) {
            jit_set_last_error("annl enable " ~ "basic_block" ~ "failed");
            return false;
        }
        _ann._label_basic_block_enabled = 1;
        return true;
    }
    /* Predecessor number of the block that is only used in
   update_cfg for updating the CFG.  */
    bool jit_annl_enable_pred_num() {
        if (_ann._label_pred_num_enabled)
            return true;
        if (_ann._label_capacity > 0 && ((_ann._label_pred_num = jit_calloc(_ann._label_capacity * uint16.sizeof)) == 0)) {
            jit_set_last_error("annl enable " ~ "pred_num" ~ "failed");
            return false;
        }
        _ann._label_pred_num_enabled = 1;
        return true;
    }
    /* Execution frequency of a block.  We can split critical edges with
   empty blocks so we don't need to store frequencies of edges.  */
    bool jit_annl_enable_freq() {
        if (_ann._label_freq_enabled)
            return true;
        if (_ann._label_capacity > 0 && ((_ann._label_freq = jit_calloc(_ann._label_capacity * uint16.sizeof)) == 0)) {
            jit_set_last_error("annl enable " ~ "freq" ~ "failed");
            return false;
        }
        _ann._label_freq_enabled = 1;
        return true;
    }
    /* Begin bytecode instruction pointer of the block.  */
    bool jit_annl_enable_begin_bcip() {
        if (_ann._label_begin_bcip_enabled)
            return true;
        if (_ann._label_capacity > 0 && ((_ann._label_begin_bcip = jit_calloc(_ann._label_capacity * (ubyte*)
                .sizeof)) == 0)) {
            jit_set_last_error("annl enable " ~ "begin_bcip" ~ "failed");
            return false;
        }
        _ann._label_begin_bcip_enabled = 1;
        return true;
    }
    /* End bytecode instruction pointer of the block.  */
    bool jit_annl_enable_end_bcip() {
        if (_ann._label_end_bcip_enabled)
            return true;
        if (_ann._label_capacity > 0 && ((_ann._label_end_bcip = jit_calloc(_ann._label_capacity * (ubyte*)
                .sizeof)) == 0)) {
            jit_set_last_error("annl enable " ~ "end_bcip" ~ "failed");
            return false;
        }
        _ann._label_end_bcip_enabled = 1;
        return true;
    }
    /* Stack pointer offset at the end of the block.  */
    bool jit_annl_enable_end_sp() {
        if (_ann._label_end_sp_enabled)
            return true;
        if (_ann._label_capacity > 0 && ((_ann._label_end_sp = jit_calloc(_ann._label_capacity * uint16.sizeof)) == 0)) {
            jit_set_last_error("annl enable " ~ "end_sp" ~ "failed");
            return false;
        }
        _ann._label_end_sp_enabled = 1;
        return true;
    }
    /* The label of the next physically adjacent block.  */
    bool jit_annl_enable_next_label() {
        if (_ann._label_next_label_enabled)
            return true;
        if (_ann._label_capacity > 0 && ((_ann._label_next_label = jit_calloc(_ann._label_capacity * JitReg
                .sizeof)) == 0)) {
            jit_set_last_error("annl enable " ~ "next_label" ~ "failed");
            return false;
        }
        _ann._label_next_label_enabled = 1;
        return true;
    }
    /* Compiled code address of the block.  */
    bool jit_annl_enable_jitted_addr() {
        if (_ann._label_jitted_addr_enabled)
            return true;
        if (_ann._label_capacity > 0 && ((_ann._label_jitted_addr = jit_calloc(_ann._label_capacity * (void*)
                .sizeof)) == 0)) {
            jit_set_last_error("annl enable " ~ "jitted_addr" ~ "failed");
            return false;
        }
        _ann._label_jitted_addr_enabled = 1;
        return true;
    }
    /**
 * @def ANN_INSN (TYPE, NAME)
 *
 * Definition of instruction annotations.
 *
 * @param TYPE type of the annotation
 * @param NAME name of the annotation
 *
 * Each defined annotation with name NAME has the following APIs:
 *
 * @c jit_anni_NAME (cc, insn): accesses the annotation NAME of
 * instruction @p insn
 * @c jit_anni_enable_NAME (cc): enables the annotation NAME
 * @c jit_anni_disable_NAME (cc): disables the annotation NAME
 * @c jit_anni_is_enabled_NAME (cc): check whether the annotation NAME
 * is enabled
 */
    /* A private annotation for linking instructions with the same hash
   value, which is only used by the compilation context's hash table
   of instructions.  */
    bool jit_anni_enable__hash_link() {
        if (_ann._insn__hash_link_enabled)
            return true;
        if (_ann._insn_capacity > 0 && ((_ann._insn__hash_link = jit_calloc(_ann._insn_capacity * (JitInsn*)
                .sizeof)) == 0)) {
            jit_set_last_error("anni enable " ~ "_hash_link" ~ "failed");
            return false;
        }
        _ann._insn__hash_link_enabled = 1;
        return true;
    }
    /**
 * @def ANN_REG (TYPE, NAME)
 *
 * Definition of register annotations.
 *
 * @param TYPE type of the annotation
 * @param NAME name of the annotation
 *
 * Each defined annotation with name NAME has the following APIs:
 *
 * @c jit_annr_NAME (cc, reg): accesses the annotation NAME of
 * register @p reg
 * @c jit_annr_enable_NAME (cc): enables the annotation NAME
 * @c jit_annr_disable_NAME (cc): disables the annotation NAME
 * @c jit_annr_is_enabled_NAME (cc): check whether the annotation NAME
 * is enabled
 */
    /* Defining instruction of registers satisfying SSA property.  */
    bool jit_annr_enable_def_insn() {
        uint k = void;
        if (_ann._reg_def_insn_enabled)
            return true;
        for (k = JIT_REG_KIND_VOID; k < JIT_REG_KIND_L32; k++)
            if (_ann._reg_capacity[k] > 0 && ((_ann._reg_def_insn[k] = jit_calloc(_ann._reg_capacity[k] * (JitInsn*)
            .sizeof)) == 0)) {
            jit_set_last_error("annr enable " ~ "def_insn" ~ "failed");
            jit_annr_disable_def_insn;
            return false;
        }
        _ann._reg_def_insn_enabled = 1;
        return true;
    }
    /*
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
    /**
 * @file   jit-ir.def
 *
 * @brief  Definition of JIT IR instructions and annotations.
 */
    /**
 * @def INSN (NAME, OPND_KIND, OPND_NUM, FIRST_USE)
 *
 * Definition of IR instructions
 *
 * @param NAME name of the opcode
 * @param OPND_KIND kind of the operand(s)
 * @param OPND_NUM number of the operand(s)
 * @param FIRST_USE index of the first use register
 *
 * @p OPND_KIND and @p OPND_NUM together determine the format of an
 * instruction.  There are four kinds of formats:
 *
 * 1) Reg: fixed-number register operands, @p OPND_NUM specifies the
 * number of operands;
 *
 * 2) VReg: variable-number register operands, @p OPND_NUM specifies
 * the number of fixed register operands;
 *
 * 3) TableSwitch: tableswitch instruction's format, @p OPND_NUM must
 * be 1;
 *
 * 4) LookupSwitch: lookupswitch instruction's format, @p OPND_NUM
 * must be 1.
 *
 * Instruction operands are all registers and they are organized in an
 * order that all registers defined by the instruction, if any, appear
 * before the registers used by the instruction. The @p FIRST_USE is
 * the index of the first use register in the register vector sorted
 * in this order. Use @c jit_insn_opnd_regs to get the register
 * vector in this order and use @c jit_insn_opnd_first_use to get the
 * index of the first use register.
 *
 * Every instruction with name @p NAME has the following definitions:
 *
 * @c JEFF_OP_NAME: the enum opcode of insn NAME
 * @c jit_insn_new_NAME (...): creates a new instance of insn NAME
 *
 * An instruction is deleted by function:
 *
 * @c jit_insn_delete (@p insn)
 *
 * In the scope of this IR's terminology, operand and argument have
 * different meanings. The operand is a general notation, which
 * denotes every raw operand of an instruction, while the argument
 * only denotes the variable part of operands of instructions of VReg
 * kind. For example, a VReg instruction phi node "r0 = phi(r1, r2)"
 * has three operands opnd[0]: r0, opnd[1]: r1 and opnd[2]: r2, but
 * only two arguments arg[0]: r1 and arg[1]: r2.  Operands or
 * arguments of instructions with various formats can be access
 * through the following APIs:
 *
 * @c jit_insn_opnd (@p insn, @p n): for Reg_N formats
 * @c jit_insn_opndv (@p insn, @p n): for VReg_N formats
 * @c jit_insn_opndv_num (@p insn): for VReg_N formats
 * @c jit_insn_opndts (@p insn): for TableSwitch_1 format
 * @c jit_insn_opndls (@p insn): for LookupSwitch_1 format
 */
    /* Move and conversion instructions that transfer values among
   registers of the same kind (move) or different kinds (convert) */
    /* conversion. will extend or truncate */
    /**
 * Re-interpret binary presentations:
 *   *(i32 *)&f32, *(i64 *)&f64, *(f32 *)&i32, *(f64 *)&i64
 */
    /* Arithmetic and bitwise instructions: */
    /* Select instruction: */
    /* Memory access instructions: */
    /* Control instructions */
    /* Call and return instructions */
    /**
 * @def ANN_LABEL (TYPE, NAME)
 *
 * Definition of label annotations.
 *
 * @param TYPE type of the annotation
 * @param NAME name of the annotation
 *
 * Each defined annotation with name NAME has the following APIs:
 *
 * @c jit_annl_NAME (cc, label): accesses the annotation NAME of
 * label @p label
 * @c jit_annl_enable_NAME (cc): enables the annotation NAME
 * @c jit_annl_disable_NAME (cc): disables the annotation NAME
 * @c jit_annl_is_enabled_NAME (cc): check whether the annotation NAME
 * is enabled
 */
    /* Basic Block of a label.  */
    void jit_annl_disable_basic_block() {
        jit_free(_ann._label_basic_block);
        _ann._label_basic_block = null;
        _ann._label_basic_block_enabled = 0;
    }
    /* Predecessor number of the block that is only used in
   update_cfg for updating the CFG.  */
    void jit_annl_disable_pred_num() {
        jit_free(_ann._label_pred_num);
        _ann._label_pred_num = null;
        _ann._label_pred_num_enabled = 0;
    }
    /* Execution frequency of a block.  We can split critical edges with
   empty blocks so we don't need to store frequencies of edges.  */
    void jit_annl_disable_freq() {
        jit_free(_ann._label_freq);
        _ann._label_freq = null;
        _ann._label_freq_enabled = 0;
    }
    /* Begin bytecode instruction pointer of the block.  */
    void jit_annl_disable_begin_bcip() {
        jit_free(_ann._label_begin_bcip);
        _ann._label_begin_bcip = null;
        _ann._label_begin_bcip_enabled = 0;
    }
    /* End bytecode instruction pointer of the block.  */
    void jit_annl_disable_end_bcip() {
        jit_free(_ann._label_end_bcip);
        _ann._label_end_bcip = null;
        _ann._label_end_bcip_enabled = 0;
    }
    /* Stack pointer offset at the end of the block.  */
    void jit_annl_disable_end_sp() {
        jit_free(_ann._label_end_sp);
        _ann._label_end_sp = null;
        _ann._label_end_sp_enabled = 0;
    }
    /* The label of the next physically adjacent block.  */
    void jit_annl_disable_next_label() {
        jit_free(_ann._label_next_label);
        _ann._label_next_label = null;
        _ann._label_next_label_enabled = 0;
    }
    /* Compiled code address of the block.  */
    void jit_annl_disable_jitted_addr() {
        jit_free(_ann._label_jitted_addr);
        _ann._label_jitted_addr = null;
        _ann._label_jitted_addr_enabled = 0;
    }
    /**
 * @def ANN_INSN (TYPE, NAME)
 *
 * Definition of instruction annotations.
 *
 * @param TYPE type of the annotation
 * @param NAME name of the annotation
 *
 * Each defined annotation with name NAME has the following APIs:
 *
 * @c jit_anni_NAME (cc, insn): accesses the annotation NAME of
 * instruction @p insn
 * @c jit_anni_enable_NAME (cc): enables the annotation NAME
 * @c jit_anni_disable_NAME (cc): disables the annotation NAME
 * @c jit_anni_is_enabled_NAME (cc): check whether the annotation NAME
 * is enabled
 */
    /* A private annotation for linking instructions with the same hash
   value, which is only used by the compilation context's hash table
   of instructions.  */
    void jit_anni_disable__hash_link() {
        jit_free(_ann._insn__hash_link);
        _ann._insn__hash_link = null;
        _ann._insn__hash_link_enabled = 0;
    }
    /**
 * @def ANN_REG (TYPE, NAME)
 *
 * Definition of register annotations.
 *
 * @param TYPE type of the annotation
 * @param NAME name of the annotation
 *
 * Each defined annotation with name NAME has the following APIs:
 *
 * @c jit_annr_NAME (cc, reg): accesses the annotation NAME of
 * register @p reg
 * @c jit_annr_enable_NAME (cc): enables the annotation NAME
 * @c jit_annr_disable_NAME (cc): disables the annotation NAME
 * @c jit_annr_is_enabled_NAME (cc): check whether the annotation NAME
 * is enabled
 */
    /* Defining instruction of registers satisfying SSA property.  */
    void jit_annr_disable_def_insn() {
        uint k = void;
        for (k = JIT_REG_KIND_VOID; k < JIT_REG_KIND_L32; k++) {
            jit_free(_ann._reg_def_insn[k]);
            _ann._reg_def_insn[k] = null;
        }
        _ann._reg_def_insn_enabled = 0;
    }

    bool jit_lock_reg_in_insn(JitInsn* the_insn, JitReg reg_to_lock) {
        bool ret = false;
        JitInsn* prevent_spill = null;
        JitInsn* indicate_using = null;
        if (!the_insn)
            goto just_return;
        if (is_hreg_fixed(reg_to_lock)) {
            ret = true;
            goto just_return;
        }
        /**
     * give the virtual register of the locked hard register a minimum, non-zero
     * distance, * so as to prevent it from being spilled out
     */
        prevent_spill = jit_insn_new_MOV(reg_to_lock, reg_to_lock);
        if (!prevent_spill)
            goto just_return;
        jit_insn_insert_before(the_insn, prevent_spill);
        /**
     * announce the locked hard register is being used, and do necessary spill
     * ASAP
     */
        indicate_using = jit_insn_new_MOV(reg_to_lock, reg_to_lock);
        if (!indicate_using)
            goto just_return;
        jit_insn_insert_after(the_insn, indicate_using);
        ret = true;
    just_return:
        if (!ret)
            jit_set_last_error("generate insn failed");
        return ret;
    }

    JitInsn* set_insn_uid(JitInsn* insn) {
        if (insn) {
            unsigned num = _ann._insn_num;
            unsigned capacity = _ann._insn_capacity;
            bool successful = true;
            bh_assert(num <= capacity);
            if (num == capacity) {
                capacity = capacity > 0 ? (capacity + capacity / 2) : 64;
                /*
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
                /**
 * @file   jit-ir.def
 *
 * @brief  Definition of JIT IR instructions and annotations.
 */
                /**
 * @def INSN (NAME, OPND_KIND, OPND_NUM, FIRST_USE)
 *
 * Definition of IR instructions
 *
 * @param NAME name of the opcode
 * @param OPND_KIND kind of the operand(s)
 * @param OPND_NUM number of the operand(s)
 * @param FIRST_USE index of the first use register
 *
 * @p OPND_KIND and @p OPND_NUM together determine the format of an
 * instruction.  There are four kinds of formats:
 *
 * 1) Reg: fixed-number register operands, @p OPND_NUM specifies the
 * number of operands;
 *
 * 2) VReg: variable-number register operands, @p OPND_NUM specifies
 * the number of fixed register operands;
 *
 * 3) TableSwitch: tableswitch instruction's format, @p OPND_NUM must
 * be 1;
 *
 * 4) LookupSwitch: lookupswitch instruction's format, @p OPND_NUM
 * must be 1.
 *
 * Instruction operands are all registers and they are organized in an
 * order that all registers defined by the instruction, if any, appear
 * before the registers used by the instruction. The @p FIRST_USE is
 * the index of the first use register in the register vector sorted
 * in this order. Use @c jit_insn_opnd_regs to get the register
 * vector in this order and use @c jit_insn_opnd_first_use to get the
 * index of the first use register.
 *
 * Every instruction with name @p NAME has the following definitions:
 *
 * @c JEFF_OP_NAME: the enum opcode of insn NAME
 * @c jit_insn_new_NAME (...): creates a new instance of insn NAME
 *
 * An instruction is deleted by function:
 *
 * @c jit_insn_delete (@p insn)
 *
 * In the scope of this IR's terminology, operand and argument have
 * different meanings. The operand is a general notation, which
 * denotes every raw operand of an instruction, while the argument
 * only denotes the variable part of operands of instructions of VReg
 * kind. For example, a VReg instruction phi node "r0 = phi(r1, r2)"
 * has three operands opnd[0]: r0, opnd[1]: r1 and opnd[2]: r2, but
 * only two arguments arg[0]: r1 and arg[1]: r2.  Operands or
 * arguments of instructions with various formats can be access
 * through the following APIs:
 *
 * @c jit_insn_opnd (@p insn, @p n): for Reg_N formats
 * @c jit_insn_opndv (@p insn, @p n): for VReg_N formats
 * @c jit_insn_opndv_num (@p insn): for VReg_N formats
 * @c jit_insn_opndts (@p insn): for TableSwitch_1 format
 * @c jit_insn_opndls (@p insn): for LookupSwitch_1 format
 */
                /* Move and conversion instructions that transfer values among
   registers of the same kind (move) or different kinds (convert) */
                /* conversion. will extend or truncate */
                /**
 * Re-interpret binary presentations:
 *   *(i32 *)&f32, *(i64 *)&f64, *(f32 *)&i32, *(f64 *)&i64
 */
                /* Arithmetic and bitwise instructions: */
                /* Select instruction: */
                /* Memory access instructions: */
                /* Control instructions */
                /* Call and return instructions */
                /**
 * @def ANN_LABEL (TYPE, NAME)
 *
 * Definition of label annotations.
 *
 * @param TYPE type of the annotation
 * @param NAME name of the annotation
 *
 * Each defined annotation with name NAME has the following APIs:
 *
 * @c jit_annl_NAME (cc, label): accesses the annotation NAME of
 * label @p label
 * @c jit_annl_enable_NAME (cc): enables the annotation NAME
 * @c jit_annl_disable_NAME (cc): disables the annotation NAME
 * @c jit_annl_is_enabled_NAME (cc): check whether the annotation NAME
 * is enabled
 */
                /* Basic Block of a label.  */
                /* Predecessor number of the block that is only used in
   update_cfg for updating the CFG.  */
                /* Execution frequency of a block.  We can split critical edges with
   empty blocks so we don't need to store frequencies of edges.  */
                /* Begin bytecode instruction pointer of the block.  */
                /* End bytecode instruction pointer of the block.  */
                /* Stack pointer offset at the end of the block.  */
                /* The label of the next physically adjacent block.  */
                /* Compiled code address of the block.  */
                /**
 * @def ANN_INSN (TYPE, NAME)
 *
 * Definition of instruction annotations.
 *
 * @param TYPE type of the annotation
 * @param NAME name of the annotation
 *
 * Each defined annotation with name NAME has the following APIs:
 *
 * @c jit_anni_NAME (cc, insn): accesses the annotation NAME of
 * instruction @p insn
 * @c jit_anni_enable_NAME (cc): enables the annotation NAME
 * @c jit_anni_disable_NAME (cc): disables the annotation NAME
 * @c jit_anni_is_enabled_NAME (cc): check whether the annotation NAME
 * is enabled
 */
                /* A private annotation for linking instructions with the same hash
   value, which is only used by the compilation context's hash table
   of instructions.  */
                if (successful && _ann._insn__hash_link_enabled) {
                    JitInsn* ptr = _jit_realloc(_ann._insn__hash_link, JitInsn.sizeof * capacity, JitInsn.sizeof * num);
                    if (ptr)
                        _ann._insn__hash_link = ptr;
                    else
                        successful = false;
                }
                /**
 * @def ANN_REG (TYPE, NAME)
 *
 * Definition of register annotations.
 *
 * @param TYPE type of the annotation
 * @param NAME name of the annotation
 *
 * Each defined annotation with name NAME has the following APIs:
 *
 * @c jit_annr_NAME (cc, reg): accesses the annotation NAME of
 * register @p reg
 * @c jit_annr_enable_NAME (cc): enables the annotation NAME
 * @c jit_annr_disable_NAME (cc): disables the annotation NAME
 * @c jit_annr_is_enabled_NAME (cc): check whether the annotation NAME
 * is enabled
 */
                /* Defining instruction of registers satisfying SSA property.  */
                if (!successful) {
                    jit_set_last_error("set insn uid failed");
                    return null;
                }
                _ann._insn_capacity = capacity;
            }
            _ann._insn_num = num + 1;
            insn.uid = num;
        }
        return insn;
    }
    /**
 * Create a I32 constant value with relocatable into the compilation
 * context. A constant value that has relocation info cannot be
 * constant-folded as normal constants because its value depends on
 * runtime context and may be different in different executions.
 *
 * @param cc compilation context
 * @param val a I32 value
 * @param rel relocation information
 *
 * @return a constant register containing the value
 */
    JitReg new_const_I32_rel(int val, ulong rel) {
        ulong val64 = cast(ulong) val | rel << 32;
        do {
            JitReg reg = jit_reg_new(JIT_REG_KIND_I32, (_JIT_REG_CONST_VAL_FLAG | (cast(JitReg) val64 & ~_JIT_REG_KIND_MASK)));
            if (cast(ulong) get_const_val_in_reg(reg) == val64)
                return reg;
            return _new_const(JIT_REG_KIND_I32, val64.sizeof, &val64);
        }
        while (0);
    }
    /**
 * Create a I32 constant value without relocation info (0) into the
 * compilation context.
 *
 * @param cc compilation context
 * @param val a I32 value
 *
 * @return a constant register containing the value
 */
    JitReg new_const_I32(int val) {
        return new_const_I32_rel(val, 0);
    }

    JitReg new_const_I64(long val) {
        do {
            JitReg reg = jit_reg_new(JIT_REG_KIND_I64, (_JIT_REG_CONST_VAL_FLAG | (cast(JitReg) val & ~_JIT_REG_KIND_MASK)));
            if (cast(long) get_const_val_in_reg(reg) == val)
                return reg;
            return _new_const(JIT_REG_KIND_I64, val.sizeof, &val);
        }
        while (0);
    }
    /**
 * Create a F32 constant value into the compilation context.
 *
 * @param cc compilation context
 * @param val a F32 value
 *
 * @return a constant register containing the value
 */
    JitReg new_const_F32(float val) {
        int float_neg_zero = 0x80000000;
        if (!memcmp(&val, &float_neg_zero, float.sizeof)) /* Create const -0.0f */
            return _new_const(JIT_REG_KIND_F32, float.sizeof, &val);
        do {
            JitReg reg = jit_reg_new(JIT_REG_KIND_F32, (_JIT_REG_CONST_VAL_FLAG | (cast(JitReg) val & ~_JIT_REG_KIND_MASK)));
            if (cast(float) get_const_val_in_reg(reg) == val)
                return reg;
            return _new_const(JIT_REG_KIND_F32, val.sizeof, &val);
        }
        while (0);
    }
    /**
 * Create a F64 constant value into the compilation context.
 *
 * @param cc compilation context
 * @param val a F64 value
 *
 * @return a constant register containing the value
 */
    JitReg new_const_F64(double val) {
        long double_neg_zero = 0x8000000000000000L;
        if (!memcmp(&val, &double_neg_zero, double.sizeof)) /* Create const -0.0d */
            return _new_const(JIT_REG_KIND_F64, double.sizeof, &val);
        do {
            JitReg reg = jit_reg_new(JIT_REG_KIND_F64, (_JIT_REG_CONST_VAL_FLAG | (cast(JitReg) val & ~_JIT_REG_KIND_MASK)));
            if (cast(double) get_const_val_in_reg(reg) == val)
                return reg;
            return _new_const(JIT_REG_KIND_F64, val.sizeof, &val);
        }
        while (0);
    }

    private ulong get_const_I32_helper(JitReg reg) {
        do {
            bh_assert(jit_reg_kind(reg) == JIT_REG_KIND_I32);
            bh_assert(jit_reg_is_const(reg));
            return (jit_reg_is_const_val(reg) ? cast(ulong) get_const_val_in_reg(reg) : *cast(ulong*)(
                    address_of_const(reg, uint.sizeof)));
        }
        while (0);
    }

    uint get_const_I32_rel(JitReg reg) {
        return cast(uint)(get_const_I32_helper(reg) >> 32);
    }

    int get_const_I32(JitReg reg) {
        return cast(int)(get_const_I32_helper(reg));
    }

    long get_const_I64(JitReg reg) {
        do {
            bh_assert(jit_reg_kind(reg) == JIT_REG_KIND_I64);
            bh_assert(jit_reg_is_const(reg));
            return (jit_reg_is_const_val(reg) ? cast(long) get_const_val_in_reg(reg) : *cast(long*)(
                    address_of_const(reg, int.sizeof)));
        }
        while (0);
    }

    float get_const_F32(JitReg reg) {
        do {
            bh_assert(jit_reg_kind(reg) == JIT_REG_KIND_F32);
            bh_assert(jit_reg_is_const(reg));
            return (jit_reg_is_const_val(reg) ? cast(float) get_const_val_in_reg(reg) : *cast(float*)(
                    address_of_const(reg, float.sizeof)));
        }
        while (0);
    }

    double get_const_F64(JitReg reg) {
        bh_assert(jit_reg_kind(reg) == JIT_REG_KIND_F64);
        bh_assert(jit_reg_is_const(reg));
        return (jit_reg_is_const_val(reg) ? cast(double) get_const_val_in_reg(reg) : *(cast(double*) address_of_const(reg, double
                .sizeof)));
    }
    /**
 * Get the number of total created instructions.
 *
 * @param cc the compilation context
 *
 * @return the number of total created instructions
 */
    uint insn_num() {
        return _ann._insn_num;
    }
    /**
 * Get the number of total created registers.
 *
 * @param cc the compilation context
 * @param kind the register kind
 *
 * @return the number of total created registers
 */
    uint reg_num(uint kind) {
        bh_assert(kind < JIT_REG_KIND_L32);
        return _ann._reg_num[kind];
    }

    JitReg new_label() {
        uint num = _ann._label_num;
        uint capacity = _ann._label_capacity;
        bool successful = true;
        bh_assert(num <= capacity);
        if (num == capacity) {
            capacity = capacity > 0 ? (capacity + capacity / 2) : 16;
            /*
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
            /**
 * @file   jit-ir.def
 *
 * @brief  Definition of JIT IR instructions and annotations.
 */
            /**
 * @def INSN (NAME, OPND_KIND, OPND_NUM, FIRST_USE)
 *
 * Definition of IR instructions
 *
 * @param NAME name of the opcode
 * @param OPND_KIND kind of the operand(s)
 * @param OPND_NUM number of the operand(s)
 * @param FIRST_USE index of the first use register
 *
 * @p OPND_KIND and @p OPND_NUM together determine the format of an
 * instruction.  There are four kinds of formats:
 *
 * 1) Reg: fixed-number register operands, @p OPND_NUM specifies the
 * number of operands;
 *
 * 2) VReg: variable-number register operands, @p OPND_NUM specifies
 * the number of fixed register operands;
 *
 * 3) TableSwitch: tableswitch instruction's format, @p OPND_NUM must
 * be 1;
 *
 * 4) LookupSwitch: lookupswitch instruction's format, @p OPND_NUM
 * must be 1.
 *
 * Instruction operands are all registers and they are organized in an
 * order that all registers defined by the instruction, if any, appear
 * before the registers used by the instruction. The @p FIRST_USE is
 * the index of the first use register in the register vector sorted
 * in this order. Use @c jit_insn_opnd_regs to get the register
 * vector in this order and use @c jit_insn_opnd_first_use to get the
 * index of the first use register.
 *
 * Every instruction with name @p NAME has the following definitions:
 *
 * @c JEFF_OP_NAME: the enum opcode of insn NAME
 * @c jit_insn_new_NAME (...): creates a new instance of insn NAME
 *
 * An instruction is deleted by function:
 *
 * @c jit_insn_delete (@p insn)
 *
 * In the scope of this IR's terminology, operand and argument have
 * different meanings. The operand is a general notation, which
 * denotes every raw operand of an instruction, while the argument
 * only denotes the variable part of operands of instructions of VReg
 * kind. For example, a VReg instruction phi node "r0 = phi(r1, r2)"
 * has three operands opnd[0]: r0, opnd[1]: r1 and opnd[2]: r2, but
 * only two arguments arg[0]: r1 and arg[1]: r2.  Operands or
 * arguments of instructions with various formats can be access
 * through the following APIs:
 *
 * @c jit_insn_opnd (@p insn, @p n): for Reg_N formats
 * @c jit_insn_opndv (@p insn, @p n): for VReg_N formats
 * @c jit_insn_opndv_num (@p insn): for VReg_N formats
 * @c jit_insn_opndts (@p insn): for TableSwitch_1 format
 * @c jit_insn_opndls (@p insn): for LookupSwitch_1 format
 */
            /* Move and conversion instructions that transfer values among
   registers of the same kind (move) or different kinds (convert) */
            /* conversion. will extend or truncate */
            /**
 * Re-interpret binary presentations:
 *   *(i32 *)&f32, *(i64 *)&f64, *(f32 *)&i32, *(f64 *)&i64
 */
            /* Arithmetic and bitwise instructions: */
            /* Select instruction: */
            /* Memory access instructions: */
            /* Control instructions */
            /* Call and return instructions */
            /**
 * @def ANN_LABEL (TYPE, NAME)
 *
 * Definition of label annotations.
 *
 * @param TYPE type of the annotation
 * @param NAME name of the annotation
 *
 * Each defined annotation with name NAME has the following APIs:
 *
 * @c jit_annl_NAME (cc, label): accesses the annotation NAME of
 * label @p label
 * @c jit_annl_enable_NAME (cc): enables the annotation NAME
 * @c jit_annl_disable_NAME (cc): disables the annotation NAME
 * @c jit_annl_is_enabled_NAME (cc): check whether the annotation NAME
 * is enabled
 */
            /* Basic Block of a label.  */
            if (successful && _ann._label_basic_block_enabled) {
                JitBasicBlock* ptr = _jit_realloc(_ann._label_basic_block, JitBasicBlock.sizeof * capacity, JitBasicBlock
                        .sizeof * num);
                if (ptr)
                    _ann._label_basic_block = ptr;
                else
                    successful = false;
            }
            /* Predecessor number of the block that is only used in
   update_cfg for updating the CFG.  */
            if (successful && _ann._label_pred_num_enabled) {
                uint16* ptr = _jit_realloc(_ann._label_pred_num, uint16.sizeof * capacity, uint16.sizeof * num);
                if (ptr)
                    _ann._label_pred_num = ptr;
                else
                    successful = false;
            }
            /* Execution frequency of a block.  We can split critical edges with
   empty blocks so we don't need to store frequencies of edges.  */
            if (successful && _ann._label_freq_enabled) {
                uint16* ptr = _jit_realloc(_ann._label_freq, uint16.sizeof * capacity, uint16.sizeof * num);
                if (ptr)
                    _ann._label_freq = ptr;
                else
                    successful = false;
            }
            /* Begin bytecode instruction pointer of the block.  */
            if (successful && _ann._label_begin_bcip_enabled) {
                uint8** ptr = _jit_realloc(_ann._label_begin_bcip, (uint8*).sizeof.sizeof * capacity, (uint8*).sizeof * num);
                if (ptr)
                    _ann._label_begin_bcip = ptr;
                else
                    successful = false;
            }
            /* End bytecode instruction pointer of the block.  */
            if (successful && _ann._label_end_bcip_enabled) {
                uint8** ptr = _jit_realloc(_ann._label_end_bcip, (uint8*).sizeof * capacity, (uint8*).sizeof * num);
                if (ptr)
                    _ann._label_end_bcip = ptr;
                else
                    successful = false;
            }
            /* Stack pointer offset at the end of the block.  */
            if (successful && _ann._label_end_sp_enabled) {
                uint16* ptr = _jit_realloc(_ann._label_end_sp, uint16.sizeof * capacity, uint16.sizeof * num);
                if (ptr)
                    _ann._label_end_sp = ptr;
                else
                    successful = false;
            }
            /* The label of the next physically adjacent block.  */
            if (successful && _ann._label_next_label_enabled) {
                JitReg* ptr = _jit_realloc(_ann._label_next_label, JitReg.sizeof * capacity, JitReg.sizeof * num);
                if (ptr)
                    _ann._label_next_label = ptr;
                else
                    successful = false;
            }
            /* Compiled code address of the block.  */
            if (successful && _ann._label_jitted_addr_enabled) {
                void** ptr = _jit_realloc(_ann._label_jitted_addr, (void*).sizeof * capacity, (void*).sizeof * num);
                if (ptr)
                    _ann._label_jitted_addr = ptr;
                else
                    successful = false;
            }
            /**
 * @def ANN_INSN (TYPE, NAME)
 *
 * Definition of instruction annotations.
 *
 * @param TYPE type of the annotation
 * @param NAME name of the annotation
 *
 * Each defined annotation with name NAME has the following APIs:
 *
 * @c jit_anni_NAME (cc, insn): accesses the annotation NAME of
 * instruction @p insn
 * @c jit_anni_enable_NAME (cc): enables the annotation NAME
 * @c jit_anni_disable_NAME (cc): disables the annotation NAME
 * @c jit_anni_is_enabled_NAME (cc): check whether the annotation NAME
 * is enabled
 */
            /* A private annotation for linking instructions with the same hash
   value, which is only used by the compilation context's hash table
   of instructions.  */
            /**
 * @def ANN_REG (TYPE, NAME)
 *
 * Definition of register annotations.
 *
 * @param TYPE type of the annotation
 * @param NAME name of the annotation
 *
 * Each defined annotation with name NAME has the following APIs:
 *
 * @c jit_annr_NAME (cc, reg): accesses the annotation NAME of
 * register @p reg
 * @c jit_annr_enable_NAME (cc): enables the annotation NAME
 * @c jit_annr_disable_NAME (cc): disables the annotation NAME
 * @c jit_annr_is_enabled_NAME (cc): check whether the annotation NAME
 * is enabled
 */
            /* Defining instruction of registers satisfying SSA property.  */
            if (!successful) {
                jit_set_last_error(cc, "create label register failed");
                return 0;
            }
            _ann._label_capacity = capacity;
        }
        _ann._label_num = num + 1;
        return jit_reg_new(JIT_REG_KIND_L32, num);
    }

    JitBasicBlock* new_basic_block(int n) {
        JitReg label = new_label;
        JitBasicBlock* block = null;
        if (label && ((block = jit_basic_block_new(label, n)) !is null)) /* Void 0 register indicates error in creation.  */
            *(jit_annl_basic_block(label)) = block;
        else
            jit_set_last_error("create basic block failed");
        return block;
    }

    JitBasicBlock* resize_basic_block(JitBasicBlock* block, int n) {
        JitReg label = jit_basic_block_label(block);
        JitInsn* insn = jit_basic_block_first_insn(block);
        JitBasicBlock* new_block = jit_basic_block_new(label, n);
        if (!new_block) {
            jit_set_last_error("resize basic block failed");
            return null;
        }
        jit_insn_unlink(block);
        if (insn != block)
            jit_insn_insert_before(insn, new_block);
        bh_assert(*(jit_annl_basic_block(label)) == block);

        *(jit_annl_basic_block(label)) = new_block;
        jit_insn_delete(block);
        return new_block;
    }

    bool enable_insn_hash(uint n) {
        if (jit_anni_is_enabled__hash_link)
            return true;
        if (!jit_anni_enable__hash_link)
            return false;
        /* The table must not exist.  */
        bh_assert(!_insn_hash_table._table);
        /* Integer overflow cannot happen because n << 4G (at most several
       times of 64K in the most extreme case).  */
        if (((_insn_hash_table._table =
                jit_calloc_ref(cast(uint)(n * typeof(*_insn_hash_table._table).sizeof))) is null)) {
            jit_anni_disable__hash_link;
            return false;
        }
        _insn_hash_table._size = n;
        return true;
    }

    void disable_insn_hash() {
        jit_anni_disable__hash_link;
        jit_free(_insn_hash_table._table);
        _insn_hash_table._table = null;
        _insn_hash_table._size = 0;
    }

    void reset_insn_hash() {
        if (jit_anni_is_enabled__hash_link)
            memset(_insn_hash_table._table, 0,
                    _insn_hash_table._size
                    * typeof(*_insn_hash_table._table).sizeof);
    }

    JitInsn* _set_insn_uid_for_new_insn(JitInsn* insn) {
        if (set_insn_uid(insn))
            return insn;
        jit_insn_delete(insn);
        return null;
    }

    char* jit_get_last_error() {
        return last_error[0] == '\0' ? null : last_error.ptr;
    }

    bool update_cfg() {
        JitBasicBlock* block = void;
        uint block_index = void, end = void, succ_index = void;
        ushort idx = void;
        JitReg* target = void;
        bool retval = false;
        if (!jit_annl_enable_pred_num)
            return false;
        /* Update pred_num of all blocks.  */
        for (block_index = 0, end = (cc)._ann._label_num; block_index < end; block_index++)
            if ((block = (cc)._ann._label_basic_block[block_index]) !is null) {
            JitRegVec succs = jit_basic_block_succs(block);
            for (succ_index = 0, target = succs._base; succ_index < succs.num; succ_index++, target += succs
                    ._stride)
                if (*target is JitRegKind.L32)

                    *(jit_annl_pred_num(*target)) += 1;
        }
        /* Resize predecessor vectors of body blocks.  */
        for (block_index = 2, end = (cc)._ann._label_num; block_index < end; block_index++)
            if ((block = (cc)._ann._label_basic_block[block_index]) !is null) {
            if (!resize_basic_block(
                    cc, block,

                    *(jit_annl_pred_num(jit_basic_block_label(block)))))
                goto cleanup_and_return;
        }
        /* Fill in predecessor vectors all blocks.  */
        for (block_index = (cc)._ann._label_num; block_index > 0; block_index--)
            if ((block = (cc)._ann._label_basic_block[block_index - 1]) !is null) {
            JitRegVec succs = jit_basic_block_succs(block), preds = void;
            for (succ_index = 0, target = succs._base; succ_index < succs.num; succ_index++, target += succs
                    ._stride)
                if (*target is JitRegKind.L32) {
                    preds = jit_basic_block_preds(*(jit_annl_basic_block(*target)));
                    bh_assert(*(jit_annl_pred_num(*target)) > 0);
                    idx = cast(ushort)(*(jit_annl_pred_num(*target)) - 1);

                    *(jit_annl_pred_num(*target)) = idx;

                    *(jit_reg_vec_at(&preds, idx)) = jit_basic_block_label(block);
                }
        }
        retval = true;
    cleanup_and_return:
        jit_annl_disable_pred_num;
        return retval;
    }
}
