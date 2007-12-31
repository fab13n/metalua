include ../common.mk

#VM = $(TARGET_LUA_CPATH)/$(VM)

TARGETS = bytecode.luac mlp.luac mlc.luac metaluac

all: $(TARGETS) install

# Library which compiles an AST into a bytecode string.
# Written in pure lua
BYTECODE_LUA =      \
      lopcodes.lua  \
      lcode.lua     \
      ldump.lua     \
      compile.lua   

bytecode.luac: $(BYTECODE_LUA)
	../lua-vm/$(COMPILE) -o $@ $^

# Library which compiles strings into AST
MLP_LUA =           \
      lexer.lua     \
      gg.lua        \
      mlp_lexer.lua \
      mlp_misc.lua  \
      mlp_table.lua \
      mlp_meta.lua  \
      mlp_expr.lua  \
      mlp_stat.lua  \
      mlp_ext.lua 

mlp.luac: $(MLP_LUA)
	../lua-vm/$(COMPILE) -o $@ $^

# bootstrap is the minimal executable that turns a metalua source file into
# a bytecode file. It's used to generate 
BOOTSTRAP_LUA = \
      bootstrap.lua

bootstrap: $(BOOTSTRAP_LUA)
	../lua-vm/$(COMPILE) -o $@ $^

COMPILER_LUA = \
      metaluac.lua    

%.luac: %.mlua bootstrap
	../lua-vm/$(RUN) bootstrap $<

metaluac: metaluac.luac
	echo '#!$(TARGET_LUA_CPATH)/$(RUN)' > $@
	cat   $^ >> $@
	chmod a+x $@

install: $(TARGETS)
	cp $^ $(TARGET_LUA_CPATH)/

.PHONY: all install-lib

clean:
	rm *.luac $(TARGETS)