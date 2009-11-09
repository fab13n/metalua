local M = { }
gg_syntax = M

print "hi"

function tonolistr (x, ...)
   local function dli (x)
      if type(x)=='table' then
         x.lineinfo=nil
         for k, v in pairs(x) do dli(k); dli(v) end
      end
      return x
   end
   return table.tostring(dli(x), ...)
end

-- import gg_syntax.gg_expr_ast:
require 'gg-syntax.stage_ast'

-- import gg_syntax.decorate:
require 'gg-syntax.stage_decorate'

-- import gg_syntax.compile:
require 'gg-syntax.stage_compile'

function M.gg_expr (lx)
   local ast = M.gg_expr_ast (lx)
   print "\n***\nAST:"; table.print (ast, 'nohash', 80)
   M.decorate (ast)
   print "\n***\nDECORATED AST:"; print (tonolistr(ast, 80))
   return M.compile (ast)
end

require 'gg-syntax.stage_extension'

print "loaded"