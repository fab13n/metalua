include ../config

all: stable.lua
	$(MKLIB) -o rings.$(LIBEXT) rings.$(OBJEXT)

install:
	cp rings.$(LIBEXT) $(TARGET_LUA_CPATH)/
	cp stable.lua $(TARGET_LUA_PATH)/
