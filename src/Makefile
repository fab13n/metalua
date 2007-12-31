include common.mk

all: setup.sh lib-copy lua-vm rings pluto compiler installed-vm

installed-vm: lua-vm
	cp lua-vm/$(RUN) lua-vm/$(COMPILE) $(TARGET_LUA_CPATH)/

setup.sh: common.mk
	mkdir -p $(TARGET_LUA_PATH)
	mkdir -p $(TARGET_LUA_CPATH)
	echo '#!/bin/bash'                                 >  $@
	echo 'export $(ENV_PREFIX)_INIT="require [[std]]"' >> $@
	echo 'export $(ENV_PREFIX)_PATH=$(LUA_PATH)'       >> $@
	echo 'export $(ENV_PREFIX)_CPATH=$(LUA_CPATH)'     >> $@
	chmod a+x $@

lib-copy: setup.sh lib
	cp -r lib/* $(TARGET_LUA_PATH)/
lua-vm:
	$(MAKE) -C lua-vm/ $(PLATFORM)
rings:
	$(MAKE) -C rings/ $(PLATFORM)
pluto:
	$(MAKE) -C pluto/ $(PLATFORM)
bitlib:
	$(MAKE) -C bitlib/ $(PLATFORM)
compiler:
	$(MAKE) -C compiler/ $(PLATFORM)

.PHONY: all setup.sh lib-copy lua-vm rings pluto compiler
