include common.mk

all: setup.sh install-lib lua rings pluto compiler

installed-vm: lua
	cp $(VM_DIR)/$(RUN) $(VM_DIR)/$(COMPILE) $(TARGET_LUA_CPATH)/

setup.sh: common.mk
	mkdir -p $(TARGET_LUA_PATH)
	mkdir -p $(TARGET_LUA_CPATH)
	echo '#!/bin/bash'                                   >  $@
	echo 'export $(ENV_PREFIX)_PATH="$(LUA_PATH)"'       >> $@
	echo 'export $(ENV_PREFIX)_CPATH="$(LUA_CPATH)"'     >> $@
	echo 'export $(ENV_PREFIX)_MPATH="$(LUA_MPATH)"'     >> $@
	chmod a+x $@

install-lib: setup.sh lib
	cp -r lib/* $(TARGET_LUA_PATH)/
lua:
	$(MAKE) -C lua/ $(PLATFORM)
rings:
	$(MAKE) -C rings/ $(PLATFORM)
pluto:
	$(MAKE) -C pluto/ $(PLATFORM)
bitlib:
	$(MAKE) -C bitlib/ $(PLATFORM)
compiler:
	$(MAKE) -C compiler/ $(PLATFORM)

.PHONY: all setup.sh lib-copy lua rings pluto compiler
