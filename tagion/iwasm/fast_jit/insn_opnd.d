module tagion.iwasmd.fast_jit.insn_opnd;
import tagion.iwasm.fast_jit.jit_ir;
enum JIT_OPND_KIND : ubyte {
Reg,
VReg,
LookupSwitch
}
struct InsnOpnd {
 align (1):
 ubyte kind;
 ubyte num;
 ubyte first_use;
}
immutable(InsnOpnd[]) insn_opnd = [
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.VReg, 1, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 4, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 4, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 4, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 4, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 4, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 4, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 4, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 4, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 4, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 4, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 1, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 1, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 0),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 0),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 0),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 0),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 0),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 0),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 0),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 1, 0),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 0),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 0),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 0),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 0),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 0),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 0),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 0),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 0),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 0),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 0),
InsnOpnd(JIT_OPND_KIND.LookupSwitch, 1, 0),
InsnOpnd(JIT_OPND_KIND.VReg, 2, 1),
InsnOpnd(JIT_OPND_KIND.Reg, 4, 2),
InsnOpnd(JIT_OPND_KIND.Reg, 3, 0),
InsnOpnd(JIT_OPND_KIND.Reg, 1, 0),










];

struct JitCompContext {
    const(JitHardRegInfo)* hreg_info;
    ubyte cur_pass_no;
    WASMModule* cur_wasm_module;
    WASMFunction* cur_wasm_func;
    uint cur_wasm_func_idx;
    JitBlockStack block_stack;
    bool mem_space_unchanged;
    JitReg entry_label;
    JitReg exit_label;
    JitBasicBlock** exce_basic_blocks;
    JitIncomingInsnList* incoming_insns_for_exec_bbs;
    JitBasicBlock* cur_basic_block;
    JitReg fp_reg;
    JitReg exec_env_reg;
    JitReg cmp_reg;
    JitReg module_inst_reg;
    JitReg module_reg;
    JitReg import_func_ptrs_reg;
    JitReg fast_jit_func_ptrs_reg;
    JitReg func_type_indexes_reg;
    JitReg aux_stack_bound_reg;
    JitReg aux_stack_bottom_reg;
    JitMemRegs* memory_regs;
    JitTableRegs* table_regs;
    JitFrame* jit_frame;
    uint total_frame_size;
    uint spill_cache_offset;
    uint spill_cache_size;
    uint jitted_return_address_offset;
    void* jitted_addr_begin;
    void* jitted_addr_end;
    char[128] last_error = 0;
    ushort _reference_count;
    struct __const_val {
        uint[JitRegKind.L32] _num;
        uint[JitRegKind.L32] _capacity;
        ubyte*[JitRegKind.L32] _value;
        JitReg*[JitRegKind.L32] _next;
        uint _hash_table_size;
        JitReg* _hash_table;
    }__const_val _const_val;
    struct __Ann {
        uint _label_num;
        uint _label_capacity;
        uint _insn_num;
        uint _insn_capacity;
        uint[JitRegKind.L32] _reg_num;
        uint[JitRegKind.L32] _reg_capacity;












































































































JitBasicBlock * *_label_basic_block;
uint16 *_label_pred_num;
uint16 *_label_freq;
uint8 * *_label_begin_bcip;
uint8 * *_label_end_bcip;
uint16 *_label_end_sp;
JitReg *_label_next_label;
void * *_label_jitted_addr;
JitInsn * *_insn__hash_link;
JitInsn * *[JitRegKind.L32]_reg_def_insn;












































































































uint _label_basic_block_enabled = 1;
uint _label_pred_num_enabled = 1;
uint _label_freq_enabled = 1;
uint _label_begin_bcip_enabled = 1;
uint _label_end_bcip_enabled = 1;
uint _label_end_sp_enabled = 1;
uint _label_next_label_enabled = 1;
uint _label_jitted_addr_enabled = 1;
uint _insn__hash_link_enabled = 1;
uint _reg_def_insn_enabled = 1;
    }
 __Ann _ann;
    struct __insn_hash_table {
        uint _size;
        JitInsn** _table;
    }__insn_hash_table _insn_hash_table;
    bool last_cmp_on_fp;
}












































































































JitBasicBlock * *jit_annl_basic_block(JitCompContext *cc, JitReg label) { 
	unsigned idx = jit_reg_no(label); 
	bh_assert(jit_reg_kind(label) == JitRegKind.L32); 
	bh_assert(idx < cc._ann._label_num); bh_assert(cc._ann._label_basic_block_enabled); 
	return &cc._ann._label_basic_block[idx]; 
};
uint16 *jit_annl_pred_num(JitCompContext *cc, JitReg label) {
	unsigned idx = jit_reg_no(label); 
	bh_assert(jit_reg_kind(label) == JitRegKind.L32); 
	bh_assert(idx < cc._ann._label_num); 
	bh_assert(cc._ann._label_pred_num_enabled); 
	return &cc._ann._label_pred_num[idx]; 
};
uint16 *jit_annl_freq(JitCompContext *cc, JitReg label) { 
	unsigned idx = jit_reg_no(label); 
	bh_assert(jit_reg_kind(label) == JitRegKind.L32); 
	bh_assert(idx < cc._ann._label_num); 
	bh_assert(cc._ann._label_freq_enabled); 
	return &cc._ann._label_freq[idx]; 
};
uint8 * *jit_annl_begin_bcip(JitCompContext *cc, JitReg label) { 
	unsigned idx = jit_reg_no(label); 
	bh_assert(jit_reg_kind(label) == JitRegKind.L32); 
	bh_assert(idx < cc._ann._label_num); 
	bh_assert(cc._ann._label_begin_bcip_enabled);
	return &cc._ann._label_begin_bcip[idx];
};
uint8 * *jit_annl_end_bcip(JitCompContext *cc, JitReg label) { 
	unsigned idx = jit_reg_no(label); 
	bh_assert(jit_reg_kind(label) == JitRegKind.L32);
	bh_assert(idx < cc._ann._label_num);
	bh_assert(cc._ann._label_end_bcip_enabled);
	return &cc._ann._label_end_bcip[idx];
};
uint16 *jit_annl_end_sp(JitCompContext *cc, JitReg label) {
	unsigned idx = jit_reg_no(label);
	bh_assert(jit_reg_kind(label) == JitRegKind.L32);
	bh_assert(idx < cc._ann._label_num);
	bh_assert(cc._ann._label_end_sp_enabled);
	return &cc._ann._label_end_sp[idx];
};
JitReg *jit_annl_next_label(JitCompContext *cc, JitReg label) {
	unsigned idx = jit_reg_no(label);
	bh_assert(jit_reg_kind(label) == JitRegKind.L32);
	bh_assert(idx < cc._ann._label_num); 
	bh_assert(cc._ann._label_next_label_enabled);
	return &cc._ann._label_next_label[idx];
};
void * *jit_annl_jitted_addr(JitCompContext *cc, JitReg label) {
	unsigned idx = jit_reg_no(label);
	bh_assert(jit_reg_kind(label) == JitRegKind.L32);
	bh_assert(idx < cc._ann._label_num);
	bh_assert(cc._ann._label_jitted_addr_enabled);
	return &cc._ann._label_jitted_addr[idx];
};
YPE *jit_anni__hash_link(JitCompContext *cc, JitInsn *insn) {
	unsigned uid = insn.uid;
	bh_assert(uid < cc._ann._insn_num);
	bh_assert(cc._ann._insn__hash_link_enabled);
	return &cc._ann._insn__hash_link[uid];
};
JitInsn * *jit_annr_def_insn(JitCompContext *cc, JitReg reg) {
	unsigned kind = jit_reg_kind(reg);
	unsigned no = jit_reg_no(reg);
	bh_assert(kind < JitRegKind.L32);
	bh_assert(no < cc._ann._reg_num[kind]);
	bh_assert(cc._ann._reg_def_insn_enabled);
	return &cc._ann._reg_def_insn[kind][no];
};












































































































bool jit_annl_enable_basic_block(JitCompContext *cc);
bool jit_annl_enable_pred_num(JitCompContext *cc);
bool jit_annl_enable_freq(JitCompContext *cc);
bool jit_annl_enable_begin_bcip(JitCompContext *cc);
bool jit_annl_enable_end_bcip(JitCompContext *cc);
bool jit_annl_enable_end_sp(JitCompContext *cc);
bool jit_annl_enable_next_label(JitCompContext *cc);
bool jit_annl_enable_jitted_addr(JitCompContext *cc);
bool jit_anni_enable__hash_link(JitCompContext *cc);
bool jit_annr_enable_def_insn(JitCompContext *cc);












































































































void jit_annl_disable_basic_block(JitCompContext *cc);
void jit_annl_disable_pred_num(JitCompContext *cc);
void jit_annl_disable_freq(JitCompContext *cc);
void jit_annl_disable_begin_bcip(JitCompContext *cc);
void jit_annl_disable_end_bcip(JitCompContext *cc);
void jit_annl_disable_end_sp(JitCompContext *cc);
void jit_annl_disable_next_label(JitCompContext *cc);
void jit_annl_disable_jitted_addr(JitCompContext *cc);
void jit_anni_disable__hash_link(JitCompContext *cc);
void jit_annr_disable_def_insn(JitCompContext *cc);












































































































bool jit_annl_is_enabled_basic_block(JitCompContext *cc) { return !!cc._ann._label_basic_block_enabled; };
bool jit_annl_is_enabled_pred_num(JitCompContext *cc) { return !!cc._ann._label_pred_num_enabled; };
bool jit_annl_is_enabled_freq(JitCompContext *cc) { return !!cc._ann._label_freq_enabled; };
bool jit_annl_is_enabled_begin_bcip(JitCompContext *cc) { return !!cc._ann._label_begin_bcip_enabled; };
bool jit_annl_is_enabled_end_bcip(JitCompContext *cc) { return !!cc._ann._label_end_bcip_enabled; };
bool jit_annl_is_enabled_end_sp(JitCompContext *cc) { return !!cc._ann._label_end_sp_enabled; };
bool jit_annl_is_enabled_next_label(JitCompContext *cc) { return !!cc._ann._label_next_label_enabled; };
bool jit_annl_is_enabled_jitted_addr(JitCompContext *cc) { return !!cc._ann._label_jitted_addr_enabled; };
bool jit_anni_is_enabled__hash_link(JitCompContext *cc) { return !!cc._ann._insn__hash_link_enabled; };
bool jit_annr_is_enabled_def_insn(JitCompContext *cc) { return !!cc._ann._reg_def_insn_enabled; };
JitCompContext* jit_cc_init(JitCompContext* cc, uint htab_size);
void jit_cc_destroy(JitCompContext* cc);
 private void jit_cc_inc_ref(JitCompContext* cc) {
    cc._reference_count++;
}
