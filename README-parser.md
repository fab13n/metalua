Metalua Parser
==============

`metalua-parser` is a subset of the Metalua compiler, which turns
valid Lua source files and strings into abstract syntax trees
(AST). This README includes a description of this AST format. People
interested by Lua code analysis and generation are encouraged to
produce and/or consume this format to represent ASTs.

It has been designed for Lua 5.1. It hasn't been tested against
Lua 5.2, but should be easily ported.

## Usage

Module `metalua.compiler` has a `new()` function, which returns a
compiler instance. This instance has a set of methods of the form
`:xxx_to_yyy(input)`, where `xxx` and `yyy` must be one of the
following:

* `srcfile` the name of a Lua source file;
* `src` a string containing the Lua sources of a list of statements;
* `lexstream` a lexical tokens stream;
* `ast` an abstract syntax tree;
* `bytecode` a chunk of Lua bytecode that can be loaded in a Lua 5.1
  VM (not available if you only installed the parser);
* `function` an executable Lua function.

Compiling into bytecode or executable functions requires the whole
Metalua compiler, not only the parser. The most frequently used
functions are `:src_to_ast(source_string)` and
`:srcfile_to_ast("path/to/source/file.lua")`.

    mlc = require 'metalua.compiler'.new()
    ast = mlc :src_to_ast[[ return 123 ]]

A compiler instance can be reused as much as you want; it's only
interesting to work with more than one compiler instance when you
start extending their grammars.

## Abstract Syntax Trees definition

### Notation

Trees are written below with some Metalua syntax sugar, which
increases their readability. the backquote symbol introduces a `tag`,
i.e. a string stored in the `"tag"` field of a table:

* `` `Foo{ 1, 2, 3 }`` is a shortcut for `{tag="Foo", 1, 2, 3}`;
* `` `Foo`` is a shortcut for `{tag="Foo"}`;
* `` `Foo 123`` is a shortcut for `` `Foo{ 123 }``, and therefore
  `{tag="Foo", 123 }`; the expression after the tag must be a literal
  number or string.

When using a Metalua interpreter or compiler, the backtick syntax is
supported and can be used directly. Metalua's pretty-printing helpers
also try to use backtick syntax whenever applicable.

### Tree elements

Tree elements are mainly categorized into statements `stat`,
expressions `expr` and lists of statements `block`. Auxiliary
definitions include function applications/method invocation `apply`,
are both valid statements and expressions, expressions admissible on
the left-hand-side of an assignment statement `lhs`.

    block: { stat* }

    stat:
      `Do{ stat* }
    | `Set{ {lhs+} {expr+} }                    -- lhs1, lhs2... = e1, e2...
    | `While{ expr block }                      -- while e do b end
    | `Repeat{ block expr }                     -- repeat b until e
    | `If{ (expr block)+ block? }               -- if e1 then b1 [elseif e2 then b2] ... [else bn] end
    | `Fornum{ ident expr expr expr? block }    -- for ident = e, e[, e] do b end
    | `Forin{ {ident+} {expr+} block }          -- for i1, i2... in e1, e2... do b end
    | `Local{ {ident+} {expr+}? }               -- local i1, i2... = e1, e2...
    | `Localrec{ ident expr }                   -- only used for 'local function'
    | `Goto{ <string> }                         -- goto str
    | `Label{ <string> }                        -- ::str::
    | `Return{ <expr*> }                        -- return e1, e2...
    | `Break                                    -- break
    | apply

    expr:
      `Nil  |  `Dots  |  `True  |  `False
    | `Number{ <number> }
    | `String{ <string> }
    | `Function{ { `Id{ <string> }* `Dots? } block }
    | `Table{ ( `Pair{ expr expr } | expr )* }
    | `Op{ opid expr expr? }
    | `Paren{ expr }       -- significant to cut multiple values returns
    | apply
    | lhs

    apply:
      `Call{ expr expr* }
    | `Invoke{ expr `String{ <string> } expr* }

    lhs: `Id{ <string> } | `Index{ expr expr }

    opid: 'add'   | 'sub'   | 'mul'   | 'div'
        | 'mod'   | 'pow'   | 'concat'| 'eq'
        | 'lt'    | 'le'    | 'and'   | 'or'
        | 'not'   | 'len'

### Meta-data (lineinfo)


ASTs also embed some metadata, allowing to map them to their source
representation. Those informations are stored in a `"lineinfo"` field
in each tree node, which points to the range of characters in the
source string which represents it, and to the content of any comment
that would appear immediately before or after that node.

Lineinfo objects have two fields, `"first"` and `"last"`, describing
respectively the beginning and the end of the subtree in the
sources. For instance, the sub-node ``Number{123}` produced by parsing
`[[return 123]]` will have `lineinfo.first` describing offset 8, and
`lineinfo.last` describing offset 10:


    > mlc = require 'metalua.compiler'.new()
    > ast = mlc :src_to_ast "return 123 -- comment"
    > print(ast[1][1].lineinfo)
    <?|L1|C8-10|K8-10|C>
    >

A lineinfo keeps track of character offsets relative to the beginning
of the source string/file ("K8-10" above), line numbers (L1 above; a
lineinfo spanning on several lines would read something like "L1-10"),
columns i.e. offset within the line ("C8-10" above), and a filename if
available (the "?" mark above indicating that we have no file name, as
the AST comes from a string). The final "|C>" indicates that there's a
comment immediately after the node; an initial "<C|" would have meant
that there was a comment immediately before the node.

Positions represent either the end of a token and the beginning of an
inter-token space (`"last"` fields) or the beginning of a token, and
the end of an inter-token space (`"first"` fields). Inter-token spaces
might be empty. They can also contain comments, which might be useful
to link with surrounding tokens and AST subtrees.

Positions are chained with their "dual" one: a position at the
beginning of and inter-token space keeps a refernce to the position at
the end of that inter-token space in its `"facing"` field, and
conversly, end-of-inter-token positions keep track of the inter-token
space beginning, also in `"facing"`. An inter-token space can be
empty, e.g. in `"2+2"`, in which case `lineinfo==lineinfo.facing`.

Comments are also kept in the `"comments"` field. If present, this
field contains a list of comments, with a `"lineinfo"` field
describing the span between the first and last comment. Each comment
is represented by a list of one string, with a `"lineinfo"` describing
the span of this comment only. Consecutive lines of `--` comments are
considered as one comment: `"-- foo\n-- bar\n"` parses as one comment
whose text is `"foo\nbar"`, whereas `"-- foo\n\n-- bar\n"` parses as
two comments `"foo"` and `"bar"`.

So for instance, if `f` is the AST of a function and I want to
retrieve the comment before the function, I'd do:

    f_comment = f.lineinfo.first.comments[1][1]

The informations in lineinfo positions, i.e. in each `"first"` and
`"last"` field, are held in the following fields:

* `"source"` the filename (optional);
* `"offset"` the 1-based offset relative to the beginning of the string/file;
* `"line"` the 1-based line number;
* `"column"` the 1-based offset within the line;
* `"facing"` the position at the opposite end of the inter-token space.
* `"comments"` the comments in the associated inter-token space (optional).
* `"id"` an arbitrary number, which uniquely identifies an inter-token
  space within a given tokens stream.

