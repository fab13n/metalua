require "std"

-{ extension "match" }

--------------------------------------------------------------------------------
-- Build the call to [newclass]
--------------------------------------------------------------------------------
local function class_builder(x)
   local ancestors, decl = x[1] or `Table{ }, x[2]
   local methods, fields = `Table{ }, `Table{ }
   ancestors.tag = "Table"
   for line in values(decl) do
      match line with
      | `Field{ lhs, rhs } -> for i = 1, #lhs do 
         table.insert (fields, `Key{ mlp.id2string(lhs[i]), rhs[i] or `Nil }) end
      | `Method{ name, m } ->
         table.insert (m[1], 1, `Id "self") -- add self as 1st param
         table.insert (methods, `Key{ name, m })
      end
   end
   return `Call{ `Id "newclass", ancestors, fields, methods }
end

--------------------------------------------------------------------------------
-- Parsers
--------------------------------------------------------------------------------
local ancestry = gg.onkeyword{ name="class ancestors",
   "<:", gg.list{ mlp.expr, separators="," } }

local method_parser = gg.sequence{ name="in-class method definition",
   "function", mlp.id, mlp.func_val, 
   builder = |x| `Method{ mlp.id2string(x[1]), x[2] } }
   
local field_parser = gg.sequence{ name="in-class instance field declaration",
   "local", gg.list{ mlp.id, separators="," },
   gg.onkeyword{ "=",
      gg.list{ mlp.expr, separators=",", 
         terminators={ "local", "function", "end" } } },
   builder = |x| `Field{ x[1], x[2] or { } } }

local class_val = gg.sequence { name = "class body",
   ancestry, 
   gg.list {gg.multisequence {method_parser, field_parser}, terminators="end"},
   "end",
   builder = class_builder }

--------------------------------------------------------------------------------
-- Pluging the parsers in the syntax
--------------------------------------------------------------------------------
mlp.lexer:add{ "class", "<:" }

mlp.stat:add{ name = "class declaration",
   "class", mlp.expr, class_val, builder = |x| `Let{ {x[1]}, {x[2]} } }

mlp.expr:add{ name = "anonymous class",
   "class", class_val, builder = |x| x[1] }