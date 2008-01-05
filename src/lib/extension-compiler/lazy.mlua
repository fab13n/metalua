-- Lazy evaluation extension for Lua. 
-- The distinctive mark of lazy constructions is the "%" sign. These
-- constructions are:
--
-- * lazy values: an expression preceded by "%". It creates a thunk,
--   i.e. an unevaluated lazy expression.
--
-- * thunk forcing: %! thunk will force the evaluation of the thunk,
--   and return that value. the evaluation's result is cached, so
--   that it won't be computed twice if the thunk is forceed twice.
--   It is legal to force a non-thunk: it simply returns the value
--   directly.
--
-- * lazy table: %{ ... } is a special case: all values in the table
--   are created as thunks, and a proxy is returned, which forces them
--   on demand, so that users aren't even aware that the table is lazy.
--
-- * lazy function: it supposes that all parameters are potentially
--   lazy, and therefore add %! thunk=forcing operators around all
--   of their usages in the function's body. Such a function is created
--   by replacing the parameters' opening parenthese with a "%(".
--
-- * lazy call: all parameters are automatically put into thunks.
--   The caleld function must therefore be lazy, or it won't know how
--   to force the thunks. It only has an interest if some of the args
--   are expansive-to-compute expressions.

----------------------------------------------------------------------
-- Take an AST, return the AST of the thunk which forces to that AST.
----------------------------------------------------------------------
local mk_thunk = |x| +{lazy.thunk(||-{x})}

----------------------------------------------------------------------
-- Build a table where all values are put in thunks, and return a
-- proxy which forces them transparently on demand.
----------------------------------------------------------------------
local function lazy_table_builder(x)
   local c = x[1]
   local d = `Table
   for i = 1, #c do
      if   c[i].tag=="Key"
      then d[i] = `Key{ c[i][1], mk_thunk (c[i][2]) }
      else d[i] = mk_thunk (c[i]) end
   end
   return +{ lazy.table(-{d})}
end

-- Mon probleme: les parametres doivent pouvoir etre remplaces par des
-- thunks -> il faut qu'ils soient forces a chaque usage en interne.
-- Sauf s'ils sont utilises dans un appel paresseux.

-- Et dans les index?
--[[--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|
local function lazy_func_val_builder (func)
   func.tag = "Function"
   local params, body = unpack (func)
   local function lazify (id)
      
      id <- +{ lazy. (|| -{} )

   for v in values (params) do
      walk.block (walk.alpha_id (lazify, v)) (body)
   end
end
--]]--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|

----------------------------------------------------------------------
-- Keywords declaration, simple operators and lazy tables:
----------------------------------------------------------------------
mlp.lexer:add{ "%", "%(", "%{", "%!" }
mlp.expr.prefix:add{  "%",  prec=30, builder= |_,x| mk_thunk(x) }
mlp.expr.prefix:add{  "%!", prec=30, builder= |_,x| +{lazy.force(-{x})} }
mlp.expr.primary:add{ "%{", mlp.table_content, "}", builder=lazy_table_builder }

--[[--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|

----------------------------------------------------------------------
-- Add lazy call rules to method invocations. This involves getting
-- the method argument parser from [mlp], which is a multisequence,
-- and adding new sequences to it.
----------------------------------------------------------------------
local method_args_parser = mlp.expr.suffix:get(":")[3]

method_args_parser:add{
   "%(", gg.list{ mlp.expr, separators=",", terminators=")" }, ")",
   builder = |x| table.imap (mk_thunk, x[1]) }

method_args_parser:add{
   "%{", mlp.table_content, "}", builder=|x| { lazy_table_builder(x) } }

----------------------------------------------------------------------
-- Lazy function call
----------------------------------------------------------------------
mlp.expr.suffix:add{
   "%(", gg.list{ mlp.expr, separators=",", terminators=")" }, ")",
   builder = |f, suffix| `Call{ f, unpack(table.imap(mk_thunk, suffix[1]))}}


----------------------------------------------------------------------
-- Lazy function definition
----------------------------------------------------------------------
local func_params_content = mlp.func_val[2]
func_val = gg.multisequence {
   { "(", func_params_content, ")", mlp.block, "end", builder = "Function" },
   { "%(", func_params_content, ")", mlp.block, "end", 
      builder = lazy_func_val_builder } }

--]]--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|