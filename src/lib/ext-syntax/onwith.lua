-- > <functor> on <expr1>, <expr2>, ... <exprn> with <function>
-- is translated to:
-- > <functor>(<function>, <expr1>, <expr2>, ... <exprn>)
--
-- That's useful for stuff of the "foreach" family, where some
-- function is passed as a first argument, but is meant to represent
-- some sort of loop body. Typically, the following:
--
-- > [table.imap ((|x,y|x+y), t1, t2)]
-- is translated to:
-- > table.imap on t1, t2 with function (x, y)
-- >    return x+y
-- >  end
-- or even:
-- > table.imap on t1, t2 with |x,y| x+y


mlp.lexer:add{ "on", "with" }
mlp.expr.suffix:add{ "on", mlp.expr_list, "with", mlp.expr,
   builder = |x, y| `Call{x, y[2], unpack(y[1])} }