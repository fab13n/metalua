--x = dynamatch()
--x <| foo | bar -> do toto end
--table.insert(x.cases, |$| match $ with foo|bar -> toto end    )


local match_builder = mlp.stat:get "match"

function dynacase_builder (d, s)
   local  v = mlp.gensym()
   local  m = match_builder{ v, false, { s[1], s[2], s[3] } }
   local  c = `Function{ {v}, {m} }
   return `Call{ `Index{ d, "extend" }, c }
end

--fixme: limiter la precedence du expr de droite
mlp.expr.suffix:add{ 
   name = "dynamatch extension", prec=30, 
   "<|",  
   gg.list{ name = "patterns",
      primary = mlp.expr,
      separators = "|",
      terminators = { "->", "if" } },
   gg.onkeyword{ "if", mlp.expr },
   "->",
   gg.multisequence{
      { "do", mlp.block, "end", builder = |x| x[1] },
      default = { mlp.expr, builder = |x| { `Return{ x[1] } } } },
   builder = |x| dyna_builder (x[1], x[3]) }

