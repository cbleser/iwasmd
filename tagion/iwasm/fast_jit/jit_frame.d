module tagion.iwasm.fast_jit.jit_frame;
@nogc nothrow:
import tagion.iwasm.fast_jit.jit_ir : JitReg, JitMemRegs, JitTableRegs;
import tagion.iwasm.fast_jit.jit_context;
import tagion.iwasm.interpreter.wasm : WASMModule, WASMFunction; 
/* Frame information for translation */
struct JitFrame {
@nogc nothrow:
    /* The current wasm module */
    WASMModule* cur_wasm_module;
    /* The current wasm function */
    WASMFunction* cur_wasm_func;
    /* The current wasm function index */
    uint cur_wasm_func_idx;
    /* The current compilation context */
    JitCompContext* cc;
    /* Max local slot number.  */
    uint max_locals;
    /* Max operand stack slot number.  */
    uint max_stacks;
    /* Instruction pointer */
    ubyte* ip;
    /* Stack top pointer */
    JitValueSlot* sp;
    /* Committed instruction pointer */
    ubyte* committed_ip;
    /* Committed stack top pointer */
    JitValueSlot* committed_sp;
    /* WASM module instance */
    private JitReg _module_inst_reg;
    /* WASM module */
    private JitReg _module_reg;
    /* module_inst->import_func_ptrs */
    private JitReg _import_func_ptrs_reg;
    /* module_inst->fast_jit_func_ptrs */
    private JitReg _fast_jit_func_ptrs_reg;
    /* module_inst->func_type_indexes */
    private JitReg _func_type_indexes_reg;
    /* Boundary of auxiliary stack */
    private JitReg _aux_stack_bound_reg;
    /* Bottom of auxiliary stack */
    private JitReg _aux_stack_bottom_reg;
    /* Data of memory instances */
    JitMemRegs* memory_regs;
    /* Data of table instances */
    JitTableRegs* table_regs;
    /* Local variables */
    JitValueSlot* lp;
    JitReg module_inst_reg() {
        if (!_module_inst_reg) {
            _module_inst_reg = cc.module_inst_reg;
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDPTR(_module_inst_reg, cc
                    .exec_env_reg, jit_cc_new_const_I32(
                    cc, WASMExecEnv.module_inst.offsetof))));
        }
        return _module_inst_reg;
    }

    JitReg module_reg() {
        //JitReg module_inst_reg = module_inst_reg(frame);
        if (!_module_reg) {
            _module_reg = cc._module_reg;
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDPTR(module_reg, module_inst_reg, jit_cc_new_const_I32(
                    cc, WASMModuleInstance.module_.offsetof))));
        }
        return _module_reg;
    }

    JitReg import_func_ptrs_reg() {
        //JitReg module_inst_reg = module_inst_reg();
        if (!_import_func_ptrs_reg) {
            _import_func_ptrs_reg = cc.import_func_ptrs_reg;
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDPTR(import_func_ptrs_reg, module_inst_reg, jit_cc_new_const_I32(
                    cc, WASMModuleInstance.import_func_ptrs.offsetof))));
        }
        return _import_func_ptrs_reg;
    }

    JitReg fast_jit_func_ptrs_reg() {
        //JitReg module_inst_reg = module_inst_reg(frame);
        if (!_fast_jit_func_ptrs_reg) {
            _fast_jit_func_ptrs_reg = cc.fast_jit_func_ptrs_reg;
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDPTR(fast_jit_func_ptrs_reg, module_inst_reg, jit_cc_new_const_I32(
                    cc, WASMModuleInstance.fast_jit_func_ptrs.offsetof))));
        }
        return _fast_jit_func_ptrs_reg;
    }

    JitReg func_type_indexes_reg() {
        //JitReg module_inst_reg = module_inst_reg(frame);
        if (!_func_type_indexes_reg) {
            _func_type_indexes_reg = cc.func_type_indexes_reg;
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDPTR(func_type_indexes_reg, module_inst_reg, jit_cc_new_const_I32(
                    cc, WASMModuleInstance.func_type_indexes.offsetof))));
        }
        return _func_type_indexes_reg;
    }

    JitReg aux_stack_bound_reg() {
        if (!_aux_stack_bound_reg) {
            _aux_stack_bound_reg = cc.aux_stack_bound_reg;
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDI32(aux_stack_bound_reg, cc
                    .exec_env_reg, jit_cc_new_const_I32(cc, WASMExecEnv.aux_stack_boundary.boundary.offsetof))));
        }
        return _aux_stack_bound_reg;
    }

    JitReg aux_stack_bottom_reg() {
        if (!_aux_stack_bottom_reg) {
            _aux_stack_bottom_reg = cc.aux_stack_bottom_reg;
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDI32(aux_stack_bottom_reg, cc
                    .exec_env_reg, jit_cc_new_const_I32(cc, WASMExecEnv.aux_stack_bottom.bottom.offsetof))));
        }
        return _aux_stack_bottom_reg;
    }

    JitReg memory_data_reg(uint mem_idx) {
        JitReg module_inst_reg = module_inst_reg(frame);
        uint memory_data_offset = cast(uint) WASMModuleInstance.global_table_data.bytes.offsetof
            + cast(
                    uint) WASMMemoryInstance.memory_data.offsetof;
        bh_assert(mem_idx == 0);
        if (!memory_regs[mem_idx].memory_data) {
            memory_regs[mem_idx].memory_data =
                cc.memory_regs[mem_idx].memory_data;
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDPTR(memory_regs[mem_idx].memory_data, module_inst_reg, jit_cc_new_const_I32(
                    cc, memory_data_offset))));
        }
        return memory_regs[mem_idx].memory_data;
    }

    JitReg memory_data_end_reg(uint mem_idx) {
        JitCompContext* cc = cc;
        JitReg module_inst_reg = module_inst_reg(frame);
        uint memory_data_end_offset = cast(uint) WASMModuleInstance.global_table_data.bytes.offsetof
            + cast(
                    uint) WASMMemoryInstance.memory_data_end.offsetof;
        bh_assert(mem_idx == 0);
        if (!memory_regs[mem_idx].memory_data_end) {
            memory_regs[mem_idx].memory_data_end =
                cc.memory_regs[mem_idx].memory_data_end;
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDPTR(memory_regs[mem_idx].memory_data_end, module_inst_reg, jit_cc_new_const_I32(
                    cc, memory_data_end_offset))));
        }
        return memory_regs[mem_idx].memory_data_end;
    }

    JitReg mem_bound_check_1byte_reg(uint mem_idx) {
        JitReg module_inst_reg = module_inst_reg(frame);
        uint mem_bound_check_1byte_offset = cast(uint) WASMModuleInstance.global_table_data.bytes.offsetof
            + cast(
                    uint) WASMMemoryInstance.mem_bound_check_1byte.offsetof;
        bh_assert(mem_idx == 0);
        if (!memory_regs[mem_idx].mem_bound_check_1byte) {
            memory_regs[mem_idx].mem_bound_check_1byte =
                cc.memory_regs[mem_idx].mem_bound_check_1byte;
            static if (UINTPTR_MAX == ulong.max) {
                _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDI64(memory_regs[mem_idx].mem_bound_check_1byte, module_inst_reg, jit_cc_new_const_I32(
                        cc, mem_bound_check_1byte_offset))));
            }
            else {
                _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDI32(memory_regs[mem_idx].mem_bound_check_1byte, module_inst_reg, jit_cc_new_const_I32(
                        cc, mem_bound_check_1byte_offset))));
            }
        }
        return memory_regs[mem_idx].mem_bound_check_1byte;
    }

    JitReg mem_bound_check_2bytes_reg(uint mem_idx) {
        JitReg module_inst_reg = module_inst_reg(frame);
        uint mem_bound_check_2bytes_offset = cast(uint) WASMModuleInstance.global_table_data.bytes.offsetof
            + cast(
                    uint) WASMMemoryInstance.mem_bound_check_2bytes.offsetof;
        bh_assert(mem_idx == 0);
        if (!memory_regs[mem_idx].mem_bound_check_2bytes) {
            memory_regs[mem_idx].mem_bound_check_2bytes =
                cc.memory_regs[mem_idx].mem_bound_check_2bytes;
            static if (UINTPTR_MAX == ulong.max) {
                _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDI64(memory_regs[mem_idx].mem_bound_check_2bytes, module_inst_reg, jit_cc_new_const_I32(
                        cc, mem_bound_check_2bytes_offset))));
            }
            else {
                _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDI32(memory_regs[mem_idx].mem_bound_check_2bytes, module_inst_reg, jit_cc_new_const_I32(
                        cc, mem_bound_check_2bytes_offset))));
            }
        }
        return memory_regs[mem_idx].mem_bound_check_2bytes;
    }

    JitReg mem_bound_check_4bytes_reg(uint mem_idx) {
        JitReg module_inst_reg = module_inst_reg(frame);
        uint mem_bound_check_4bytes_offset = cast(uint) WASMModuleInstance.global_table_data.bytes.offsetof
            + cast(
                    uint) WASMMemoryInstance.mem_bound_check_4bytes.offsetof;
        bh_assert(mem_idx == 0);
        if (!memory_regs[mem_idx].mem_bound_check_4bytes) {
            memory_regs[mem_idx].mem_bound_check_4bytes =
                cc.memory_regs[mem_idx].mem_bound_check_4bytes;
            static if (UINTPTR_MAX == ulong.max) {
                _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDI64(memory_regs[mem_idx].mem_bound_check_4bytes, module_inst_reg, jit_cc_new_const_I32(
                        cc, mem_bound_check_4bytes_offset))));
            }
            else {
                _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDI32(memory_regs[mem_idx].mem_bound_check_4bytes, module_inst_reg, jit_cc_new_const_I32(
                        cc, mem_bound_check_4bytes_offset))));
            }
        }
        return memory_regs[mem_idx].mem_bound_check_4bytes;
    }

    JitReg mem_bound_check_8bytes_reg(uint mem_idx) {
        JitReg module_inst_reg = module_inst_reg(frame);
        uint mem_bound_check_8bytes_offset = cast(uint) WASMModuleInstance.global_table_data.bytes.offsetof
            + cast(
                    uint) WASMMemoryInstance.mem_bound_check_8bytes.offsetof;
        bh_assert(mem_idx == 0);
        if (!memory_regs[mem_idx].mem_bound_check_8bytes) {
            memory_regs[mem_idx].mem_bound_check_8bytes =
                cc.memory_regs[mem_idx].mem_bound_check_8bytes;
            static if (UINTPTR_MAX == ulong.max) {
                _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDI64(memory_regs[mem_idx].mem_bound_check_8bytes, module_inst_reg, jit_cc_new_const_I32(
                        cc, mem_bound_check_8bytes_offset))));
            }
            else {
                _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDI32(memory_regs[mem_idx].mem_bound_check_8bytes, module_inst_reg, jit_cc_new_const_I32(
                        cc, mem_bound_check_8bytes_offset))));
            }
        }
        return memory_regs[mem_idx].mem_bound_check_8bytes;
    }

    JitReg mem_bound_check_16bytes_reg(uint mem_idx) {
        JitReg module_inst_reg = module_inst_reg(frame);
        uint mem_bound_check_16bytes_offset = cast(uint) WASMModuleInstance.global_table_data.bytes.offsetof
            + cast(
                    uint) WASMMemoryInstance.mem_bound_check_16bytes.offsetof;
        bh_assert(mem_idx == 0);
        if (!memory_regs[mem_idx].mem_bound_check_16bytes) {
            memory_regs[mem_idx].mem_bound_check_16bytes =
                cc.memory_regs[mem_idx].mem_bound_check_16bytes;
            static if (UINTPTR_MAX == ulong.max) {
                _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDI64(memory_regs[mem_idx].mem_bound_check_16bytes, module_inst_reg, jit_cc_new_const_I32(
                        cc, mem_bound_check_16bytes_offset))));
            }
            else {
                _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDI32(memory_regs[mem_idx].mem_bound_check_16bytes, module_inst_reg, jit_cc_new_const_I32(
                        cc, mem_bound_check_16bytes_offset))));
            }
        }
        return memory_regs[mem_idx].mem_bound_check_16bytes;
    }

    JitReg table_elems_reg(uint tbl_idx) {
        JitCompContext* cc = cc;
        JitReg module_inst = module_inst_reg(frame);
        uint offset = jit_frontend_get_table_inst_offset(cc.cur_wasm_module, tbl_idx)
            + cast(uint) WASMTableInstance.elems.offsetof;
        if (!table_regs[tbl_idx].table_elems) {
            table_regs[tbl_idx].table_elems =
                cc.table_regs[tbl_idx].table_elems;
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_ADD(table_regs[tbl_idx].table_elems, module_inst, jit_cc_new_const_PTR(
                    cc, offset))));
        }
        return table_regs[tbl_idx].table_elems;
    }

    JitReg table_cur_size_reg(uint tbl_idx) {
        JitCompContext* cc = cc;
        JitReg module_inst = module_inst_reg(frame);
        uint offset = jit_frontend_get_table_inst_offset(cc.cur_wasm_module, tbl_idx)
            + cast(uint) WASMTableInstance.cur_size.offsetof;
        if (!table_regs[tbl_idx].table_cur_size) {
            table_regs[tbl_idx].table_cur_size =
                cc.table_regs[tbl_idx].table_cur_size;
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDI32(
                    table_regs[tbl_idx].table_cur_size, module_inst, jit_cc_new_const_I32(cc, offset))));
        }
        return table_regs[tbl_idx].table_cur_size;
    }

    void clear_fixed_virtual_regs() {
        WASMModule* module_ = cc.cur_wasm_module;
        uint count = void, i = void;
        module_inst_reg = 0;
        module_reg = 0;
        import_func_ptrs_reg = 0;
        fast_jit_func_ptrs_reg = 0;
        func_type_indexes_reg = 0;
        aux_stack_bound_reg = 0;
        aux_stack_bottom_reg = 0;
        count = module_.import_memory_count + module_.memory_count;
        for (i = 0; i < count; i++) {
            memory_regs[i].memory_data = 0;
            memory_regs[i].memory_data_end = 0;
            memory_regs[i].mem_bound_check_1byte = 0;
            memory_regs[i].mem_bound_check_2bytes = 0;
            memory_regs[i].mem_bound_check_4bytes = 0;
            memory_regs[i].mem_bound_check_8bytes = 0;
            memory_regs[i].mem_bound_check_16bytes = 0;
        }
        count = module_.import_table_count + module_.table_count;
        for (i = 0; i < count; i++) {
            table_regs[i].table_elems = 0;
            table_regs[i].table_cur_size = 0;
        }
    }

    void clear_memory_regs() {
        WASMModule* module_ = cc.cur_wasm_module;
        uint count = void, i = void;
        count = module_.import_memory_count + module_.memory_count;
        for (i = 0; i < count; i++) {
            memory_regs[i].memory_data = 0;
            memory_regs[i].memory_data_end = 0;
            memory_regs[i].mem_bound_check_1byte = 0;
            memory_regs[i].mem_bound_check_2bytes = 0;
            memory_regs[i].mem_bound_check_4bytes = 0;
            memory_regs[i].mem_bound_check_8bytes = 0;
            memory_regs[i].mem_bound_check_16bytes = 0;
        }
    }

    void clear_table_regs() {
        WASMModule* module_ = cc.cur_wasm_module;
        uint count = void, i = void;
        count = module_.import_table_count + module_.table_count;
        for (i = 0; i < count; i++) {
            table_regs[i].table_cur_size = 0;
        }
    }

    JitReg gen_load_i32(ptrdiff_t n) {
        if (!lp[n].reg) {
            lp[n].reg = jit_cc_new_reg_I32(cc);
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDI32(lp[n].reg, cc.fp_reg, jit_cc_new_const_I32(
                    cc, offset_of_local(n)))));
        }
        return lp[n].reg;
    }

    JitReg gen_load_i64(ptrdiff_t n) {
        if (!lp[n].reg) {
            lp[n].reg = lp[n + 1].reg = jit_cc_new_reg_I64(cc);
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDI64(lp[n].reg, cc.fp_reg, jit_cc_new_const_I32(
                    cc, offset_of_local(n)))));
        }
        return lp[n].reg;
    }

    JitReg gen_load_f32(ptrdiff_t n) {
        if (!lp[n].reg) {
            lp[n].reg = jit_cc_new_reg_F32(cc);
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDF32(lp[n].reg, cc.fp_reg, jit_cc_new_const_I32(
                    cc, offset_of_local(n)))));
        }
        return lp[n].reg;
    }

    JitReg gen_load_f64(ptrdiff_t n) {
        if (!lp[n].reg) {
            lp[n].reg = lp[n + 1].reg = jit_cc_new_reg_F64(cc);
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_LDF64(lp[n].reg, cc.fp_reg, jit_cc_new_const_I32(
                    cc, offset_of_local(n)))));
        }
        return lp[n].reg;
    }

    void gen_commit_values() {
	gen_commit_values(lp, sp);
	}
    private void gen_commit_values(JitValueSlot* begin, JitValueSlot* end) {
        JitValueSlot* p = void;
        ptrdiff_t n = void;
        for (p = begin; p < end; p++) {
            if (!p.dirty)
                continue;
            p.dirty = 0;
            n = p - lp;
            switch (jit_reg_kind(p.reg)) {
            case JitRegKind.I32:
                _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_STI32(p.reg, cc.fp_reg, jit_cc_new_const_I32(
                        cc, offset_of_local(n)))));
                break;
            case JitRegKind.I64:
                _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_STI64(p.reg, cc.fp_reg, jit_cc_new_const_I32(
                        cc, offset_of_local(n)))));
                (++p).dirty = 0;
                break;
            case JitRegKind.F32:
                _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_STF32(p.reg, cc.fp_reg, jit_cc_new_const_I32(
                        cc, offset_of_local(n)))));
                break;
            case JitRegKind.F64:
                _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_STF64(p.reg, cc.fp_reg, jit_cc_new_const_I32(
                        cc, offset_of_local(n)))));
                (++p).dirty = 0;
                break;
            default:
                break;
            }
        }
    }
    /**
 * Generate instructions to commit SP and IP pointers to the 
 *
 * @param frame the frame information
 */
    void gen_commit_sp_ip() {
        JitReg sp = void;
        if (sp != committed_sp) {
            sp = jit_cc_new_reg_ptr(cc);
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_ADD(sp, cc.fp_reg, jit_cc_new_const_PTR(
                    cc, offset_of_local(
                    sp - lp)))));
            _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_STPTR(sp, cc.fp_reg, jit_cc_new_const_I32(
                    cc, WASMInterpFrame
                    .sp.offsetof))));
            committed_sp = sp;
        }
        version (none) { /* Disable committing ip currently */
            if (ip != committed_ip) {
                _gen_insn(cc, _jit_cc_set_insn_uid_for_new_insn(cc, jit_insn_new_STPTR(jit_cc_new_const_PTR(cc, cast(uintptr_t) frame
                        .ip), cc.fp_reg, jit_cc_new_const_I32(cc, WASMInterpip.offsetof))));
                committed_ip = ip;
            }
        }
    }
    /////
    /**
 * Generate instruction to load an integer from the 
 *
 * This and the below gen_load_X functions generate instructions to
 * load values from the frame into registers if the values have not
 * been loaded yet.
 *
 * @param frame the frame information
 * @param n slot index to the local variable array
 *
 * @return register holding the loaded value
 */
    JitReg gen_load_i32(uint n);
    /**
 * Generate instruction to load a i64 integer from the 
 *
 * @param frame the frame information
 * @param n slot index to the local variable array
 *
 * @return register holding the loaded value
 */
    JitReg gen_load_i64(uint n);
    /**
 * Generate instruction to load a floating point value from the 
 *
 * @param frame the frame information
 * @param n slot index to the local variable array
 *
 * @return register holding the loaded value
 */
    JitReg gen_load_f32(uint n);
    /**
 * Generate instruction to load a double value from the 
 *
 * @param frame the frame information
 * @param n slot index to the local variable array
 *
 * @return register holding the loaded value
 */
    JitReg gen_load_f64(uint n);
    /**
 * Generate instructions to commit computation result to the 
 * The general principle is to only commit values that will be used
 * through the 
 *
 * @param frame the frame information
 * @param begin the begin value slot to commit
 * @param end the end value slot to commit
 */
    void gen_commit_values(JitValueSlot* begin, JitValueSlot* end);
    /**
 * Generate instructions to commit SP and IP pointers to the 
 *
 * @param frame the frame information
 */
    void gen_commit_sp_ip();
    /**
 * Generate commit instructions for the block end.
 *
 * @param frame the frame information
 */
    void gen_commit_for_branch() {
        gen_commit_values(lp, sp);
    }
    /**
 * Generate commit instructions for exception checks.
 *
 * @param frame the frame information
 */
    void gen_commit_for_exception() {
        gen_commit_values(lp, lp + max_locals);
        gen_commit_sp_ip(frame);
    }
    /**
 * Generate commit instructions to commit all status.
 *
 * @param frame the frame information
 */
    void gen_commit_for_all() {
        gen_commit_values(lp, sp);
        gen_commit_sp_ip(frame);
    }

    void clear_values() {
        size_t total_size = JitValueSlot.sizeof * (max_locals + max_stacks);
        memset(lp, 0, total_size);
        committed_sp = null;
        committed_ip = null;
        clear_fixed_virtual_regs(frame);
    }

    void push_i32(JitReg value) {
        sp.reg = value;
        sp.dirty = 1;
        sp++;
    }

    void push_i64(JitReg value) {
        sp.reg = value;
        sp.dirty = 1;
        sp++;
        sp.reg = value;
        sp.dirty = 1;
        sp++;
    }

    void push_f32(JitReg value) {
        push_i32(value);
    }

    void push_f64(JitReg value) {
        push_i64(value);
    }

    JitReg pop_i32() {
        sp--;
        return gen_load_i32(sp - lp);
    }

    JitReg pop_i64() {
        sp -= 2;
        return gen_load_i64(sp - lp);
    }

    JitReg pop_f32() {
        sp--;
        return gen_load_f32(sp - lp);
    }

    JitReg pop_f64() {
        sp -= 2;
        return gen_load_f64(sp - lp);
    }

    void pop(int n) {
        sp -= n;
        memset(sp, 0, n * typeof(sp).sizeof);
    }

    JitReg local_i32(int n) {
        return gen_load_i32(n);
    }

    JitReg local_i64(int n) {
        return gen_load_i64(n);
    }

    JitReg local_f32(int n) {
        return gen_load_f32(n);
    }

    JitReg local_f64(int n) {
        return gen_load_f64(n);
    }

    void set_local_i32(int n, JitReg val) {
        lp[n].reg = val;
        lp[n].dirty = 1;
    }

    void set_local_i64(int n, JitReg val) {
        lp[n].reg = val;
        lp[n].dirty = 1;
        lp[n + 1].reg = val;
        lp[n + 1].dirty = 1;
    }

    void set_local_f32(int n, JitReg val) {
        set_local_i32(n, val);
    }

    void set_local_f64(int n, JitReg val) {
        set_local_i64(n, val);
    }

}
/* Record information of a value slot of local variable or stack
   during translation.  */
struct JitValueSlot {
    /* The virtual register that holds the value of the slot if the
       value of the slot is in register.  */
    JitReg reg;
    /* The dirty bit of the value slot. It's set if the value in
       register is newer than the value in memory.  */
    uint dirty; /*: 0 !!*/
    /* Whether the new value in register is a reference, which is valid
       only when the dirty bit is set.  */
    uint ref_; /*: 0 !!*/
    /* Committed reference flag.  -1: unknown, 1: not-reference, 2:
       reference.  */
    uint committed_ref; /*: 1 !!*/
}


