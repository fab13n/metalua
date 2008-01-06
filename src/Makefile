include common.mk

all: setup.sh lua install-lua-lib binlibs compiler

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

install-lua-lib: lib
	cp -r lib/* $(TARGET_LUA_PATH)/

lua binlibs compiler:
	$(MAKE) -C $@ $(PLATFORM)

clean:
	$(MAKE) -C lua      clean
	$(MAKE) -C compiler clean
	$(MAKE) -C binlibs  clean

# lua:
# 	$(MAKE) -C lua/ $(PLATFORM)
# binlibs:
# 	$(MAKE) -C binlibs/ $(PLATFORM)
# compiler:
# 	$(MAKE) -C compiler/ $(PLATFORM)

.PHONY: all setup.sh install-lua-lib binlibs lua compiler
