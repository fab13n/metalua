require 'freevars'

local function anaphoric_if(ast)
   local it_found = false
   for i=2, #ast do 
      if freevars.block(ast[i])['it'] then
         it_found = true
         break
      end
   end
   if it_found then
      local cond = ast[1]
      ast[1] = +{it}
      return +{stat: do local it = -{cond}; -{ast} end }
   end
end

local function anaphoric_while(ast)
   local it_found = false
   if freevars.block(ast[2])['it'] then
      local cond = ast[1]
      ast[1] = +{it}
      return +{stat: do local it = -{cond}; -{ast} end }
   end
end

mlp.stat:get'if'.transformers:add(anaphoric_if)
mlp.stat:get'while'.transformers:add(anaphoric_while)