/*
** $Id: linit.c,v 1.14 2005/12/29 15:32:11 roberto Exp $
** Initialization of libraries for lua.c
** See Copyright Notice in lua.h
*/


#define linit_c
#define LUA_LIB

#include "lua.h"

#include "lualib.h"
#include "lauxlib.h"


static const luaL_Reg objlibs[] = {
  {"", luaopen_base},
  {LUA_LOADLIBNAME, luaopen_package},
  {LUA_TABLIBNAME, luaopen_table},
  {LUA_IOLIBNAME, luaopen_io},
  {LUA_OSLIBNAME, luaopen_os},
  {LUA_STRLIBNAME, luaopen_string},
  {LUA_MATHLIBNAME, luaopen_math},
  {LUA_DBLIBNAME, luaopen_debug},
  {NULL, NULL}
};

static const char *lualibs[] = {
  // "metalua",
  NULL
};


LUALIB_API void luaL_openlibs (lua_State *L) {
  const luaL_Reg *objlib;
  const char **lualib;

  for (objlib  = objlibs; objlib->func; objlib++) {
    lua_pushcfunction(L, objlib->func);
    lua_pushstring(L, objlib->name);
    lua_call(L, 1, 0);
  }

  for (lualib = lualibs; *lualib; lualib++) {
    int r;
    lua_getglobal (L, "require");
    lua_pushstring (L, *lualib);
    r = lua_pcall (L, 1, 0, 0); 
    if( 0 != r) {
      const char *msg = lua_tostring( L, -1);
      if( ! msg) msg = "unprintable";
      printf( "Lua non fatal init error loading lua library '%s':\n%s\n",
              *lualib, msg);
      lua_pop( L, 1); /* Restore the stack in its original state */
    }
  }
}

