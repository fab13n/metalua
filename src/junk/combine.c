/* This should combine several functions into one, when they're already
 * compiled into functions. Useful when we don't have their AST, e.g.
 * to link several precompiled chunks into one.
 *
 * It currently doesn't work; meanwhile, one can use the original
 * 'luac' executable, although it doesn't handle argument passing through
 * "..." correctly.
 */

#include <lua.h>
#include <lapi.h>
#include <lfunc.h>
#include <lstate.h>
#include <lstring.h>
#include <lopcodes.h>
#include <ldo.h>

static int lua_combine( lua_State* L) {
  int n = lua_gettop( L); /* Number of functions to combine */
  if( 1 == n) {
    return 1; /* Only one function, nothing to combine */
  } else {
      int i, pc = 3*n + 1;
      Proto* f = luaF_newproto( L);
      setptvalue2s( L,L->top,f); 
      incr_top( L);
      f->source       = luaS_newliteral( L,"=(combiner)");
      f->maxstacksize = 2;
      f->is_vararg    = VARARG_ISVARARG;
      f->code         = luaM_newvector(L, pc, Instruction);
      f->sizecode     = pc;
      f->p            = luaM_newvector( L, n, Proto*);
      f->sizep        = n;
      for( i = pc = 0; i < n; i ++) {
        int proto_idx = i-n-1;
        Proto *p      = clvalue( L->top + proto_idx)->l.p;
        f->p[i]       = p;
        f->code[pc++] = CREATE_ABx( OP_CLOSURE, 0, i);
        f->code[pc++] = CREATE_ABx( OP_VARARG,  1, 0);
        f->code[pc++] = CREATE_ABC( OP_CALL,    0, 0, 1);
      }
      f->code[pc++]   = CREATE_ABC( OP_RETURN, 0, 1, 0);
      return 1;
    }
}

int luaopen_combine( lua_State *L) {
  lua_pushcfunction( L, lua_combine);
  lua_setglobal( L, "combine");
  return 0;
}
