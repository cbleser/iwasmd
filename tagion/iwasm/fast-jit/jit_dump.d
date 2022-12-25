module jit_dump;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/*
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

public import jit_dump;
public import jit_compiler;
public import jit_codegen;

void jit_dump_reg(JitCompContext* cc, JitReg reg) {
    uint kind = jit_reg_kind(reg);
    uint no = jit_reg_no(reg);

    switch (kind) {
        case JIT_REG_KIND_VOID:
            os_printf("VOID");
            break;

        case JIT_REG_KIND_I32:
            if (jit_reg_is_const(reg)) {
                uint rel = jit_cc_get_const_I32_rel(cc, reg);

                os_printf("0x%x", jit_cc_get_const_I32(cc, reg));

                if (rel)
                    os_printf("(rel: 0x%x)", rel);
            }
            else
                os_printf("i%d", no);
            break;

        case JIT_REG_KIND_I64:
            if (jit_reg_is_const(reg))
                os_printf("0x%llxL", jit_cc_get_const_I64(cc, reg));
            else
                os_printf("I%d", no);
            break;

        case JIT_REG_KIND_F32:
            if (jit_reg_is_const(reg))
                os_printf("%f", jit_cc_get_const_F32(cc, reg));
            else
                os_printf("f%d", no);
            break;

        case JIT_REG_KIND_F64:
            if (jit_reg_is_const(reg))
                os_printf("%fL", jit_cc_get_const_F64(cc, reg));
            else
                os_printf("D%d", no);
            break;

        case JIT_REG_KIND_L32:
            os_printf("L%d", no);
            break;

        default:
            bh_assert(!"Unsupported register kind.");
    }
}

private void jit_dump_insn_Reg(JitCompContext* cc, JitInsn* insn, uint opnd_num) {
    uint i = void;

    for (i = 0; i < opnd_num; i++) {
        os_printf(i == 0 ? " " : ", ");
        jit_dump_reg(cc, *(jit_insn_opnd(insn, i)));
    }

    os_printf("\n");
}

private void jit_dump_insn_VReg(JitCompContext* cc, JitInsn* insn, uint opnd_num) {
    uint i = void;

    opnd_num = jit_insn_opndv_num(insn);

    for (i = 0; i < opnd_num; i++) {
        os_printf(i == 0 ? " " : ", ");
        jit_dump_reg(cc, *(jit_insn_opndv(insn, i)));
    }

    os_printf("\n");
}

private void jit_dump_insn_LookupSwitch(JitCompContext* cc, JitInsn* insn, uint opnd_num) {
    uint i = void;
    JitOpndLookupSwitch* opnd = jit_insn_opndls(insn);

    os_printf(" ");
    jit_dump_reg(cc, opnd.value);
    os_printf("\n%16s: ", "default");
    jit_dump_reg(cc, opnd.default_target);
    os_printf("\n");

    for (i = 0; i < opnd.match_pairs_num; i++) {
        os_printf("%18d: ", opnd.match_pairs[i].value);
        jit_dump_reg(cc, opnd.match_pairs[i].target);
        os_printf("\n");
    }
}

void jit_dump_insn(JitCompContext* cc, JitInsn* insn) {
    switch (insn.opcode) {
enum string INSN(string NAME, string OPND_KIND, string OPND_NUM, string FIRST_USE) = `     \
    case JIT_OP_##NAME:                                \
        os_printf("    %-15s", #NAME);                 \
        jit_dump_insn_##OPND_KIND(cc, insn, OPND_NUM); \
        break;`;
public import jit_ir.d;
    default: break;}
}

void jit_dump_basic_block(JitCompContext* cc, JitBasicBlock* block) {
    uint i = void, label_index = void;
    void* begin_addr = void, end_addr = void;
    JitBasicBlock* block_next = void;
    JitInsn* insn = void;
    JitRegVec preds = jit_basic_block_preds(block);
    JitRegVec succs = jit_basic_block_succs(block);
    JitReg label = jit_basic_block_label(block), label_next = void;
    JitReg* reg = void;

    jit_dump_reg(cc, label);
    os_printf(":\n    ; PREDS(");

    JIT_REG_VEC_FOREACH(preds, i, reg)
    {
        if (i > 0)
            os_printf(" ");
        jit_dump_reg(cc, *reg);
    }

    os_printf(")\n    ;");

    if (jit_annl_is_enabled_begin_bcip(cc))
        os_printf(" BEGIN_BCIP=0x%04tx",
                  *(jit_annl_begin_bcip(cc, label))
                      - cast(ubyte*)cc.cur_wasm_module.load_addr);

    if (jit_annl_is_enabled_end_bcip(cc))
        os_printf(" END_BCIP=0x%04tx",
                  *(jit_annl_end_bcip(cc, label))
                      - cast(ubyte*)cc.cur_wasm_module.load_addr);
    os_printf("\n");

    if (jit_annl_is_enabled_jitted_addr(cc)) {
        begin_addr = *(jit_annl_jitted_addr(cc, label));

        if (label == cc.entry_label) {
            block_next = cc._ann._label_basic_block[2];
            label_next = jit_basic_block_label(block_next);
            end_addr = *(jit_annl_jitted_addr(cc, label_next));
        }
        else if (label == cc.exit_label) {
            end_addr = cc.jitted_addr_end;
        }
        else {
            label_index = jit_reg_no(label);
            if (label_index < jit_cc_label_num(cc) - 1)
                block_next = cc._ann._label_basic_block[label_index + 1];
            else
                block_next = cc._ann._label_basic_block[1];
            label_next = jit_basic_block_label(block_next);
            end_addr = *(jit_annl_jitted_addr(cc, label_next));
        }

        jit_codegen_dump_native(begin_addr, end_addr);
    }
    else {
        /* Dump IR.  */
        JIT_FOREACH_INSN(block, insn) jit_dump_insn(cc, insn);
    }

    os_printf("    ; SUCCS(");

    JIT_REG_VEC_FOREACH(succs, i, reg)
    {
        if (i > 0)
            os_printf(" ");
        jit_dump_reg(cc, *reg);
    }

    os_printf(")\n\n");
}

private void dump_func_name(JitCompContext* cc) {
    const(char)* func_name = null;
    WASMModule* module_ = cc.cur_wasm_module;

static if (WASM_ENABLE_CUSTOM_NAME_SECTION != 0) {
    func_name = cc.cur_wasm_func.field_name;
}

    /* if custom name section is not generated,
       search symbols from export table */
    if (!func_name) {
        uint i = void;
        for (i = 0; i < module_.export_count; i++) {
            if (module_.exports[i].kind == EXPORT_KIND_FUNC
                && module_.exports[i].index == cc.cur_wasm_func_idx) {
                func_name = module_.exports[i].name;
                break;
            }
        }
    }

    /* function name not exported, print number instead */
    if (func_name == null) {
        os_printf("$f%d", cc.cur_wasm_func_idx);
    }
    else {
        os_printf("%s", func_name);
    }
}

private void dump_cc_ir(JitCompContext* cc) {
    uint i = void, end = void;
    JitBasicBlock* block = void;
    JitReg label = void;
    const(char)*[8] kind_names = [ "VOID", "I32", "I64",  "F32",
                                 "F64",  "V64", "V128", "V256" ];

    os_printf("; Function: ");
    dump_func_name(cc);
    os_printf("\n");

    os_printf("; Constant table sizes:");

    for (i = 0; i < JIT_REG_KIND_L32; i++)
        os_printf(" %s=%d", kind_names[i], cc._const_val._num[i]);

    os_printf("\n; Label number: %d", jit_cc_label_num(cc));
    os_printf("\n; Instruction number: %d", jit_cc_insn_num(cc));
    os_printf("\n; Register numbers:");

    for (i = 0; i < JIT_REG_KIND_L32; i++)
        os_printf(" %s=%d", kind_names[i], jit_cc_reg_num(cc, i));

    os_printf("\n; Label annotations:");
enum string ANN_LABEL(string TYPE, string NAME) = `           \
    if (jit_annl_is_enabled_##NAME(cc)) \
        os_printf(" %s", #NAME);`;
public import jit_ir.d;
    os_printf("\n; Instruction annotations:");
enum string ANN_INSN(string TYPE, string NAME) = `            \
    if (jit_anni_is_enabled_##NAME(cc)) \
        os_printf(" %s", #NAME);`;
public import jit_ir.d;
    os_printf("\n; Register annotations:");
enum string ANN_REG(string TYPE, string NAME) = `             \
    if (jit_annr_is_enabled_##NAME(cc)) \
        os_printf(" %s", #NAME);`;
public import jit_ir.d;
    os_printf("\n\n");

    if (jit_annl_is_enabled_next_label(cc)) {
        /* Blocks have been reordered, use that order to dump.  */
        for (label = cc.entry_label; label;
             label = *(jit_annl_next_label(cc, label)))
            jit_dump_basic_block(cc, *(jit_annl_basic_block(cc, label)));
    }
    else {
        /* Otherwise, use the default order.  */
        jit_dump_basic_block(cc, jit_cc_entry_basic_block(cc));

        JIT_FOREACH_BLOCK(cc, i, end, block) jit_dump_basic_block(cc, block);

        jit_dump_basic_block(cc, jit_cc_exit_basic_block(cc));
    }
}

void jit_dump_cc(JitCompContext* cc) {
    if (jit_cc_label_num(cc) <= 2)
        return;

    dump_cc_ir(cc);
}

bool jit_pass_dump(JitCompContext* cc) {
    const(JitGlobals)* jit_globals = jit_compiler_get_jit_globals();
    const(ubyte)* passes = jit_globals.passes;
    ubyte pass_no = cc.cur_pass_no;
    const(char)* pass_name = pass_no > 0 ? jit_compiler_get_pass_name(passes[pass_no - 1]) : "NULL";

static if (HasVersion!"BUILD_TARGET_X86_64" || HasVersion!"BUILD_TARGET_AMD_64") {
    if (!strcmp(pass_name, "lower_cg"))
        /* Ignore lower codegen pass as it does nothing in x86-64 */
        return true;
}

    os_printf("JIT.COMPILER.DUMP: PASS_NO=%d PREV_PASS=%s\n\n", pass_no,
              pass_name);
    jit_dump_cc(cc);
    os_printf("\n");
    return true;
}

bool jit_pass_update_cfg(JitCompContext* cc) {
    return jit_cc_update_cfg(cc);
}
/*
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 
public import jit_compiler;

version (none) {
extern "C" {
//! #endif

/**
 * Dump a register.
 *
 * @param cc compilation context of the register
 * @param reg register to be dumped
 */
void jit_dump_reg(JitCompContext* cc, JitReg reg);

/**
 * Dump an instruction.
 *
 * @param cc compilation context of the instruction
 * @param insn instruction to be dumped
 */
void jit_dump_insn(JitCompContext* cc, JitInsn* insn);

/**
 * Dump a block.
 *
 * @param cc compilation context of the block
 * @param block block to be dumped
 */
void jit_dump_block(JitCompContext* cc, JitBlock* block);

/**
 * Dump a compilation context.
 *
 * @param cc compilation context to be dumped
 */
void jit_dump_cc(JitCompContext* cc);

version (none) {}
}
}

 /* end of _JIT_DUMP_H_ */
