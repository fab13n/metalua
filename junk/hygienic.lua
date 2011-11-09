----------------------------------------------------------------------
-- Metalua:  $Id$
--
-- Summary: Hygienic macro facility for Metalua
--
----------------------------------------------------------------------
--
-- Copyright (c) 2006, Fabien Fleutot <metalua@gmail.com>.
--
-- This software is released under the MIT Licence, see licence.txt
-- for details.
--
--------------------------------------------------------------------------------
--
-- =============
-- W A R N I N G
-- =============
--
-- THIS IS AN OLD NAIVE IMPLEMENTATION. IT'S PARATIAL (NO HYGIENE WRT OUTSIDE)
-- AND WRITTEN FROM SCRATCH WITH PATTERN MATCHING. MUST BE DONE WITH A WALKER.
--
-- Traditional macros carry a well-known pitfall, called variable capture:
-- when pasting a piece of source code A into another code B, if B bonds some
-- variables used by A, then the meaning of A is modified in a way probably
-- not intended by the user.
--
-- Example:
-- A = +{ n = 5 }
-- B = +{ local n=3; -{ A } }
-- 
-- In this example, [n] in [A] will be captured by the local variable declared
-- by [B], and this is probably a bug.
-- 
-- Notice that this also exists in C. Typical example:
--
-- #define swap (type, a, b) do { type tmp=a; a=b; b=tmp } while(0)
-- void f() {
--   int tmp=1, a=2;  
--   swap (int, tmp, a); // won't work, [tmp] is captured in the macro
-- }
--
-- We can fix this by making sure that all local variables and parameters
-- created by [B] have fresh names. [mlp.gensym()] produces guaranteed-to-be-unique
-- variable names; we use it to replace all local var names declarations and 
-- occurences in [B] by such fresh names.
--
-- Such macros which are guaranteed not to capture any variable are called
-- hygienic macros. By extension, an AST guaranteed not to contain capturing
-- variables is called an hygienic AST.
--
-- We implement here some functions which make sure that an AST is hygienic:
-- 
-- - [hygienize_stat (ast)] for statement AST;
-- - [hygienize_stat (ast)] for statement block AST;
-- - [hygienize_expr (ast)] for expression AST;
--
-- This sample deconstructs AST by structural pattern matching, which is
-- supported by Metalua extension "match.lua"
--
--------------------------------------------------------------------------------

-{ extension "match" }

require "std"

local clone_ctx = std.shallow_copy

--------------------------------------------------------------------------------
-- Tag tables: these allow [hygienize] to decide whether an AST is
-- an expression, a statement, or something which isn't changed by
-- alpha renaming.
--------------------------------------------------------------------------------
local stat_tags = {
   Do       = true,   Let      = true,
   While    = true,   Repeat   = true,
   If       = true,   Fornum   = true,
   Forin    = true,   Local    = true,
   Localrec = true,   Return   = true }

local expr_tags = {
   Function = true,   Table    = true,
   Op       = true,   Call     = true,
   Method   = true,   Index    = true }

local neutral_tags = {
   String = true,   Number = true,
   True   = true,   False  = true,
   Dots   = true,   Break  = true,
   Id     = true }

--------------------------------------------------------------------------------
-- Choose the relevant [hygienize_xxx()] function according to the AST's tag
-- and the tables above.
--------------------------------------------------------------------------------
function hygienize (ast)
   if not ast.tag           then hygienize_block (ast)
   elseif neutral_tags[ast.tag] then -- pass
   elseif stat_tags[ast.tag]    then hygienize_stat (ast) 
   elseif expr_tags[ast.tag]    then hygienize_expr (ast) 
   else error "Unrecognized AST" end
   return ast
end

if mlp then
   -- Add hygienic parsers for quotes
   mlp.hexpr  = hygienize `o` mlp.expr
   mlp.hstat  = hygienize `o` mlp.stat
   mlp.hblock = hygienize `o` mlp.block
end

--------------------------------------------------------------------------------
-- Make a statement AST hygienic. The optional [ctx] parameter is a
-- [old_name -> new_name] map, which holds variable name substitutions
-- to perform.
--------------------------------------------------------------------------------
function hygienize_stat (ast, ctx)
   if not ctx then ctx = { } end
   match ast with
   | { ... } if not ast.tag -> hygienize_block (ast, ctx)
   | `Do{ ... } -> hygienize_block (ast, clone_ctx (ctx))

   | `Let{ vars, vals } -> 
      hygienize_expr_list (vars, ctx)
      hygienize_expr_list (vals, ctx)

   | `While{ cond, block } ->
      hygienize_expr (cond, ctx)
      -- use a clone of [ctx], since the block has a separate scope
      hygienize_block (ast, clone_ctx (ctx))

   | `Repeat{ block, cond } ->
      -- use a clone of [ctx], since the block has a separate scope.
      -- Notice that the condition in [repeat ... until] is evaluated
      -- inside the block's scope, i.e. with [inner_ctx] rather than [ctx].
      local inner_ctx = clone_ctx (ctx)
      hygienize_block (ast, inner_ctx)
      hygienize (cond, inner_ctx)

   | `If{ ... } ->
      for i=1, #ast-1, 2 do
         hygienize_expr (ast[i], ctx) -- condtion
         -- each block has its own scope
         hygienize_block (ast[i+1], clone_ctx (ctx)) -- conditional block
      end
      if #ast % 2 == 1 then 
         hygienize_block (ast[#ast], clone_ctx (ctx)) -- else block
      end

   | `Fornum{ var, ... } ->
      hygienize_expr (ast[i], ctx, 2, #ast-1) -- start, finish, step? exprs
      local inner_ctx = clone_ctx (ctx)
      alpha_rename (var, inner_ctx) -- rename local var [var] in [inner_ctx]
      hygienize_block (ast[#ast], inner_ctx)
      
   | `Forin{ vars, vals, block } ->
      hygienize_expr_list (vals, ctx)
      local inner_ctx = clone_ctx (ctx)
      alpha_rename_list (vars, inner_ctx) -- rename local vars [vars] in [inner_ctx]
      hygienize_block (block, inner_ctx)         
      
   | `Local{ vars, vals } ->
      -- locals only enter in scope after their values are computed
      -- --> parse values first, then rename vars
      hygienize_expr_list (vals, ctx)
      alpha_rename_list (vars, ctx)
   
   | `Localrec{ vars, vals } ->
      -- As opposed to [`Local], vars are in scope during their values' 
      -- computation --> rename before parsing values. 
      alpha_rename_list (vars, ctx)
      hygienize_expr_list (vals, ctx)

   | `Call{ ... } | `Method{ ... } -> 
      -- these are actually expr, delegate to [hygienize_expr]
      hygienize_expr (ast, ctx)

   | `Return{ ... } -> hygienize_expr_list (ast, ctx)
   | `Break -> 
   | _ -> error ("Unknown statement "..ast.tag)
   end
end


--------------------------------------------------------------------------------
-- Make an expression AST hygienic. The optional [ctx] parameter is a
-- [old_name -> new_name] map, which holds variable name substitutions
-- to perform.
--------------------------------------------------------------------------------
function hygienize_expr (ast, ctx)
   if not ctx then ctx = { } end
   match ast with
   | `String{ _ } | `Number{ _ } | `True | `False | `Dots -> -- nothing

   | `Function{ params, block } ->
     local inner_ctx = clone_ctx (ctx)
     alpha_rename_list (params, inner_ctx)
     hygienize_block (block, inner_ctx)
      
   | `Table{ ... } ->
      for _, x in ipairs (ast) do
         match x with
         | `Key{ key, val } -> 
            hygienize_expr (key, ctx)
            hygienize_expr (val, ctx)
         | _ -> hygienize (x, ctx)
         end
      end

   | `Id{ x } ->
      -- Check for substitutions to apply:
      local y = ctx[x]; if y then ast[1] = y end

   | `Op{ op, ... } ->
      hygienize_expr_list (ast, ctx, 2, #ast)

   -- Just dispatch to sub-expressions:
   | `Call{ func, ... }
   | `Method{ obj, `String{ name }, ... }
   | `Index{ table, key } ->
      hygienize_expr_list (ast, ctx)
   | _ -> error ("Unknown expression "..ast.tag)
   end
end

--------------------------------------------------------------------------------
-- Make an statements block AST hygienic. The optional [ctx] parameter is a
-- [old_name -> new_name] map, which holds variable name substitutions
-- to perform.
--------------------------------------------------------------------------------
function hygienize_block (ast, ctx)
   if not ctx then ctx = { } end
   table.iter ((|x| hygienize(x, ctx)), ast)
--   for i = 1, #ast do
--      hygienize_stat (ast[i], ctx)
--   end
end

--------------------------------------------------------------------------------
-- Makes a shallow copy of a table. Used to make a copy of [ctx] substitution
-- tables, when entering a new scope.
--------------------------------------------------------------------------------
--[[
function clone_ctx (ctx)
   local r = { }
   for k, v in pairs (ctx) do r[k] = v end
   return r
end
]]

--------------------------------------------------------------------------------
-- Make every expression from index [start] to [finish], in list
-- [ast], hygienic. The optional [ctx] parameter is a [old_name ->
-- new_name] map, which holds variable name substitutions to perform.
-- [start] defaults to 1, [finish] defaults to the list's size.
--------------------------------------------------------------------------------
function hygienize_expr_list (ast, ctx, start, finish)
   for i = start or 1, finish or #ast do 
      hygienize_expr (ast[i], ctx)
   end
end

--------------------------------------------------------------------------------
-- Replace the identifier [var]'s name with a fresh one generated by
-- [mlp.gensym()], and store the new association in [ctx], so that the
-- calling function will be able to substitute identifier occurences with
-- its new name.
--------------------------------------------------------------------------------
function alpha_rename (var, ctx)
   assert (var.tag == "Id")
   ctx[var[1]] = mlp.gensym()[1]
   var[1] = ctx[var[1]]
end

--------------------------------------------------------------------------------
-- runs [alpha_rename] on a list of identifiers.
--------------------------------------------------------------------------------
function alpha_rename_list (vars, ctx)
   for _, v in ipairs(vars) do alpha_rename (v, ctx) end
end
