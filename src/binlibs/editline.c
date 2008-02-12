#include <stdlib.h>
#include <stdio.h>
#include <histedit.h>
#include <lua.h>
#include <lauxlib.h>
#include <string.h>

#define MOD_NAME "editline"
#define DEFAULT_PROMPT "> "
#define DEFAULT_HIST_NAME "metalua"

struct el_userdata {
  EditLine   *el;
  History    *hist;
  lua_State  *L;
  char       *prompt;
  HistEvent   hev;
};

/* static const lua_CFunction init, read, close, set; */
static int init( lua_State *L);
static int read( lua_State *L);
static int close( lua_State *L);
static int setf( lua_State *L);

static const struct luaL_Reg REG_TABLE[] = {
  { "init",  init  },
  { "read",  read  },
  { "close", close },
  { "__gc",  close },
  { "__newindex", setf }, 
  { NULL,    NULL  } };

int luaopen_editline( lua_State *L) {
  /* Create the module. */
  luaL_register( L, MOD_NAME, REG_TABLE);  

  /* Set the module as editline's metatable */  
  lua_pushvalue( L, -1);
  lua_setfield( L, LUA_REGISTRYINDEX, MOD_NAME);

  /* Set the table as its own __index metamethod */
  lua_pushvalue( L, -1);
  lua_setfield( L, -2, "__index");

  /* printf( "Editline binary registered\n"); */

  return 1;
}

static int setf( lua_State *L) {
  struct el_userdata *u = luaL_checkudata( L, 1, MOD_NAME);
  const  char *key     = luaL_checkstring( L, 2);
  if( ! strcmp( key, "prompt")) {
    const char *prompt = luaL_checkstring( L, 3);
    realloc( u->prompt, strlen( prompt));
    strcpy( u->prompt, prompt);
  } else {   
    luaL_error( L, "invalid field in editline");
  }
  return 0;
}  

static char *prompt( EditLine *el) {
  /* Hack Hack Hack: the address of el_userdata is the same as
   * its el field's. */
  struct el_userdata *u;
  el_get( el, EL_CLIENTDATA, &u);
  return u->prompt;
}

#include <dlfcn.h>

static int init( lua_State *L) {
  /* Allocate the structure and initialize its fields */
  const char *name      = luaL_optstring( L, 1, DEFAULT_HIST_NAME);
  struct el_userdata *u = lua_newuserdata( L, sizeof( *u));

  u->el = el_init( name, stdin, stdout, stderr);
  if( ! u->el) luaL_error( L, "can't create editline object");
  u->hist = history_init();
  if( ! u->hist) luaL_error( L, "can't create editline history");
  u->L = L;
  u->prompt = (char *) malloc( sizeof( DEFAULT_PROMPT));
  strcpy( u->prompt, DEFAULT_PROMPT);

  /* Set its metatable; if necessary, create the metatable. */
  luaL_newmetatable( L, MOD_NAME);
  lua_setmetatable( L, -2);

  /* Some basic settings */
  history( u->hist, & u->hev, H_SETSIZE, 800);
  el_set( u->el, EL_PROMPT, & prompt);
  el_set( u->el, EL_EDITOR, "emacs");
  el_set( u->el, EL_HIST,   history, u->hist);
  el_set( u->el, EL_CLIENTDATA, u);
  return 1;
}

static int close( lua_State *L) {
  struct el_userdata *u = luaL_checkudata( L, 1, MOD_NAME);
  free( u->prompt);
  history_end( u->hist);
  el_end( u->el);
  return 0;
}

static int read( lua_State *L) {
  struct el_userdata *u = luaL_checkudata( L, 1, MOD_NAME);
  const char *p = luaL_optstring( L, 2, NULL);
  char *old_p = NULL;
  int count;
  const char *line;
  if( p) { old_p = u->prompt; u->prompt = (char*) p; }
  line = el_gets( u->el, & count);
  if( p) { u->prompt = old_p; }
  if( line) {
    if (count > 0) history(u->hist, & u->hev, H_ENTER, line);
    lua_pushlstring( L, line, count);
  } else {
    lua_pushnil( L);
  }
  return 1;
}

