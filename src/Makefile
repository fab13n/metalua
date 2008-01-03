PLATFORMS=macosx mingw

ifneq ($(PLATFORM),) 
  include config
endif

none:
	@echo Please select one of supported platforms
	@echo $(PLATFORMS)


all: setenv.sh lib-copy lua-vm rings pluto compiler installed-vm

macosx:
	PLATFORM=macosx $(MAKE) all

mingw:
	PLATFORM=mingw $(MAKE) all

setenv.sh: config
	mkdir -p $(TARGET_LUA_PATH)
	mkdir -p $(TARGET_LUA_CPATH)
	mkdir -p $(TARGET_BIN_PATH)
	echo '#!/bin/bash'                                 >  $@
	echo 'export $(ENV_PREFIX)_INIT="require [[std]]"' >> $@
	echo 'export $(ENV_PREFIX)_PATH=$(LUA_PATH)'       >> $@
	echo 'export $(ENV_PREFIX)_CPATH=$(LUA_CPATH)'     >> $@
	echo 'export PATH=$(TARGET_BIN_PATH):$$PATH'       >> $@
	chmod a+x $@

lib-copy: setenv.sh lib
	cp -r lib/* $(TARGET_LUA_PATH)/
lua-vm:
	$(MAKE) -C lua-vm/ $(PLATFORM)

compiler:
	$(MAKE) -C compiler/

clean:
	make -C lua-vm/ clean
	make -C compiler/ clean

installed-vm: lua-vm
	cd lua-vm && cp $(LUA_BINARIES) $(TARGET_BIN_PATH)

.PHONY: all setenv.sh lib-copy lua-vm rings pluto compiler
