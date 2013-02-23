Tidal Lock: Gradual Static Typing for Lua
=========================================

Tidal Lock is a static analyzer for Lua, which allows to mix
statically and dynamically typed Lua code. It relies on type
annotations, i.e. on a simple extension of Lua's grammar, although a
comments-based annotation system could easily be designed for it, thus
retaining full Lua compatibility.

The ability to mix static types with dynamic parts is based on Jeremy
Siek's gradual typing approach. This means that a fairly strict type
system can be used, even if it can't support some important idioms, or
sometimes requires prohibitive amounts of annotations: when it isn't
worth it, just turn it off with a dynamic type.

For an in-depth study of gradual typing, please refer to
http://ecee.colorado.edu/~siek/gradualtyping.html. Some further
publications by Siek and others detail how to integrate gradual types
with subtyping and type inference.

The type system relies on partial type inference: when a program
isn't fully annotated, it tries to guess the missing annotations, and
will cause an error if it finds an inconsistency in the process. For
instance, when calling a typed function with untyped arguments, it
will infer types for the latter. Otherwise, no type errors could be
found in untyped program fragments, thus dramatically reducing the
system's interest.


Current state
=============

Tidal Lock is a work in progress, in a early stage. At its core is a
formal essay describing the underlying type system; it still misses
some key parts, most prominently a soundness theorem demonstration.

The compiler is, at this stage, still an exploratory tool to test the
paper's theories. It's written in Metalua, an self-extensible dialect
of Lua which supports interesting code manipulation features (it
analyses regular Lua code, though). since Metalua hasn't been ported
to Lua 5.2, Tidal Lock currently only targets Lua 5.1.

The current compiler only recognizes a subset of Lua, exhibiting the
parts of the language most interesting and challenging to type.
Unsupported parts of the language therefore fall in two categories:

* reasonably easy to support, but of limited theoretical interest;
* so hard to type that they probably aren't worth it. The magic of
  gradual typing is that they will remain usable, simply they'll
  remain dynamically typed.

The subset of the language currently supported is:

* local variables declaration and use;
* assignments (in multiple variables and/or table slots);
* functions (multiple parameters and returned values, but no "..."
  ellipsis);
* return statements;
* table literals;
* function calls;
* table indexing;
* primitives (strings, numbers, booleans, nil).

Binary operators, if/then/else and loops will soon be added, to allow
useful programs.


Available types
===============

Dynamic type
------------

The dynamic type is written `*`, as a wildcard. An object of this type
is accepted everywhere (as the `bottom` type found in many formal type
systems), and every object is allowed to have type `*`
(as the `top` type in formal systems).

The key insight of gradual typing is that although `*` shares top and
bottom's defining characteristics, it's distinct from both, and
orthogonal with respect to the subtyping relationship. This allows to
integrate it in a sound type system, without collapsing the whole
subtyping by forcing `top=bottom`.

A gradual type system doesn't have the soundness property ("a well
typed program can't cause an error"), but it offers a weaker version
thereof: a program that causes an error can only do so because of a
dynamically typed fragment.

Please refer to Jeremy Siek, especially "Gradual Typing for Objects"
[1] for formal developments.

[1] http://ecee.colorado.edu/~siek/pubs/pubs/2006/siek06_sem_cpp.pdf


Primitive expression types
--------------------------

`nil, boolean, number, string`.


Table types
-----------

`[e1: F1, ..., en: En | Fd]` is the type of a table which associates a
value of type `F1` to the primitive expression `e1`, `F2` to `e2`,
etc. `Fn` to `en`, and type `Fd` to all other keys not explicitly
listed before. The default `Fd` type is normally some variant of
`nil`.

Types `Fn` are "field types", i.e. they're annotated with
accessibility modifiers such as `var` or `const`, which will be
described later.

For instance, `{x=1, y="abc"}` could be typed
`["x": var number, "y": const string | const nil]`.

For tables used as real hashtables or lists, rather than as records, a
generic hashtable parametrized with key type and value type `[E=>F]`
can easily be added to the system. By making the key type and/or the
value type dynamic, we can further relax the constraints on a table's
content. Such facilities haven't been put in the type system yet,
though.

We'll admit as syntax sugar that `[pn: En]` is a shortcut for
`[pn: En | field]` (cf. below "Field types" for the signification of
`field`).


Local variable types
--------------------

As table values, variables are annotated with "field types", i.e.
accessibility modifiers. A noteworthy modifier is `currently`, which
allows to change a variable's type within a program. It is necessary
to type many idiomatic Lua programs, as we shall see later.


Expression sequence types
-------------------------

Expression sequences have a central importance in Lua: functions
return them, take them as parameters, and they are are unpacked by
variable assignment statements. Type sequences are explicitly
surrounded with parentheses, as in `(number, string)`.

An expression sequence and its type sequence don't necessarily have
the same length, e.g. `x, y()` might have a type of length 3 if
function `y` returns 2 values.


Function types
--------------

Functions types are written as an arrow between the parameters
sequence and the results sequence, e.g. `(number, string) ->
(boolean)`.


Field types
-----------

As mentioned above, variables and table fields (collectively referred
to as "slots") are decorated with modifiers. These modifiers can be:

* `var E`: the slot contains a value of type `E`. This content can be
  changed for another expression of type `E`.
* `const E`: the slot contains a value of type `E`, and its content
  can't be changed.
* `currently E`: the slot contains a value of type `E`. This content
  can be changed for another expression, whose type can be different
  from `E`. There are restrictions on how those slots can be used, so
  that the type system can keep track of their type.
* `field`: the slot's content is unknown, private. The type system
  will neither let read nor change this content.

The `currently` modifier is unusual. Its main purpose is to soundly
type idiomatic fragments such as `M={ }; M.f1=function() ... end`,
where a table's type changes gradually as methods and/or fields are
added in it.

A `just` modifier appears transiently in the typing rules, but users
don't need to bother about it.

Some remarks about the type system
==================================

Static duck typing
------------------

Subtyping and type equality are structural: two tables are equal if
and only if all their fields are equal. This is in contrast with
languages inspired from C, where two `struct`s or `class`es with the
same fields but different `typedef` names aren't comparable.


Subtyping
---------

An important property of many type system is subtyping: which type can
be substituted with which other. As mentioned above, Tidal Lock uses
structural type comparisons. We define a partial order over field
types and expression types, `E1 <: E2`, which means that `E1` is a
subtype of `E2`. The consequence `E1` being a subtype of `E2` is that
everywhere a term of type `E2` is accepted, a term of type `E1` must
also be accepted.

Subtyping is defined as follows:

* `var E <: const E`.

* `const E1 <: const E2` iff `E1 <: E2`.

* `const E <: field`.

* `var E <: field` (this could actually be inferred in two steps from
  `var E <: const E <: field`).

* `currently E <: field`.

* `[p1:F1...pn:Fn|Fd] <: [p1:F1'...pn:Fn'|Fd']` iff `Fx <: Fx'` for
  all `x`, and `Fd <: Fd'`. Adjust for fields reordering and expansion
  of the default type; for instance,
  `[x:var number; y:var number | const nil] <:
   [y:var number; x:var number; z:const nil | const nil]`.

* `(Ei1...Ein) -> (Eo1...Eom) <:(Ei1'...Ein') -> (Eo1'...Eom')` iff
  `Eix' <: Eix` and `Eox <: Eox'` for all `x`. Adjust for `nil` types
  on the right, which can be omitted; for instance, `(point, nil) ->
  ()  <: (colored_point) -> (nil)`. Notice the reversed direction of
  the `<:` operator on parameters.

Notice that we don't have `var E1 <: var E2`, even if `E1 <: E2`. This
means that an object of type `[p: var colored_point]` cannot be used
where a `[p: var point]` is expected, even if `colored_point <:
point`. Indeed, the latter's `p` field can be updated with a
non-colored point, whereas it would be illegal on the former.

The fact that subtyping doesn't "go through" `var` modifiers is called
`var`'s invariance. It follows from the fact that one can write in
`var` slots. By contrast, `const` is said to be covariant
(`[p:const colored_point] <:[p:const point]`), and enjoys this
property because users are forbidden from writing in it.

There's also no subtyping relationship between `currently` and `var`:
only the former can change its content's type, and the latter can be
used in more contexts, because it's easier for the type system to keep
track of it (more on this below); as a consequence, neither can be
substituted for the other, there's no subtyping between them.

"currently" types
-----------------

This is certainly the most unusual feature of the type system. We
allow to change a variable's type, as long as the type system can keep
track of it statically. The main use is to gradually add new fields
and methods in an initially empty table. This requires to forbid some
operations; more precisely, it requires to make sure that the content
of `currently` slots cannot be reached from more than one path. If two
variables `a` and `b` refer to the same table of type
`[x: currently number]`, and `a.x="abc"` is performed, the type system
can remember that `a.x`'s type changed, but won't realize that `b.x`'s
type changed too.

To solve this, whenever a second reference is made to a term, it will
be "delinearized", i.e. all of its `currently` fields will be made
private in the copy, by typing them as `field`. Here's an illustration:

    local a #currently [x: currently number; y:var number] = { x=1; y=2 }
    local b #currently [x: field; y:var number] = a
    a.x #currently string = "foo" -- OK: b ignores its private field x, it won't mind if it becomes a string.
    b.x #currently boolean = false -- Illegal: b.x is a private field, we can't write in it.

To maintain linearity of `currently` variables, we force
delinearization:

* when assigning into a variable, as seen above;

* when passing an argument to a function: it creates a second
  reference to a term, just as for assignment.

* when using an upvalue. A function's body can be executed at any
  time, we don't know what might have happened to an upvalue between
  the function's definition and its application. All `currently`
  variables which aren't local to the function must therefore be
  ignored. Upvalues must therefore be typed as `var` or `const` (the
  inference system will attempt to guess such a type whenever
  appropriate).

The handling of linear types is the trickiest part of the type system,
and a rigorous presentation of it goes beyond this summary. Please
refer to the paper for a detailed presentation.


Syntax
======

Type annotations are introduced with the "#" character, after the slot
/ term they alter. It can appear:

* after a function parameter:
  `function string.rep(str #string, n #number) ... end`;

* in the left-hand-side of an assignment. It then precedes a field
  annotation: `local n #var number, x #currently string = 1, "foo"`.
  It can also modify a table field, `t.x #currently number = 3`, but
  for this to be legal, both `t` and `t.x` must be `currently` slots
  (since changing the type of `t.x` implies to also change the type of
  `t`).

* in front of a sequence of statements, introduced by `return`. For
  instance, if a block returns a pair of numbers, it can be written
  `#return number, number; local x #const number = foo(); return x,
  x+1`. In most cases, such annotations aren't necessary, as statement
  types are reliably guessed by the type inference system.

Some support for type aliases is planned, to avoid repeating long
structural type. They will probably look like
`#point = [x:const number; y:const number]`; but they present no
theoretical interest, and haven't been implemented yet. Notice that
the question of their scope will have to be addressed.

Finally, typing statements will probably prove necessary to integrate
untyped modules in typed ones, and check their proper use. A sentence
like `#assume string.rep: const (string,number)->(string)` means
"trust me, this slot has exactly this type; now you can ensure that I
use it soundly".

Some examples
=============

**Warning:** *The examples below show the results of a type-guessing
heuristic which isn't mature; they may go out-of-cate without notice.*

Tidal Lock offers:

1. a sound, annotation-based type system;
2. support for (annotation-based) gradual typing, through the `*` type;
3. type inference, to try and guess annotations where they're missing.

Of course, we'd like to have most if not all types guessed rather that
explicitly annotated, but in the general case we can't, because the
type system doesn't enjoy the _principal type_ property: for a given
term, there isn't always a single best type, so that any other type
would either be a subtype of that principal type, or would accept
terms causing errors. The pragmatic approach is to try and guess
something that works well 90% of times, and let users put annotations
when the inference heuristic guessed wrong.

Let's start with a very simple example:

    $ tilo() { lua -l metalua -l tilo -e "tilo[[$1]]" ; }
    $ tilo "return 123"
    Result: return number

Tidal Lock will do a decent job of tracking the types of primitives,
even if composed into tables:

    $ tilo "local x = { }; x.num=123; x.str='abc'; return x"
    Result: return ["num"=var number, "str"=var string|currently nil]

Here it chose to type fields as `var` rather than `currently`: by
default, local vars are typed `currently` unless they're upvalues, and
table fields are typed `var`. This is because in general, table
contents are more structured, and more likely to be passed around, so
having a stable type is more desirable. They could even have been made
`const` by default, but in such an imperative language as Lua, it
seemed too coercive. These choices can be overridden through
annotations, though:

    $ tilo "local x = { };
            x.num #currently number = 123;
            x.str #const string = 'abc'
            return x"
    Result: return ["num"=currently number, "str"=const string|currently nil]

Constant fields are enforced:

    $ tilo "local x = { }; x.y = 123; x.y=234; return x"
    Result: return ["y"=var number|currently nil]
    $ tilo "local x = { }; x.y #const number = 123; x.y=234; return x
    "tilo.type": Don't override a constant field

Things become more complex with unannotated function
parameters. Operators help to detect primitive types:

    $ tilo "return function(x) return x+1 end"
    Result: return (number)->(number)

For table parameters, we try to guess `const` types rather than `var`
ones, because the typing rule `var E <: const E` allows to pass a
variable where a constant was expected

    $ tilo "return function(x) x.a=x.b+1 end"
    Result: return (["b"=const number, "a"=var number])->(nil)

However, such a choice might not be what's expected, e.g if the
parameter is returned as a result:

    $ tilo "return function(x) x.a=x.b+1; return x end"
    Result: return
    (["b"=const number, "a"=var number])->(["b"=const number, "a"=var number])

Here the choice to be more compliant with the function's parameters
made the function's returned type more vague. There's no way to guess
what the user prefers, so such a case deserves an annotation. More
generally, explicitly typing function parameters is a good way to
document the code and to enforce stable invariants, and should be
encouraged.


Future extensions
=================

Globals
-------

Global variables in Lua are stored in a special table, with their name
as a string key. An access to global variable `foo` is equivalent to
`_ENV["foo"]`, with `_ENV` a variable holding the global variables
table (it is even implemented that way in the Lua 5.2 VM). That's how
we'll eventually type global variables.

The global table's content will have to be passed to modules, for them
to check the use of primitive functions. Some interesting questions
remain about the most appropriate field annotations, though:

* global functions should be typed `const`: monkey-patching them is
  generally a poor idea. In the very few cases where it would make
  sense, forcing the type system off with strategically placed `*`
  types seems a very reasonable warning. Conceptually ugly code should
  be visually ugly.

* unset global variables can be typed `field`: this would completely
  prevent from accessing them.

* they could also be typed `const nil`: this is more accurate, but an
  access to a known-as-nil variable is maybe more likely to be an
  error than performed on purpose. It also supposes that we know the
  exhaustive list of all actual global variables, included those which
  might have been created by old-style modules.

* typing them `var nil` has little interest, as a `var nil` could only
  be overwritten with another `nil` (you can't change the type in a
  `var` slot).

* `var *` and `const *` let you use global variables as you want,
  either in read-write or in read-only mode. It's probably nice to
  allow this as an option, but it shouldn't be the default
  configuration.

* `currently nil` can be interesting, but suffers from the same
  limitation as `const nil`: we need to be sure of the exact state of
  the global table.

* `currently *` is even more interesting: initially we don't know
  anything about the non-predeclared global variables, but if they are
  updated within the module, the type system keeps track of those
  type changes.

Of these possibilities, the two most interesting ones are `field` and
`currently *`; they'll probably be both accessible as two options of
the compiler.

Requiring modules
-----------------

Modules which alter the global variables table are pretty much
intractable. Since they're discouraged anyway in Lua 5.2, we choose
not to support globals creation by modules. At least, we won't keep
track of such global vars, and won't guarantee their sound use.

A module is compiled as a function body; a call to `local M = require
'module.name'` will be interpreted by the type system as a call to
this parameter-less function.

Keeping track of `require` will be done by putting a "magic type" in
the global variable `require`, rather than following the variable
itself. This way, idioms such as `local require = require` will be
handled gracefully and automatically.

Metatables
----------

Metatables can get partial support. By monitoring the use of
`setmetatable`, one can keep track of an object's metatable in many
cases. `__index` metafields can be tracked effectively as long as
they're tables rather than arbitrary functions.

Support for overloaded binary operators would be very complex, and
probably not worth it. Moreover, I'll argue that most operator
overloading uses I've seen borders on abuse, and have no place in a
code base which fancies itself as maintainable.

`__newindex` is mostly used with a function, and as such remains
intractable to a static type system.

`__call` can be supported with no special difficulty.


Nullable or optional types
--------------------------

The type system is intended to catch nil-indexing errors: those make
up an important proportion of type errors, and although languages
descending from Algol traditionally don't try to catch them, languages
of the ML family have been soundly doing so since the early 70's,
without requiring much additional bookkeeping from their users.

This means that to be usable, the type system will require either a
"nullable" modifier `?`, as in `?number`, or a union type, as in
`nil|number`. The latter seems more satisfying intellectually, but
they would probably create much more complications than they're worth.

To support nullable types, we need a deconstructor: a language feature
which guarantees that a given instance of a nullable type isn't
null. This role is taken by structural pattern matching in ML-family
languages. Since we don't want to extend Lua, this will be done by
recognizing the pattern `if E==nil then ... end` and its variants: the
versions where the test is reversed, or in an `elseif` clause, and the
shorter `if E then ... end` (when `E` can't be `false`). Pathological
use cases will have to remain dynamically typed.


Hashtables
----------

The type system treats hashtables as records, with keys taken from the
set of Lua primitives (this set has nice properties, most notably
being enumerable and enjoying a straightforward definition of
equality). An additional "generic hashtable" type can be added without
great difficulty: from a type system point of view, it behaves mostly
like a function of one parameter with one result. It will probably be
written `[E=>E]`, or possibly `[F=>E]`: it should be possible to
annotate the key type with `var` or `const`, to allow read-only
covariant hashtables.

A notable type is `[number=>E]`, i.e. the lists of `E`. It's probably
worthy of some syntax sugar.

Hashtable types can be mixed with the dynamic type `*`; one can thus
get types such as `[number=>*]`, a list of dynamic values. `[*=>*]` is
an hasshtable about which we don't know anything, besides the fact
that it's a hashtable.

However, it's difficult to create hybrid types between hashtable and
record-table types: we would have to make sure that hashtable keys
can't overwrite record-table keys. Some special cases, such as
list-table + string-keyed record-tables are theoretically possible; it
remains to be seen whether they're practical, but such structures are
heavily used, for instance, by Metalua.


Homebrew class systems
----------------------

Just like every other junior lisper recreates his own parenthese-free
dialect of the language (the first one actually predates Lisp itself
[2]), every other junior Lua hacker rolls out his own object
framework. No de-facto standard ever emerged, and things are likely to
remain that way.

Simple objects and classes, which rely on straight tables in `__index`
index metafields, should be understood by the current system. Fancier
systems with ad-hoc inheritance will not. It should be possible to
salvage such objects with more annotations (mostly in constructors).

However, I wonder how much of an issue this actually is: I haven't
seen a lot of those fancy object hierarchies in actually reused code,
and I suspect that the reason why there's still no standard
inheritance mechanism in Lua is that very few people really need them:
their main interest is that they're fun to write.

[2] http://en.wikipedia.org/wiki/M-expression

Sigma binders
-------------

You must be an academic if you're wondering about this :)

The typing of object-oriented languages is often studied through the
sigma-calculus [3], a formal calculus which constitutes the OO
counterpart to the lambda-calculus. It introduces a notion of
recursive types: an object type can reference itself in its own
definition. For instance consider a point with a method `move(dx)`,
which returns a copy of the point shifted `dx` units to the right; it
will have type `S(T)[move:(number)->(T)]`, where `T` is bound to the
object's type. This feature is important to handle inheritance when
objects casually return modified versions of themselves. This doesn't
fit Lua's typical usage: there's no well established inheritance
mechanism, and tables typically alter themselves rather than returning
functional copies.

In addition to being of dubious usefulness in realistic Lua programs,
sigma binders dramatically complicate type systems, and the ability to
perform inference on them. For those reasons, they're most likely to
stay out of Tidal Lock forever. If type variables were to be
introduced in the system, ML-style polymorphism would surely be much
more beneficial. But even this doesn't cohabit too easily with
subtyping, and might not be worth the pain. Anecdotal evidences of
this include Go's lack of generics, and the misunderstanding of Java's
generics by most seasoned Java developers.

[3] http://lucacardelli.name/indexPapers.html#Objects
