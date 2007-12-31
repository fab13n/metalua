include ../common.mk

all: pluto.$(LIBEXT)
	cp $+ $(TARGET_LUA_CPATH)

macosx: all

pluto.$(LIBEXT): pluto.$(OBJEXT)
	$(MKLIB) -o $@ $+
