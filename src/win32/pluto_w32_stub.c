#define LUA_LIB
#include <lua.h>
#include <lauxlib.h>

LUALIB_API int luaopen_pluto_w32_stub( lua_State *L) {
  return luaopen_pluto( L);
}
