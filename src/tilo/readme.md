Tidal Lock: Gradual Static Typing for Lua
=========================================

Tidal Lock is a static analyzer for Lua, which allows to mix
statically and dynamically typed Lua code. It relies on type
annotations, i.e. on a simple extension of Lua's grammar, although a
comments-based annotation system could easily be designed for it, thus
retaining full Lua compatibility.

The ability to mix static types with dynamic parts is based on gradual
typing, the result of Jeremy Siek's research. This means that a fairly
strict type system can be used, even if it can't support some
important idioms, or sometimes requires prohibitive amounts of
annotations: when it isn't worth it, just turn it off with a dynamic
type. 

For an in-depth study of gradual typing, go to
http://ecee.colorado.edu/~siek/gradualtyping.html.

The type system relies on partial type inference: when a program
isn't fully annotated, it tries to guess the missing annotations, and
will cause an error if it find an inconsistency in the process. For
instance, when calling a typed function with untyped arguments, it
will infer types for the latter. Otherwise, no type errors could be
found in untyped program fragments, thus dramatically reducing the
system's interest.


Current state
=============

Tidal Lock is a work in progress, in a early stage. At its core is a
formal essay describing the underlying type system, which isn't in a
publishable state yet. I can send drafts upon request, though.

The compiler is, at this stage, still an exploratory tool to test the
paper's theories. It's written in Metalua, an self-extensible dialect
of Lua which supports interesting code manipulation features. As a
result, it currently only targets Lua 5.1.

It only recognizes a subset of Lua, exhibiting the parts of the
language most interesting and challenging to type. Unsupported parts
of the language therefore fall in two categories:

* reasonably easy to support, but of limited theoretical interest;

* so hard to type that they probably aren't worth it. The magic of
  gradual typing is that they will remain usable by people, only
  dynamically typed.

The subset of the language currently supported are:

* local variables declaration and use;
* assignments (in multiple variables and/or table slots);
* functions (multiple parameters and returned values, but no "..."
  ellipsis);
* return statements;
* table literals;
* function calls;
* table indexing;
* primitives (strings, numbers, booleans, nil).

Binary operators, if/then/else and loops will soon be added, to allow useful
programs.


Available types
===============

The type system doesn't support generic types (use dynamic types for
that). It's intended to catch nil-indexings, although this part isn't
operational yet.


Dynamic type
------------

Written `*`, as a wildcard, it's the dynamic type. An object of this
type is accepted everywhere (as the "bottom" type found in many formal
type systems with subtyping), and every object is allowed to have type
`*` (as the "top" type in formal systems).

The key insight of gradual typing is that although `*` shares top's
and bottom's defining characteristics, it's distinct from both, and
orthogonal with respect to the subtyping relationship. This allows to
integrate it in a sound type system, without collapsing the whole
subtyping by forcing `top=bottom`. Please refer to Jeremy Siek,
especially "Gradual Typing for Objects"[1] for formal developments.

[1] http://ecee.colorado.edu/~siek/pubs/pubs/2006/siek06_sem_cpp.pdf


Primitive expression types
--------------------------

`nil, boolean, number, string`.


Table types
-----------

`[e1: F1, ..., en: En | Fd]` is the type of a table which associates
a value of type `F1` to the primitive expression `e1`, ..., a value of
type `Fn` to the primitive expression `en`, and type `Fd` to all other
keys, not explicitly listed before. Types `Fn` are "field types",
i.e. they're annotated with accessibility modifiers such as `var` or
`const`.

For tables whose keys are either not primitives, or not known
statically, a generic hashtable parametrized with key type and value
type `[E=>F]` can easily be added to the system. By making either key
type or value type dynamic, one can further relax the constraints on a
table's content. Such facilities haven't been put in the type system
yet, though.


Local variable types
--------------------

As table values, variable are annotated with "field types", i.e. with
accessibility modifiers. A noteworthy feature is the `currently` field
modifier, which allows to change a variable's type within a
program. It is necessary to type many idiomatic Lua programs, as we
shall see later.


Expression sequence types
-------------------------

Expression sequences have a central importance in Lua: functions
return them, take them as parameters, and they are central to the way
variable assignment works in Lua. Sequences are explicitly surrounded
with parentheses, as in `(number, string)`.

An expression sequence and its expression types sequence don't
necessarily have the same length, e.g. `x, y()` might have a type of
length 3 if function `y` returns 2 values.


Function types
--------------

Functions types are written as an arrow between the parameter types
sequence and the result types sequence, e.g. `(number, string) ->
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
  that the type system can keep track of them.
* `field`: the slot's content is unknown, private. The type system
  will neither let read nor change this content.

The `currently` modifier is unusual. Its main purpose is to soundly
type idiomatic fragments such as `M={ }; M.f1=function() ... end`,
where a table's type changes gradually as methods and/or fields are
added in it.

We'll admit as syntax sugar that `[pn:En]` is a shortcut for
`[pn:En|field]`.

Some remarks about the type system
==================================

Static duck typing
------------------

Subtyping and type equality are structural: two tables are equal if
and only if all their fields are equal. This is in contrast with
languages inspired from C, where two `struct`s with the same fields
but different `typedef` names aren't comparable.


Subtyping
---------

An important property of a type system is subtyping: which type can be
substituted with which one. As mentioned above, Tidal Lock uses
structural type comparisons. We define a partial order over field
types and expression types, `E1 <: E2`, which means that `E1` is a
subtype of `E2`. The consequence is that everywhere a term of type
`E2` is accepted, a term of type `E1` must also be accepted.

Subtyping is defined as follows:

* `var E <: const E`.

* `const E1 <: const E2` iff `E1 <: E2`.

* `const E <: field`.

* `var E <: field`. This could be inferred in two steps from
  `var E <: const E <: field`.

* `currently E <: field`.

* `[p1:F1...pn:Fn|Fd] <: [p1:F1'...pn:Fn'|Fd']` iff `Fx <: Fx'` for
  all `x`, and `Fd <: Fd'`. Adjust for fields reordering and expansion
  of the default type. For instance,
  `[x:var number; y:var number | const nil] <:
   [y:var number; x:var number; z:const nil | const nil]`).

* `(Ei1...Ein) -> (Eo1...Eom) <:(Ei1'...Ein') -> (Eo1'...Eom')` iff
  `Eix' <: Eix` and `Eox <: Eox'` for all `x`. Adjust for `nil` types
  on the right, which can be omitted. For instance, `(point, nil) ->
  ()  <: (colored_point) -> (nil)`.

Notice that we don't have `var E1 <: var E2`, even if `E1 <: E2`. An
object of type `[p: var colored_point]` cannot be used where a
`[p: var point]` is expected, even if `colored_point <: point`. I can
update the latter's `p` field with a non-colored point, whereas I
can't do that with the former. Because `var` field can be written to

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
of `currently` slot cannot be reached from more than one path. If two
variables `a` and `b` refer to the same table of type
`[x: currently number]`, and `a.x="abc"` is performed, the type system
can remember that `a`'s type changed, but won't realize that `b`'s
type changed too.

To solve this, whenever a second reference is made to a term, it will
be "delinearized", i.e. all of its `currently` fields will be made
private in the copy, by typing them as `field`. Here's an illustration:

    local a #currently[x: currently number; y:var number] = { x=1; y=2 }
    local b #currently[x: field; y:var number] = a
    a.x #currently string = "foo" -- OK: b must ignore private field b.
    b.x = false -- Illegal: x is private in b, can't be written.

To maintain linearity of `currently` variables, we force
delinearization:

* when assigning into a variable, as seen above;

* when passing an argument to a function: it creates a second
  reference to a term, just as for assignment.

* when using an upvalue. A function's body can be executed at any
  time, we don't know what might have happened to an upvalue between
  the function's definition and its application. All `currently`
  variables which aren't local to the function must therefore be
  ignored. Upvalues must be typed as `var` or `const` (the inference
  system will attempt to guess such a type whenever appropriate).

The handling of linear types is the trickiest part of the type system,
and a rigorous presentation of it goes far beyond this summary. A
paper will be published later about how this works, formally and
pragmatically.


Syntax
======

Type annotations are introduced with the "#" character, after the slot
they alter. It can appear:

* after a function parameter: `function string.rep(str #string, n
  #number) ... end`;

* in the left-hand-side of an assignment. It then precedes a field
  annotation: `local n #var number, x #currently string = 1, "foo"`.
  It can also modify a table field, `t.x #currently number = 3`, but
  for this to be legal, both `t` and `t.x` must be `currently` slots.

* in front of a sequence of statements, introduced by "return". For
  instance, if a block returns a pair of numbers, it can be written
  `#return number, number; local x #const number = foo(); return x,
  x+1`. In most cases, such annotations aren't necessary, as statement
  types are reliably guessed by the type inference system.

Some support for type aliases


Future extensions
=================

Globals
-------

Global variables in Lua are stored in a special table, with their name
as a key. An access to global variable `foo` is equivalent to
`_ENV["foo"]`, with `_ENV` a variable holding the global variables
table. It is even implemented that way in the Lua 5.2 VM. That's how
we'll eventually type global variables.

The global table's content will have to be passed to modules, for them
to check the use of primitive functions. Some interesting questions
remain about the field annotations, though:

* global functions should be typed `const`: monkey-patching them is
  generally a poor idea; in the very few cases where it would make
  sense, forcing the type system off with strategically placed `*`
  types seems a very reasonable warning. Conceptually ugly code should
  be visually ugly.

* unset global variables can be typed `field`: this would completely
  prevent from accessing them.

* they could also be typed `const nil`: this is more accurate, but
  an access to a known-as-nil variable is maybe more likely to be an
  error than made on purpose. It supposes that we know the exhaustive
  list of all actual global variables, included those which might have
  been created by old-style modules.

* typing them `var nil` has little interest, as they could only be
  overwritten with another `nil` (you can't change the type in a `var`
  slot).

* `var *` and `const *` lets you use global variables as you want,
  either in read-write or in read-only mode. It's probably nice to
  allow this as an option, but it should certainly not be the default
  configuration.

* `currently nil` can be interesting, but suffers from the same
  limitation as `const nil`: we need to be sure of the exact state of
  the global table.

* `currently *` is even more interesting: initially we don't know
  anything about the non-predeclared global variables, but if they are
  updated within the module, the type system keeps track of those
  type changes.

Of these possibilities, the two most interesting ones are `field` and
`currently *`; they'll probably be both accessible in a parametrizable
way.

Module requiring
----------------

Modules which alter the global variables table are pretty much
intractable. Since they're discouraged anyway in Lua 5.2, we choose
not to support globals creation by modules. At least, we won't keep
track of such global vars, and won't guarantee their sound use.

A module is compiled as a function body; a call to `local M = require
'module.name'` will be interpreted by the type system as a call to
this parameter-less function.

Keeping track of `require` will be done by putting a "magic type" in
global `require`, rather than following dereferrencing of the variable
itself. This way, idioms such as `local require = require` will be
handled gracefully and automatically.

Metatables
----------

Metatables can get partial support. By monitoring the use of
`setmetatable`, one can keep track of an object's metatable in many
cases. `__index` metafields can be tracked effectively as long as
they're tables rather than arbitrary functions.

Support for overloaded binary operators would be very complex, and
probably not worth it. Moreover, I would argue that most operator
overloading use I've seen borders on abuse, and has no place in a
code base which fancies itself as maintainable.

`__newindex` is mostly used with a function, and as such remains
intractable to a static type system.

`__call` can be supported with no special difficulty.


Nullable or optional types
--------------------------

The type system s intended to catch nil-indexing errors: those are an
important proportion of type errors, and although languages descending
from Algol traditionally don't try to catch them, languages of the ML
family do it soundly, and without requiring much additional bookkeeping
from their users.

This means that to be usable, the type system will require either a
"nullable" modifier "?", as in "`?number`", or a union type, as in
"`nil|number`". The latter seems more satisfying intellectually, but
it remains to be seen whether it's worth it in terms of type complexity.

To support nullable types, one needs a deconstructor, a language
feature which guarantees that a given instance of a nullable type
isn't null. Since we don't want to extend Lua, this will be done by
recognizing the pattern `if E==nil then ... end` and its variants: the
versions in `else` or `elseif` clauses and the shorter `if E then`
when E can't be `false`. Pathological use cases will have to remain
dynamically typed.


Hashtables
----------

The type system treats hashtables as records, with keys taken from the
set of Lua primitives, which is enumerable and enjoys a
straightforward definition of equality. An additional "generic
hashtable" type can be added without great difficulty: from a type
system point of view, it behaves similarly to a function with one
parameter and one result. It will probably be written `[E=>E]` (no
need to put a slot annotation on the values type: the type system
won't be able to keep track of constants, let alone the types of
`currently` slots).

A notable type is `[number=>E]`, i.e. the lists of `E`. It's probably
worthy of some syntax sugar.

Hashtable types can be mixed with the dynamic type `*`; one can thus
get types such as `[number=>*]`, a list of dynamic values. `[*=>*]` is
an hasshtable about which we don't know anything, besides the fact
that it's a hashtable.


Sigma binders
-------------

You must be an academic if you're wondering about this :)

The typing of object-oriented language is often studied through the
"sigma-calculus", a formal calculus which constitutes the OO
counterpart to the lambda-calculus. It introduces a notion of
recursive types: an object type can reference itself in its own
definition. For instance, a point which as a method `move(dx)`, which
returns a copy of the point shifted `dx` units to the right, will have
type `S(T)[move:(number)->(T)]`, where `T` is bound to the object's
type. This is important in presence of inheritance, and when objects
casually return modified versions of themselves. This doesn't fit
Lua's typical usage: there's no well established inheritance
mechanism, and tables typically alter themselves rather than returning
functional copies.

In addition to be of dubious use in realistic Lua programs, sigma
binders dramatically complicate the type system, and the ability to
perform inference on them. For those reasons, they're most likely to
stay out of Tidal Lock forever. If type variables were to be
introduced in the system, ML-style polymorphism would probably be much
more beneficial. But even this doesn't cohabit too easily with
subtyping, and is probably not worth the trouble. Anecdotal evidences
of this include Go's lack of generics, and the misunderstanding of
Java's generics by most seasoned Java developers.

