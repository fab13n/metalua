include ../common.mk

all: $(LIBRARIES) $(M_LIBRARIES) install metalua

$(PLATFORM): all

LUA_RUN     = ../lua/lua
LUA_COMPILE = ../lua/luac

LIBRARIES =       \
	bytecode.luac \
	mlp.luac      \
	mlc.luac      


# Library which compiles an AST into a bytecode string.
BYTECODE_LUA =      \
      lopcodes.lua  \
      lcode.lua     \
      ldump.lua     \
      compile.lua   

# Library which compiles source strings into AST
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

bytecode.luac: $(BYTECODE_LUA)
	$(LUA_COMPILE) -o $@ $^

mlp.luac: $(MLP_LUA)
	$(LUA_COMPILE) -o $@ $^

# Plain lua files compilation
%.luac: %.mlua bootstrap.lua mlp.luac bytecode.luac
	$(LUA_RUN) bootstrap.lua $<

# Metalua files compilation through the bootstrap compiler
%.luac: %.lua
	$(LUA_COMPILE) -o $@ bootstrap $<

# Compiler/interpreter
metalua: metalua.luac $(LIBRARIES)
	$(LUA_RUN) metalua.luac --verbose --sharpbang '#!/usr/bin/env lua' --output metalua --file metalua.mlua

install: metalua $(LIBRARIES)
	cp metalua $(TARGET_BIN_PATH)
	cp $(LIBRARIES) $(TARGET_LUA_PATH)/

.PHONY: all lib install

clean:
	rm *.luac 