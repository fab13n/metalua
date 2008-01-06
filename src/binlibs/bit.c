/* Bitwise operations library */
/* (c) Reuben Thomas 2000-2008 */
/* See README for license */

/* Metalua: no automake/autoconf goo pleaaaze! :) */
/* #include "config.h" */

#include <lua.h>
#include <lauxlib.h>

/* FIXME: Should really use limits of lua_Integer (currently not given
   by Lua); the code below assumes that lua_Integer is ptrdiff_t, that
   size_t is the same as unsigned ptrdiff_t, and that lua_Number is
   floating-point and fits in a double (use of fmod). */
#ifdef BUILTIN_CAST
#define TOINTEGER(L, n, f)                      \
  ((void)(f),                                   \
   luaL_checkinteger((L), (n)))
#else
#include <stdint.h>
#include <math.h>

#define TOINTEGER(L, n, f)                                              \
  ((ptrdiff_t)(((f) = fmod(luaL_checknumber((L), (n)), (double)SIZE_MAX)), \
               (f) > PTRDIFF_MAX ? ((f) -= SIZE_MAX + 1) :              \
               ((f) < PTRDIFF_MIN ? ((f) += SIZE_MAX + 1) : (f))))
#endif

#define TDYADIC(name, op)                                 \
  static int bit_ ## name(lua_State *L) {                 \
    lua_Number f;                                         \
    lua_Integer w = TOINTEGER(L, 1, f);                   \
    lua_pushinteger(L, w op TOINTEGER(L, 2, f));          \
    return 1;                                             \
  }

#define MONADIC(name, op)                                 \
  static int bit_ ## name(lua_State *L) {                 \
    lua_Number f;                                         \
    lua_pushinteger(L, op TOINTEGER(L, 1, f));            \
    return 1;                                             \
  }

#define VARIADIC(name, op)                      \
  static int bit_ ## name(lua_State *L) {       \
    lua_Number f;                               \
    int n = lua_gettop(L), i;                   \
    lua_Integer w = TOINTEGER(L, 1, f);         \
    for (i = 2; i <= n; i++)                    \
      w op TOINTEGER(L, i, f);                  \
    lua_pushinteger(L, w);                      \
    return 1;                                   \
  }

MONADIC(cast,    +)
MONADIC(bnot,    ~)
VARIADIC(band,   &=)
VARIADIC(bor,    |=)
VARIADIC(bxor,   ^=)
TDYADIC(lshift,  <<)
TDYADIC(rshift,  >>)
TDYADIC(arshift, >>)

static const struct luaL_reg bitlib[] = {
  {"cast",    bit_cast},
  {"bnot",    bit_bnot},
  {"band",    bit_band},
  {"bor",     bit_bor},
  {"bxor",    bit_bxor},
  {"lshift",  bit_lshift},
  {"rshift",  bit_rshift},
  {"arshift", bit_arshift},
  {NULL, NULL}
};

LUALIB_API int luaopen_bit (lua_State *L) {
  luaL_openlib(L, "bit", bitlib, 0);
  return 1;
}
