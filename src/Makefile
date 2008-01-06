PLATFORMS = macosx mingw

include config

none:
	@echo Please select one of supported platforms:
	@echo $(PLATFORMS)

all: setenv.sh lua install-lua-lib install-vm binlibs compiler

$(PLATFORMS):
	PLATFORM=$@ $(MAKE) all

install-vm: lua
	cp $(LUA_VM_DIR)/$(RUN) $(LUA_VM_DIR)/$(COMPILE) $(TARGET_BIN_PATH)/

setenv.sh: config
	mkdir -p $(TARGET_BIN_PATH)
	mkdir -p $(TARGET_LUA_PATH)
	mkdir -p $(TARGET_LUA_CPATH)
	echo '#!/bin/bash'                           >  $@
	echo 'export LUA_PATH="$(LUA_PATH)"'         >> $@
	echo 'export LUA_CPATH="$(LUA_CPATH)"'       >> $@
	echo 'export LUA_MPATH="$(LUA_MPATH)"'       >> $@
	echo 'export PATH=$(TARGET_BIN_PATH):$$PATH' >> $@
	chmod a+x $@

install-lua-lib: lib
	cp -r lib/* $(TARGET_LUA_PATH)/

lua binlibs compiler:
	$(MAKE) -C $@ $(PLATFORM)

clean:
	$(MAKE) -C lua      clean
	$(MAKE) -C compiler clean
	$(MAKE) -C binlibs  clean

.PHONY: all setup.sh install-lua-lib binlibs lua compiler
