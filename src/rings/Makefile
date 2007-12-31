include ../common.mk

all: rings.o stable.lua
	$(MKLIB) -o rings.$(LIBEXT) rings.$(OBJEXT)
	cp rings.$(LIBEXT) $(TARGET_LUA_CPATH)/
	cp stable.lua $(TARGET_LUA_PATH)/
