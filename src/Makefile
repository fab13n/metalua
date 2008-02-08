include config

ifeq ($(PLATFORM), none)
all:
	@echo "You haven't edited 'config' yet. Set your settings there, then run 'make' again"
else
all: setenv.sh lua libraries install-lua bin-libraries compiler compile-libraries
endif

install-lua: lua target-dirs
	cp $(LUA_VM_DIR)/$(RUN) $(LUA_VM_DIR)/$(COMPILE) $(TARGET_BIN_PATH)/

setenv.sh: config target-dirs
	echo '#!/bin/bash'                           >  $@
	echo 'export LUA_PATH="$(LUA_PATH)"'         >> $@
	echo 'export LUA_CPATH="$(LUA_CPATH)"'       >> $@
	echo 'export LUA_MPATH="$(LUA_MPATH)"'       >> $@
	echo 'export PATH=$(TARGET_BIN_PATH):$$PATH' >> $@
	chmod a+x $@


copy-libraries: lib/ target-dirs

copy-libraries: lib/
	mkdir -p $(TARGET_LUA_PATH)
	cp -Rp lib/* $(TARGET_LUA_PATH)/

compile-libraries: copy-libraries bin-libraries setenv.sh compiler
	@echo "Compiling libraries:"
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
	LUA_PATH="$(LUA_PATH)" LUA_CPATH="$(LUA_CPATH)" LUA_MPATH="$(LUA_MPATH)" $(MAKE) -C $@ $(PLATFORM)

bin-libraries:
	$(MAKE) -C binlibs	$(PLATFORM) install

lua: $@
	$(MAKE) -C $@ $(PLATFORM) 


clean:
	$(MAKE) -C lua      clean
	$(MAKE) -C compiler clean
	$(MAKE) -C binlibs  clean

target-dirs: $(TARGET_BIN_PATH) $(TARGET_LUA_PATH) $(TARGET_LUA_CPATH)

$(TARGET_BIN_PATH) $(TARGET_LUA_PATH) $(TARGET_LUA_CPATH):
	mkdir -p $@

.PHONY: all libraries lua bin-libraries copy-libraries compile-libraries compiler
