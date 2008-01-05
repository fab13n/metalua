-{ extension "match" }
-{ extension "ternary" }


local flist_builder = |x| x[2] ? 
   +{ flist.of_table(-{x[1]}) `flist.concat` -{x[2]} },  
   +{ flist.of_table(-{x[1]}) }


mlp.lexer:add{"<|","|>"}
mlp.expr:add{ name="flist", "<|", 
   gg.list{ mlp.expr, separators=",", terminators={":","|"}, builder = "Table" }, 
   gg.onkeyword{"|", mlp.expr }, "|>", builder = flist_builder }


