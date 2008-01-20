PLATFORMS = macosx mingw

include config

none:
	@echo Please select one of supported platforms:
	@echo $(PLATFORMS)

all: setenv.sh lua libraries install-lua binlibs compiler

$(PLATFORMS):
	PLATFORM=$@ $(MAKE) all

install-lua: lua
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

libraries: setenv.sh lib compiler
	cp -r lib/* $(TARGET_LUA_PATH)/
	@echo "Compiling libraries:"
	@for src in $$(find $(TARGET_LUA_PATH) -name '*.mlua') ; do \
		bc="$$(dirname $$src)/$$(basename $$src .mlua).luac";   \
		echo "| -> $$bc" ;                                      \
		metalua $$src -o $$bc ;                                 \
	done

lua binlibs compiler:
	$(MAKE) -C $@ $(PLATFORM)

clean:
	$(MAKE) -C lua      clean
	$(MAKE) -C compiler clean
	$(MAKE) -C binlibs  clean

.PHONY: all libraries binlibs lua compiler
