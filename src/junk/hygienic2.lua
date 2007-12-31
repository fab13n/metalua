--------------------------------------------------------------------------------
--
-- (c) Fabien Fleutot 2007, published under the MIT license.
--
--
-- API:
-- ----
-- * freevars.block(ast)
-- * freevars.expr(ast)
-- * freevars.stat(ast)
--
--------------------------------------------------------------------------------

require 'std'
require 'walk'
require 'freevars'

-{ extension 'match' }

--------------------------------------------------------------------------------
-- Return the string->boolean hash table of the names of all free variables
-- in 'term'. 'kind' is the name of an entry in module 'walk', presumably
-- one of 'expr', 'stat' or 'block'.
--------------------------------------------------------------------------------
local function alpha (kind, term)
   local cfg = { expr  = { }, stat  = { }, block = { } }

   -----------------------------------------------------------------------------
   -- Monkey-patch the scope add method, so that it associates a unique name
   -- to bound vars.
   -----------------------------------------------------------------------------
   local scope = scope:new()
   function scope:add(vars)
      for v in values(vars) do self.current[v] = mlp.gensym(v) end
   end
      
   -----------------------------------------------------------------------------
   -- Check identifiers; add functions parameters to scope
   -----------------------------------------------------------------------------
   function cfg.expr.down(x)
      match x with
      | `Splice{...} -> return 'break' -- don't touch user parts
      | `Id{ name } ->
         local alpha = scope.current[name]
         if alpha then x[1] = alpha end
      | `Function{ params, _ } -> scope:push(); scope:add (params)
      | _ -> -- pass
      end
   end

   -----------------------------------------------------------------------------
   -- Close the function scope opened by 'down()'
   -----------------------------------------------------------------------------
   function cfg.expr.up(x)      
      match x with `Function{...} -> scope:pop() | _ -> end
   end

   -----------------------------------------------------------------------------
   -- Create a new scope and register loop variable[s] in it
   -----------------------------------------------------------------------------
   function cfg.stat.down(x)
      match x with
      | `Splice{...}           -> return 'break'
      | `Forin{ vars, ... }    -> scope:push(); scope:add(vars)
      | `Fornum{ var, ... }    -> scope:push(); scope:add{var}
      | `Localrec{ vars, ... } -> scope:add(vars)
      | `Repeat{ block, cond } -> -- 'cond' is in the scope of 'block'
         scope:push()
         for s in values (block) do walk.stat(cfg)(s) end -- no new scope
         walk.expr(cfg)(cond)
         scope:pop()
         return 'break' -- No automatic walking of subparts
      | _ -> -- pass
      end
   end

   -----------------------------------------------------------------------------
   -- Close the scopes opened by 'up()'
   -----------------------------------------------------------------------------
   function cfg.stat.up(x)
      match x with
      | `Forin{ ... } | `Fornum{ ... } -> scope:pop() -- `Repeat has no up().
      | `Local{ vars, ... }            -> scope:add(vars)
      | _ -> -- pass
      end
   end

   -----------------------------------------------------------------------------
   -- Create a separate scope for each block
   -----------------------------------------------------------------------------
   function cfg.block.down() scope:push() end
   function cfg.block.up()   scope:pop()  end

   walk[kind](cfg)(term)
   return freevars
end

--------------------------------------------------------------------------------
-- A wee bit of metatable hackery. Just couldn't resist, sorry.
--------------------------------------------------------------------------------
freevars = setmetatable ({ scope=scope }, { __index = |_, k| |t| fv(k, t) })
