--*-lua-*--
package = "metalua-parser"
version = "0.7.2-1"
source = {
   url = "git://git.eclipse.org/gitroot/koneki/org.eclipse.koneki.metalua.git",
   tag = "v0.7.2",
}
description = {
   summary = "Metalua's parser: converting Lua source strings and files into AST",
   detailed = [[
           This is a subset of the full Metalua compiler. It defines and generates an AST
           format for Lua programs, which offers a nice level of abstraction to reason about
           and manipulate Lua programs.
   ]],
   homepage = "http://git.eclipse.org/c/koneki/org.eclipse.koneki.metalua.git",
   license = "EPL + MIT"
}
dependencies = {
    "lua ~> 5.1",
    "checks >= 1.0",
}
build = {
    type="builtin",
    modules={
        ["metalua.grammar.generator"] = "metalua/grammar/generator.lua",
        ["metalua.grammar.lexer"] = "metalua/grammar/lexer.lua",
        ["metalua.compiler.parser"] = "metalua/compiler/parser.lua",
        ["metalua.compiler.parser.common"] = "metalua/compiler/parser/common.lua",
        ["metalua.compiler.parser.table"] = "metalua/compiler/parser/table.lua",
        ["metalua.compiler.parser.ext"] = "metalua/compiler/parser/ext.lua",
        ["metalua.compiler.parser.annot.generator"] = "metalua/compiler/parser/annot/generator.lua",
        ["metalua.compiler.parser.annot.grammar"] = "metalua/compiler/parser/annot/grammar.lua",
        ["metalua.compiler.parser.stat"] = "metalua/compiler/parser/stat.lua",
        ["metalua.compiler.parser.misc"] = "metalua/compiler/parser/misc.lua",
        ["metalua.compiler.parser.lexer"] = "metalua/compiler/parser/lexer.lua",
        ["metalua.compiler.parser.meta"] = "metalua/compiler/parser/meta.lua",
        ["metalua.compiler.parser.expr"] = "metalua/compiler/parser/expr.lua",
        ["metalua.compiler"] = "metalua/compiler.lua",
        ["metalua.pprint"] = "metalua/pprint.lua",
    }
}

