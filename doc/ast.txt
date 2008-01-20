block: { stat* }

stat:
| `Do{ stat* (`Return{expr*} | `Break)? }
| `Set{ {lhs+} {expr+} }                    -- lhs1, lhs2... = e1, e2...
| `While{ expr block }                      -- while e do b end
| `Repeat{ block expr }                     -- repeat b until e
| `If{ (expr block)+ block? }               -- if e1 then b1 [elseif e2 then b2] ... [else bn] end
| `Fornum{ ident expr expr expr? block }    -- for ident = e, e[, e] do b end
| `Forin{ {ident+} {expr+} block }          -- for i1, i2... in e1, e2... do b end
| `Local{ {ident+} {expr+}? }               -- local i1, i2... = e1, e2...
| `Localrec{ ident expr }                   -- no syntax expect in 'local function'
| `Goto{ <string> }                         -- no syntax
| `Label{ <string> }                        -- no syntax
| `Return{ <expr*> }                        -- allowed anywhere, unlike in plain Lua
| `Break                                    -- allowed anywhere, unlike in plain Lua
| apply

expr:
| `Nil  |  `Dots  |  `True  |  `False
| `Number{ <number> }
| `String{ <string> }
| `Function{ { ident* `Dots? } block } 
| `Table{ ( `Pair{ expr expr } | expr )* }
| `Op{ opid expr expr? }
| `Stat{ block, expr }
| `Paren{ expr }
| apply
| lhs

apply:
| `Call{ expr expr* }
| `Invoke{ expr `String{ <string> } expr* }

lhs: ident | `Index{ expr expr }

ident: `Id{ <string> }

opid: 'add'   | 'sub'   | 'mul'   | 'div' 
    | 'mod'   | 'pow'   | 'concat'| 'eq'
    | 'lt'    | 'le'    | 'and'   | 'or'
    | 'not'   | 'len'


----------------------------------------------------------------------
-- The following lists some tolerances on the syntax, i.e. some
-- sloppy AST idioms that will not be produced as metalua output,
-- but which metalua will accept as input.
-- BEWARE: as of metalua 0.4, this is NOT implemented.
-- Constructive criticism is welcome, though.
----------------------------------------------------------------------

Canonization
============

These operations are automatically performed on AST, allowing users to
type/generate them in a somewhat sloppy form:

- When a list of ids/statements is expected and a lone id/stat is found,
  it's lifted as a single-element list. Applies in:
  `Set, `Fornum, `Forin, `Local, `Localrec

- In `Localrec and `Local, the right-hand-side list can be ommitted.

- When there are too many elements in Forin/Fornum/While/Repeat/Function,
  the extra ones are regrouped as a block.
  `While{ cond, foo, bar } -> `While{ cond, { foo, bar } }

- Numbers, strings, booleans are automatically lifted
  42 -> `Number 42

- operators accept a direct form: 
  `Add{ a, b } -> `Op{ 'add', a, b }

- `Index{ a, b, c } is folded left -> `Index{ `Index{ a, b }, c }

- List are flattened in blocks: { a, { b, c }, d, { } , e } -> 
  { a, b, c, d, e }.

- Parens around statements are tolerated:
  `Paren{ `Call { foo, bar } } -> `Call{ foo, bar }

- `Boolean{ true } and `Boolean{ false } are accepted as aliases for
  `True and `False, for the sake of uniform constant lifting.
