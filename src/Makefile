PLATFORMS = macosx mingw linux

include config

none:
	@echo Please select one of supported platforms:
	@echo $(PLATFORMS)

all: setenv.sh lua libraries install-lua bin-libraries compiler compile-libraries

$(PLATFORMS):
	PLATFORM=$@ $(MAKE) all

install-lua: lua
	mkdir -p $(TARGET_BIN_PATH)
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

copy-libraries: lib/
	mkdir -p $(TARGET_LUA_PATH)
	cp -Rp lib/ $(TARGET_LUA_PATH)/


#	cp -p -R lib/* $(TARGET_LUA_PATH)/

compile-libraries: copy-libraries bin-libraries setenv.sh compiler
	echo "Compiling libraries:"
	for src in $$(find $(TARGET_LUA_PATH) -name '*.mlua') ; do \
		bc="$$(dirname $$src)/$$(basename $$src .mlua).luac"; \
		if [ $$src -nt $$bc ]; then \
			echo "| COMPILING $$bc" ; \
			$(TARGET_BIN_PATH)/metalua $$src -o $$bc ; \
		else \
			echo "| up2date:  $$bc"; \
		fi \
	done

compiler: copy-libraries bin-libraries
	$(MAKE) -C $@ $(PLATFORM)

bin-libraries:
	$(MAKE) -C binlibs	$(PLATFORM) install

lua: $@
	$(MAKE) -C $@ $(PLATFORM)


clean:
	$(MAKE) -C lua      clean
	$(MAKE) -C compiler clean
	$(MAKE) -C binlibs  clean

.PHONY: all libraries lua bin-libraries copy-libraries compile-libraries compiler
