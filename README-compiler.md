Metalua Compiler
================

## Metalua compiler

This module `metalua-compiler` depends on `metalua-parser`. Its main
feature is to compile ASTs into Lua 5.1 bytecode, allowing to convert
them into bytecode files and executable functions. This opens the
following possibilities:

* compiler objects generated with `require 'metalua.compiler'.new()`
  support methods `:xxx_to_function()` and `:xxx_to_bytecode()`;

* Compile-time meta-programming: use of `-{...}` splices in source
  code, to generate code during compilation;

* Some syntax extensions, such as structural pattern matching and
  lists by comprehension;

* Some AST manipulation facilities such as `treequery`, which are
  implemented with Metalua syntax extensions.

## What's new in Metalua 0.7

This is a major overhaul of the compiler's architecture. Some of the
most noteworthy changes are:

* No more installation or bootstrap script. Some Metalua source files
  have been rewritten in plain Lua, and module sources have been
  refactored, so that if you just drop the `metalua` folder somewhere
  in your `LUA_PATH`, it works.

* The compiler can be cut in two parts:

  * a parser which generates ASTs out of Lua sources, and should be
    either portable or easily ported to Lua 5.2;

  * a compiler, which can turn sources and AST into executable
    Lua 5.1 bytecode and run it. It also supports compile-time
    meta-programming, i.e. code included between `-{ ... }` is
    executed during compilation, and the ASTs it produces are
    included in the resulting bytecode.

* Both parts are packaged as separate LuaRocks, `metalua-parser` and
  `metalua-compiler` respectively, so that you can install the former
  without the latter.

* The parser is not a unique object anymore. Instead,
  `require "metalua.compiler".new()` returns a different compiler
  instance every time it's called. Compiler instances can be reused on
  as many source files as wanted, but extending one instance's grammar
  doesn't affect other compiler instances.

* Included standard library has been shed. There are too many standard
  libs in Lua, and none of them is standard enough, offering
  yet-another-one, coupled with a specific compiler can only add to
  confusion.

* Many syntax extensions, which either were arguably more code samples
  than actual production-ready tools, or relied too heavily on the
  removed runtime standard libraries, have been removed.

* The remaining libraries and samples are:

  * `metalua.compiler` converts sources into ASTs, bytecode,
    functions, and ASTs back into sources.

  * `metalua` compiles and/or executes files from the command line,
    can start an interactive REPL session.

  * `metalua.loader` adds a package loader which allows to use modules
    written in Metalua, even from a plain Lua program.

  * `metalua.treequery` is an advanced DSL allowing to search ASTs in
    a smart way, e.g. "_search `return` statements which return a
    `local` variable but aren't in a nested `function`_".

  * `metalua.extension.comprehension` is a language extension which
    supports lists by comprehension
    (`even = { i for i=1, 100 if i%2==0 }`) and improved loops
    (`for i=1, 10 for j=1,10 if i~=j do print(i,j) end`).

  * `metalua.extension.match` is a language extension which offers
    Haskell/ML structural pattern matching
    (``match AST with `Function{ args, body } -> ... | `Number{ 0 } -> ...end``)

   * **TODO Move basic extensions in a separate module.**

* To remove the compilation speed penalty associated with
  metaprogramming, when environment variable `LUA_MCACHE` or Lua
  variable `package.mcache` is defined and LuaFileSystem is available,
  the results of Metalua source compilations is cached. Unless the
  source file is more recent than the latest cached bytecode file, the
  latter is loaded instead of the former.

* The Luarock install for the full compiler lists dependencies towards
  Readline, LuaFileSytem, and Alt-Getopts. Those projects are
  optional, but having them automatically installed by LuaRocks offers
  a better user experience.

* The license has changed from MIT to double license MIT + EPL. This
  has been done in order to provide the IP guarantees expected by the
  Eclipse Foundation, to include Metalua in Eclipse's
  [Lua Development Tools](http://www.eclipse.org/koneki/ldt/).
