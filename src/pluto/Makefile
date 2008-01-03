include ../config

all: pluto.$(LIBEXT)
	cp $+ $(TARGET_LUA_CPATH)

pluto.$(LIBEXT):
	echo $(PLATFORM)
	$(MKLIB) -o $@ pluto.$(OBJEXT)
