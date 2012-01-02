include ../config

all: $(LIBRARIES) install metalua

$(PLATFORM): all

LUA_RUN     = ../$(LUA_VM_DIR)/$(RUN)
LUA_COMPILE = ../$(LUA_VM_DIR)/$(COMPILE)

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

metalua.luac: mlc.luac

bytecode.luac: $(BYTECODE_LUA)
	$(LUA_COMPILE) -o $@ $^

mlp.luac: $(MLP_LUA)
	$(LUA_COMPILE) -o $@ $^

# Plain lua files compilation
%.luac: %.mlua bootstrap.lua mlp.luac bytecode.luac
	$(LUA_RUN) bootstrap.lua $<

# FIXME what's this?! some old stuff from when metalua files hadn't their own
# extensions?
# Metalua files compilation through the bootstrap compiler
%.luac: %.lua
	$(LUA_COMPILE) -o $@ bootstrap $<

# Compiler/interpreter
metalua: metalua.luac install-lib
	$(LUA_RUN) metalua.luac --verbose --sharpbang '#!$(TARGET_BIN_PATH)/lua' --output metalua --file metalua.mlua

install-lib: $(LIBRARIES)
	mkdir -p $(TARGET_LUA_PATH)/metalua
	cp $(LIBRARIES) $(TARGET_LUA_PATH)/metalua/

install: install-lib metalua
	mkdir -p $(TARGET_BIN_PATH)
	cp metalua $(TARGET_BIN_PATH)/

.PHONY: all install

clean:
	-rm *.luac metalua 
