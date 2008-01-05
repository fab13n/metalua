VM_DIR           = lua
CC               = gcc
CFLAGS           = -g3 -Wall -ansi -I../lua
OBJEXT           = o
TARGET_LUA_PATH  = /tmp/lua
TARGET_LUA_CPATH = $(TARGET_LUA_PATH)
TARGET_BIN_PATH  = /tmp
COMPILE          = lua
RUN              = luac
ENV_PREFIX       = LUA
PLATFORM         = macosx
LIBEXT           = so

ifeq ($(PLATFORM),macosx)
  MKLIB         = gcc -bundle -undefined dynamic_lookup
else
  MKLIB         = I DONT HAVE A CLUE HOW TO COMPILE ON YOUR OS
endif

LUA_PATH_DIRS = ./?.EXT;$(TARGET_LUA_PATH)/?.EXT
LUA_PATH      = $(subst EXT,luac,$(LUA_PATH_DIRS));$(subst EXT,lua,$(LUA_PATH_DIRS))
LUA_MPATH     = $(subst EXT,mlua,$(LUA_PATH_DIRS))
LUA_CPATH     = $(TARGET_LUA_CPATH)/?.$(LIBEXT);$(TARGET_LUA_CPATH)/?/linit.$(LIBEXT)

