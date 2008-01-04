VM_DIR           = lua
CC               = gcc
CFLAGS           = -g3 -Wall -ansi -I ../lua-vm
OBJEXT           = o
TARGET_LUA_PATH  = /tmp/lua
TARGET_LUA_CPATH = $(TARGET_LUA_PATH)
COMPILE          = lua
RUN              = luac
ENV_PREFIX       = LUA
PLATFORM         = macosx

ifeq ($(PLATFORM),macosx)
  LIBEXT        = dylib
  MKLIB         = gcc -bundle -undefined dynamic_lookup
else
  LIBEXT        = so
  MKLIB         = I DONT HAVE A CLUE, uname is $(UNAME)
endif

LUA_PATH_DIRS = ./?.EXT;$(TARGET_LUA_PATH)/?.EXT
LUA_PATH      = "$(subst EXT,lua,$(LUA_PATH_DIRS));$(subst EXT,luac,$(LUA_PATH_DIRS))"
LUA_CPATH     = "$(TARGET_LUA_CPATH)/?.$(LIBEXT);$(TARGET_LUA_CPATH)/?/linit.$(LIBEXT)"

