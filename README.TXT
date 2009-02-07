README.TXT
==========
For installation matters, cf. INSTALL.TXT

Metalua 0.5
===========

Metalua is a static metaprogramming system for Lua: a set of tools
that let you alter the compilation process in arbitrary, powerful and
maintainable ways. For the potential first-time users of such a
system, a descripition of these tools, as implemented by Metalua,
follows.

Dynamic Parsers
---------------

One of the tools is the dynamic parser, which allows a source file to
change the grammar recognized by the parser, while it's being
parsed. Taken alone, this feature lets you make superficial syntax
tweaks on the language. The parser is based on a parser combinator
library called 'gg'; you should know the half dozen functions in gg
API to do advanced things:

- There are a couple of very simple combinators like gg.list,
  gg.sequence, qq.multisequence, gg.optkeyword etc. that offer a level
  of expressiveness comparable to Yacc-like parsers. For instance, if
  mlp.expr parses Lua expressions, gg.list{ mlp.expr } creates a
  parser which handles lists of Lua expressions.

- Since you can create all the combinators you can think of (they're
  regular, higher-order functions), there also are combinators
  specialized for typical language tasks. In Yacc-like systems, the
  language definition quickly becomes unreadable, because all
  non-native features have to be encoded in clumsy and brittle ways.
  So if your parser won't natively let you specify infix operator
  precedence and associativity easily, tough luck for you and your
  code maintainers. With combinators OTOH, most of such useful
  functions already exist, and you can write your owns without
  rewriting the parser itself. For instance, adding an infix operator
  would just look like:

  > mlp.expr.infix:add{ "xor", prec=40, assoc='left', builder=xor_builder }

  Moreover, combinators tend to produce usable error messages when fed
  with syntactically incorrect inputs. It matters, because clearly
  explaining why an invalid input is invalid is almost as important as
  compiling a valid one, for a use=able compiler.

Yacc-like systems might seem simpler to adopt than combinators, as
long as they're used on extremely simple problems. However, if you
either try to write something non trivial, or to write a simple macro
in a robust way, you'll need to use lots of messy tricks and hacks,
and spend much more time getting them (approximately) right than
that 1/2 hour required to master the regular features of gg.


Real meta-programming
---------------------

If you plan to go beyond trivial keyword-for-keyword syntax tweaks,
what will limit you is not syntax definition, but the ability to
manipulate source code conveniently: without the proper tools and
abstractions, even the simplest tasks will turn into a dirty hacks
fest, then either into a maintenance nightmare, or simply into
abandonware. Providing an empowering framework so that you don't get
stuck in such predicaments is Metalua's whole purpose.  The central
concept is that programs prefer to manipulate code as trees, whereas
most developers prefer ASCII sources, so both representations must be
freely interchangeable. The make-or-break deal is then:

- To easily let users see sources as trees, as sources, or as
  combination thereof, and switch representations seamlessly.

- To offer the proper libraries, that won't force you to reinvent a
  square wheel, will take care of the most common pitfalls, won't
  force you to resort to brittle hacks.

On the former point, Lisps are at a huge advantage, their user syntax
already being trees. But languages with casual syntax can also offer
interchangeable tree/source views; Metalua has some quoting +{ ... }
and anti-quoting -{ ... } operators which let you switch between both
representations at will: internally it works on trees, but you always
have the option to see them as quoted sources. Metalua also supports a
slightly improved syntax for syntax trees, to improve their
readability.

Library-wise, Metalua offers a set of syntax tree manipulation tools:

- Structural pattern matching, a feature traditionally found in
  compiler-writing specialized languages (and which has nothing to do
  with string regular expressions BTW), which lets you express
  advanced tree analysis operations in a compact, readable and
  efficient way.  If you have to work with advanced data structures
  and you try it, you'll never go back.

- The walker library allows you to perform transformations on big
  portions of programs. It lets you easily express things like:
  "replace all return statements which aren't in a nested function by
  error statements", "rename all local variables and their instances
  into unique fresh names", "list the variables which escape this
  chunk's scope", "insert a type-checking instruction into every
  assignments to variable X", etc. Most of non-trivial macros will
  require some of those global code transformations, if you really want
  them to behave correctly.

- Macro hygiene, although not perfect yet in Metalua, is required if
  you want to make macro writing reasonably usable (and contrary to a
  popular belief, renaming local variables into fresh names only
  address the easiest part of the hygiene issue; cf. changelog below
  for more details).

- The existing extensions are progressively refactored in more modular
  ways, so that their features can be effectively reused in other
  extensions.


Noteworthy changes from 0.4.1 to 0.5
====================================

Simplification of the install and structure:

- This release is included in Lua for Windows, so it now couldn't get simpler
  for MS-Windows users!

- Metalua is written in pure Lua again, thus making it platform-independant. 
  No more mandatory C libraries. Pluto interface might be back, as an option,
  in a future version, but it's not worth the install trouble involved by
  DLL dependencies.

- Simpler build process, just run make.sh or make.bat depending on your OS.

- Metalua libraries are now in a separate metalua/* package. This allows to
  mix them with other Lua libraries, and to use them from plain Lua programs
  if you FIXME


Other changes:

- new option -S in metalua: prints sources re-generated from AST, after macro
  expansion.

- compatible with more Lua VMs: 64 bits numbers, integral numbers, big endians...

- some new extensions: xloop, xmatch, improved match.

- ASTs now keep track of the source extract that generated them (API is not 
  mature though, it will be changed and broken).

- improved table printer: support of a plain-Lua mode, alternative indentation 
  mode for deeply-nested tables.

- added a generic table serializer, which handles shared and recursive 
  sub-tables correctly.

- gg API has been made slightly more flexible, as a first step towards a
  comprehensive syntax support for gg grammar definition. Follow the gg-syntax
  branch on github for ongoing work.


Noteworthy changes from 0.4 to 0.4.1
====================================

- Proper reporting of runtime errors
- Interactive REPL loop
- Support for 64 bits architectures
- Update to Pluto 2.2 and Lua 5.1.3
- Build for Visual Studio .NET

Notworthy changes from 0.3 to 0.4
=================================

- A significantly bigger code base, mostly due to more libraries:
  about 2.5KLoC for libs, 4KLoC for the compiler. However, this remains
  tiny in today's desktop computers standards. You don't have to know
  all of the system to do useful stuff with it, and since compiled
  files are Lua 5.1 compatible, you can keep the "big" system on a
  development platform, and keep a lightweight runtime for embedded or
  otherwise underpowered targets.


- The compiler/interpreter front-end is completely rewritten. The new
  frontend program, aptly named 'Metalua', supports proper passing of
  arguments to programs, and is generally speaking much more user
  friendly than the mlc from the previous version.


- Metalua source libraries are looked for in environmemt variable
  LUA_MPATH, distinct from LUA_PATH. This way, in an application
  that's part Lua part Metalua, you keep a natural access to the
  native Lua compiler.

  By convention, Metalua source files should have extension .mlua. By
  default, bytecode and plain lua files have higher precedence than
  Metalua sources, which lets you easily precompile your libraries.


- Compilation of files are separated in different Lua Rings: this
  prevents unwanted side-effects when several files are compiled
  (This can be turned off, but shouldn't be IMO).


- Metalua features are accessible programmatically. Library
  'Metalua.runtime' loads only the libraries necessary to run an
  already compiled file; 'Metalua.compile' loads everything useful at
  compile-time.

  Transformation functions are available in a library 'mlc' that
  contains all meaningful transformation functions in the form
  'mlc.destformat_of_sourceformat()', such as 'mlc.luacfile_of_ast()',
  'mlc.function_of_luastring()' etc. This library has been
  significantly completed and rewritten (in Metalua) since v0.3.


- Helper libraries have been added. For now they're in the
  distribution, at some point they should be luarocked in. These
  include:
  - Lua Rings and Pluto, duct-taped together into Springs, an improved
    Rings that lets states exchange arbitrary data instead of just
    scalars and strings. Since Pluto requires a (minor) patch to the
    VM, it can be disabled.
  - Lua bits for bytecode dumping.
  - As always, very large amounts of code borrowed from Yueliang.
  - As a commodity, I've also packaged Lua sources in.


- Extensions to Lua standard libraries: many more features in table
  and the baselib, a couple of string features, and a package system
  which correctly handles Metalua source files.


- Builds on Linux, OSX, Microsoft Visual Studio. Might build on mingw
  (not tested recently, patches welcome). It's easily ported to all
  systems with a full support for lua, and if possible dynamic
  libraries.

  The MS-windows building is based on a dirty .bat script, because
  that's pretty much the only thing you're sure to find on a win32
  computer. It uses Microsoft Visual Studio as a compiler (tested with
  VC++ 6).

  Notice that parts of the compiler itself are now written in Metalua,
  which means that its building now goes through a bootstrapping
  stage.


- Structural pattern matching improvements:
  - now also handles string regular expressions: 'someregexp'/pattern
    will match if the tested term is a string accepted by the regexp,
    and on success, the list of captures done by the regexp is matched
    against pattern.
  - Matching of multiple values has been optimized
  - the default behavior when no case match is no to raise an error,
    it's the most commonly expected case in practice. Trivial to
    cancel with a final catch-all pattern.
  - generated calls to type() are now hygienic (it's been the cause of
    a puzzling bug report; again, hygiene is hard).


- AST grammar overhaul: 
  The whole point of being alpha is to fix APIs with a more relaxed
  attitude towards backward compatibility. I think and hope it's the
  last AST revision, so here is it:
  - `Let{...} is now called `Set{...} 
    (Functional programmers would expect 'Let' to introduce an
    immutable binding, and assignment isn't immutable in Lua)
  - `Key{ key, value } in table literals is now written `Pair{ key, value }
    (it contained a key *and* its associated value; besides, 'Pair' is
    consistent with the name of the for-loop iterator)
  - `Method{...} is now `Invoke{...}
    (because it's a method invocation, not a method declaration)
  - `One{...} is now `Paren{...} and is properly documented
    (it's the node representing parentheses: it's necessary, since
    parentheses are sometimes meaningful in Lua)
  - Operator are simplified: `Op{ 'add', +{2}, +{2} } instead of
    `Op{ `Add, +{2}, +{2} }. Operator names match the corresponding
    metatable entries, without the leading double-underscore.
  - The operators which haven't a metatable counterpart are
    deprecated: 'ne', 'ge', 'gt'.

 
- Overhaul of the code walking library:
  - the API has been simplified: the fancy predicates proved more
    cumbersome to use than a bit of pattern matching in the visitors.
  - binding identifiers are handled as a distinct AST class
  - walk.id is scope-aware, handles free and bound variables in a
    sensible way.
  - the currified API proved useless and sometimes cumbersome, it's
    been removed.


- Hygiene: I originally planned to release a full-featured hygienic
  macro system with v0.4, but what exists remains a work in
  progress. Lua is a Lisp-1, which means unhygienic macros are very
  dangerous, and hygiene a la Scheme pretty much limits macro writing
  to a term rewriting subset of the language, which would be crippling
  to use.

  Note: inside hygiene, i.e. preventing macro code from capturing
  variables in user code, is trivial to address through alpha
  conversion, it's not the issue. The trickier part is outside
  hygiene, when user's binders capture globals required by the
  macro-generated code. That's the cause of pretty puzzling and hard
  to find bugs. And the *really* tricky part, which is still an open
  problem in Metalua, is when you have several levels of nesting
  between user code and macro code. For now this case has to be
  hygienized by hand.

  Note 2: Converge has a pretty powerful approach to hygienic macros
  in a Lisp-1 language; for reasons that would be too long to expose
  here, I don't think its approach would be the best suited to Metalua.
  But I might well be proved wrong eventually.

  Note 3: Redittors must have read that Paul Graham has released Arc,
  which is also a Lisp-1 with Common Lisp style macros; I expect this
  to create a bit of buzz, out of which might emerge proper solutions
  the macro hygiene problem.


- No more need to create custom syntax for macros when you don't want
  to. Extension 'dollar' will let you declare macros in the dollar
  table, as in +{block: function dollar.MYMACRO(a, b, c) ... end},
  and use it as $MYMACRO(1, 2, 3) in your code.

  With this extension, you can write macros without knowing anything
  about the Metalua parser. Together with quasi-quotes and automatic
  hygiene, this will probably be the closest we can go to "macros for
  dummies" without creating an unmaintainable mess generator.

  Besides, it's consistent with my official position that focusing on
  superficial syntax issues is counter-productive most of the time :)


- Lexers can be switched on the fly. This lets you change the set of
  keywords temporarily, with the new gg.with_lexer() combinator. You
  can also handle radically different syntaxes in a single file (think
  multiple-languages systems such as LuaTeX, or programs+goo as PHP).


- Incorporation of the bug fixes reported to the mailing list and on
  the blog.


- New samples and extensions, in various states of completion:

  * lists by comprehension, a la python/haskell. It includes lists
    chunking, e.g. mylist[1 ... 3, 5 ... 7]

  * anaphoric macros for 'if' and 'while' statements: with this
    extension, the condition of the 'if'/'while' is bound to variable
    'it' in the body; it lets you write things like:

    > while file:read '*l' do print(it) end.

    No runtime overhead when 'it' isn't used in the body. An anaphoric
    variable should also be made accessible for functions, to let
    easily write anonymous recursive functions.

  * Try ... catch ... finally extension. Syntax is less than ideal,
    but the proper way to fix that is to refactor the match extension
    to improve code reuse. There would be many other great ways to
    leverage a refactored match extension, e.g. destructuring binds or
    multiple dispatch methods. To be done in the next version.

  * with ... do extension: it uses try/finally to make sure that
    resources will be properly closed. The only constraint on
    resources is that they have to support a :close() releasing method.
    For instance, he following code guarantees that file1 and file2
    will be closed, even if a return or an error occurs in the body.

    > with file1, file2 = io.open "f1.txt", io.open "f2.txt" do
    >    contents = file1:read'*a' .. file2:read ;*a'
    > end

  * continue statement, logging facilities, ternary "?:" choice
    operator, assignments as expressions, and a couple of similarly
    tiny syntax sugar extensions.


You might expect in next versions
=================================
The next versions of Metalua will provide some of the following
improvements, in no particular order: better error reporting,
especially at runtime (there's a patch I've been too lazy to test
yet), support for 64 bits CPUs, better support for macro hygiene, more
samples and extensions, an adequate test suite, refactored libraries.


Credits
=======

I'd like to thank the people who wrote the open source code which
makes Metalua run: the Lua team, the authors of Yueliang, Pluto, Lua
Rings, Bitlib; and the people whose bug reports, patches and
insightful discussions dramatically improved the global design,
including John Belmonte, Vyacheslav Egorov, David Manura, Olivier
Gournet, Eric Raible, Laurence Tratt, Alexander Gladysh, Ryan
Pusztai...
