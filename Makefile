#-include local.mk
-include setup.mk

REDREC?=redrec
CTOD?=ctod
DC?=dmd
DSCANNER?=dscanner

include deps.mk
include config.mk


DFILES:=$(TARGET_DFILES)

OBJS:=$(DFILES:.d=.o)

CHECKS:=${addsuffix -check,$(DFILES)}


DEF_CFILES+=insn_opnd_tmp.d jit_ir_tmp.d
.SECONDARY: insn_opnd_tmp.c jit_ir_tmp.c


DEF_DFILES=$(DEF_CFILES:.c=.d)

DINC?=-I$(PWD)
all: $(OBJS)

ctod: $(DFILES)

check: ctod $(CHECKS)
	@#

.PHONY: all ctod check

%.d-check: %.d
	$(DSCANNER) -s $<


%.o: %.d
	$(DC) $(DINC) -c $< -of=$@

def: $(DEF_DFILES)

%.d: %.c
	echo $*
	$(CTOD) $<
	$(REDREC) $(REDREC_DFLAGS)  $@ -i


%_tmp.c: %.c
	gcc -I. -CC -P -E $< > $@


%.c:
	$(REDREC) $(REDREC_FLAGS) $< 

info:
	@echo $(DEF_DFILES)

clean:
	rm -f $(OBJS)
	rm -f $(DEF_DFILES)
	rm -f *_tmp*
	find tagion -name "*.[cd]" -exec rm -f {} \;


