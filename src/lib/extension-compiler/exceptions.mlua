require "std"

function try_with_builder(x)
   local block, handlers = x[1], x[3]
   local result, exn, endmark = 
      mlp.gensym "_result", mlp.gensym "_exn", mlp.gensym "_endmark"
   local function parse_exn_handler (x)
      local exn_test, block = x[1], x[2]
       return { +{ -{exn_test} <= -{exn} }, block }
    end
   local catchers = table.flatten (table.map(parse_exn_handler, handlers))   
   catchers.tag = "If"
   table.insert (catchers, { `Call{ `Id "error", exn } } )
   table.insert (block, `Return{ endmark })
   return +{ block:
      local -{endmark} = { }
      local -{result}  = { pcall (function() -{block} end) }
      if -{result}[1] then -- no exception raised
         if -{result}[2] ~= -{endmark} then -- user-caused return: propagate it
            table.remove( -{result}, 1)
            return unpack( -{result})
         end
      else -- an error/exception occured
         local -{exn} = -{result}[2]
         -{catchers} 
      end }
end

mlp.block.terminators:add{ "|", "with" }
mlp.lexer:add{ "try", "with", "->" }
mlp.stat:add{ name="try block",
   "try", mlp.block, "with", 
   gg.optkeyword "|",
   gg.list{ name="exception catchers list",
      gg.sequence{ name="exception catching case",
         mlp.expr, "->", mlp.block },
      separators = "|", terminators = "end" },
   "end",
   builder = try_with_builder }