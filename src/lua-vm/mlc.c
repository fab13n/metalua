/*
** $Id: luac.c,v 1.54 2006/06/02 17:37:11 lhf Exp $
** Lua compiler (saves bytecodes to files; also list bytecodes)
** See Copyright Notice in lua.h
*/

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define luac_c
#define LUA_CORE

#include "lua.h"
#include "lauxlib.h"

#include "ldo.h"
#include "lfunc.h"
#include "lmem.h"
#include "lobject.h"
#include "lopcodes.h"
#include "lstring.h"
#include "lundump.h"
#include "lualib.h"

#define PROGNAME	"mlc"		    /* default program name */
#define	OUTPUT		"metalua.out"   /* default output file */

/* These global vars are set by doargs(), and used by pmain(). */
static int listing=0;			/* list bytecodes? */
static int dumping=1;			/* dump bytecodes? */
static int stripping=0;			/* strip debug information? */
static char Output[]={ OUTPUT };	/* default output file name */
static const char* output=Output;	/* actual output file name */
static const char* progname=PROGNAME;	/* actual program name */
static int showast=0; /* show resulting AST on stdout */
static int metabugs=0; /* show errors as compile-time crashes 
                        * rather than src syntax errors. */

static void fatal(const char* message)
{
 fprintf(stderr,"%s: %s\n",progname,message);
 exit(EXIT_FAILURE);
}

static void cannot(const char* what)
{
 fprintf(stderr,"%s: cannot %s %s: %s\n",progname,what,output,strerror(errno));
 exit(EXIT_FAILURE);
}

/* Print an error message, followed by the usage summary, then exits the
 * program with an error status.
 */
static void usage(const char* message)
{
 if (*message=='-')
  fprintf(stderr,"%s: unrecognized option " LUA_QS "\n",progname,message);
 else
  fprintf(stderr,"%s: %s\n",progname,message);
 fprintf(stderr,
 "usage: %s [options] [filenames].\n"
 "Available options are:\n"
 "  -        process stdin\n"
 "  -l       list\n"
 "  -o name  output to file " LUA_QL("name") " (default is \"%s\")\n"
 "  -p       parse only\n"
 "  -s       strip debug information\n"
 "  -v       show version information\n"
 "  --       stop handling options\n",
 progname,Output);
 exit(EXIT_FAILURE);
}

/* Used by doargs() and by pmain() */
#define	IS(s)	(strcmp(argv[i],s)==0)

/* Parse command line options, returns the index of the first
 * non-option command line parameter (normally a filename or NULL. 
 */
static int doargs(int argc, char* argv[])
{
 int i;
 int version=0;
 if (argv[0]!=NULL && *argv[0]!=0) progname=argv[0];
 for (i=1; i<argc; i++)
 {
  if (*argv[i]!='-')			/* end of options; keep it */
   break;
  else if (IS("--"))			/* end of options; skip it */
  {
   ++i;
   if (version) ++version;
   break;
  }
  else if (IS("-"))			/* end of options; use stdin */
   break;
  else if (IS("-l"))			/* list */
   ++listing;
  else if (IS("-o"))			/* output file */
  {
   output=argv[++i];
   if (output==NULL || *output==0) usage(LUA_QL("-o") " needs argument");
   if (IS("-")) output=NULL;
  }
  else if (IS("-p"))			/* parse only */
   dumping=0;
  else if (IS("-s"))			/* strip debug information */
   stripping=1;
  else if (IS("-v"))			/* show version */
   ++version;
  else if (IS("-a"))
   showast=1;
  else if (IS("-b"))
   metabugs=1;
  else					/* unknown option */
   usage(argv[i]);
 }
 if (i==argc && (listing || !dumping))
 {
  dumping=0;
  argv[--i]=Output;
 }
 if (version)
 {
  printf("%s  %s\n",LUA_RELEASE,LUA_COPYRIGHT);
  if (version==argc-1) exit(EXIT_SUCCESS);
 }
 return i;
}


/* Take a list of n functions on L's stack. If there's only one,
 * return it as is. If there are several of them, combine them 
 * in a single function, which calls each of them in sequence.
 * This version is modified w.r.t. Lua 5.1.2: when there are
 * several functions, each of them receives the command line's
 * argument in '...', whereas in original Lua, '...' was left
 * empty when several chunks were combined.
 */
static const Proto* combine(lua_State* L, int n)
{
#define toproto(L,i) (clvalue(L->top+(i))->l.p)
 if (n==1)
  return toproto(L,-1);
 else
 {
  int i,pc;
  Proto* f=luaF_newproto(L);
  setptvalue2s(L,L->top,f); incr_top(L);
  f->source=luaS_newliteral(L,"=(" PROGNAME ")");
  f->maxstacksize=2;
  f->is_vararg = VARARG_ISVARARG;
  pc=3*n+1;
  f->code=luaM_newvector(L,pc,Instruction);
  f->sizecode=pc;
  f->p=luaM_newvector(L,n,Proto*);
  f->sizep=n;
  pc=0;
  for (i=0; i<n; i++)
  {
   f->p[i]=toproto(L,i-n-1);
   f->code[pc++]=CREATE_ABx(OP_CLOSURE,0,i);
   f->code[pc++]=CREATE_ABx(OP_VARARG,1,0);
   f->code[pc++]=CREATE_ABC(OP_CALL,0,0,1);
  }
  f->code[pc++]=CREATE_ABC(OP_RETURN,0,1,0);
  return f;
 }
#undef toproto
}

/* Callback for luaU_dump(), so that bytecode is saved in a file. */
static int writer(lua_State* L, const void* p, size_t size, void* u)
{
 UNUSED(L);
 return (fwrite(p,size,1,(FILE*)u)!=1) && (size!=0);
}

struct Smain {
 int argc;
 char** argv;
};

/* Called by main():
 * - after option arguments have been removed from argc/argv
 * - with a properly setup lua_State
 * - in a cpcall(), so that errors are caught properly
 * argc & argv are passed on the lua state, in a userdata structure
 * kept on the C stack in main()'s frame.
 */
static int pmain(lua_State* L)
{
 struct Smain* s = (struct Smain*)lua_touserdata(L, 1);
 int argc=s->argc;
 char** argv=s->argv;
 const Proto* f;
 int i;

 if (!lua_checkstack(L,argc)) fatal("too many input files");

 for (i=0; i<argc; i++) {
   const char* filename=IS("-") ? NULL : argv[i];

   /* Load the default libraries */
   lua_gc(L, LUA_GCSTOP, 0);  /* stop collector during initialization */
   luaL_openlibs(L);          /* open libraries */
   lua_gc(L, LUA_GCRESTART, 0);

   if (luaL_loadfile(L,filename)!=0) fatal(lua_tostring(L,-1)); /* */
 
 if (showast) luaL_dostring( L, "mlc.showast=true");
 if (metabugs) luaL_dostring( L, "mlc.metabugs=true");

 }
 f=combine(L,argc);
 if (listing) luaU_print(f,listing>1);
 if (dumping)
 {
  FILE* D= (output==NULL) ? stdout : fopen(output,"wb");
  if (D==NULL) cannot("open");
  lua_lock(L);
  luaU_dump(L,f,writer,D,stripping);
  lua_unlock(L);
  if (ferror(D)) cannot("write");
  if (fclose(D)) cannot("close");
 }
 return 0;
}

int main(int argc, char* argv[])
{
 lua_State* L;
 struct Smain s;
 int i=doargs(argc,argv);
 argc-=i; argv+=i;
 if (argc<=0) usage("no input files given");
 L=lua_open();
 if (L==NULL) fatal("not enough memory for state");
 s.argc=argc;
 s.argv=argv;
 if (lua_cpcall(L,pmain,&s)!=0) fatal(lua_tostring(L,-1));
 lua_close(L);
 return EXIT_SUCCESS;
}
