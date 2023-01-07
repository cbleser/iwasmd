module tagion.iwasm.fast_jit.jit_context;
@nogc:
nothrow:
import tagion.iwasm.fast_jit.jit_ir;
import tagion.iwasm.fast_jit.jit_frame;

import tagion.iwasm.interpreter.wasm : WASMModule, WASMFunction;

//bool jit_cc_pop_value(JitCompContext* cc, ubyte type, JitReg* p_value) {
//    return cc.pop_value(type, p_value);
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
        if (!jit_block_stack_top(&cc.block_stack)) {
            jit_set_last_error(cc, "WASM block stack underflow");
            return false;
        }
        if (!jit_block_stack_top(&cc.block_stack).value_stack.value_list_end) {
            jit_set_last_error(cc, "WASM data stack underflow");
            return false;
        }
        jit_value = jit_value_stack_pop(

                &jit_block_stack_top(&cc.block_stack).value_stack);
        bh_assert(jit_value !is null);
        if (jit_value.type != to_stack_value_type(type)) {
            jit_set_last_error(cc, "invalid WASM stack data type");
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
        bh_assert(cc.jit_frame.sp == jit_value.value);
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
   jit_cc_update_cfg for updating the CFG.  */
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
        JitInsn**[JIT_REG_KIND_L32] _reg_def_insn;
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
   jit_cc_update_cfg for updating the CFG.  */
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
bool jit_cc_push_value( ubyte type, JitReg value) {
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
    jit_value_stack_push(&jit_block_stack_top(&cc.block_stack).value_stack,
            jit_value);
    switch (jit_value.type) {
    case VALUE_TYPE_I32:
        jit_frame.push_i32(  value);
        break;
    case VALUE_TYPE_I64:
        jit_frame.push_i64(  value);
        break;
    case VALUE_TYPE_F32:
        jit_frame.push_f32(  value);
        break;
    case VALUE_TYPE_F64:
        jit_frame.push_f64(  value);
        break;
    default:
        break;
    }
    return true;
}
}
