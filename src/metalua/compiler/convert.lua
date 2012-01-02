--*-lua-*-----------------------------------------------------------------------
--
-- Convert between various code representation formats. Some atomic
-- converters are written in extenso, others are composed automatically
-- by chaining the atomic ones together in a closure.
--
-- Supported formats are:
--
-- * luafile:    the name of a file containing sources.
-- * luastring:  these sources as a single string.
-- * lexstream:  a stream of lexemes.
-- * ast:        an abstract syntax tree.
-- * proto:      a (Yueliang) struture containing a high level 
--               representation of bytecode. Largely based on the 
--               Proto structure in Lua's VM.
-- * luacstring: a string dump of the function, as taken by 
--               loadstring() and produced by string.dump().
-- * function:   an executable lua function in RAM.
--
--------------------------------------------------------------------------------

local bytecode = require 'metalua.compiler.bytecode'
local mlp      = require 'metalua.compiler.parser'
local M        = { }

M.metabugs = false

--------------------------------------------------------------------------------
-- Order of the transformations. if 'a' is on the left of 'b', then a 'a' can
-- be transformed into a 'b' (but not the other way around).
-- M.sequence goes for numbers to format names, M.order goes from format
-- names to numbers.
--------------------------------------------------------------------------------
M.sequence = {
   'luafile',  'luastring', 'lexstream', 'ast', 'proto', 
   'luacstring', 'function' }

M.order = table.transpose(M.sequence)

-- Check whether a structure of nested tables is a valid AST.
-- Currently thows an error if it isn't.
-- TODO: return boolean + msg instead of throwing an error when AST is invalid.
-- TODO: build a detailed error location, with the lineinfo of every nested node.
local function check_ast(kind, ast)
    if not ast then return check_ast('block', kind) end
    assert(type(ast)=='table', "wrong AST type")
    local function error2ast(error_node, ...)
        if error_node.tag=='Error' then
            error(error_node[1])
        else
            local li
            for _, n in ipairs{ error_node, ... } do
                li = n.lineinfo
                if li then break end
            end
            local pos = li 
                and string.format("line %d, char #%d, offset %d",
                                  li[1], li[2], li[3])
                or "unknown source position"     
            local msg = "Invalid node tag "..tostring(error_node.tag).." at "..pos
            print (msg)
            table.print(ast, 'nohash')
            error (msg)
        end
    end
    local cfg = { malformed=error2ast; unknown=error2ast }
    local f = require 'metalua.treequery.walk' [kind]
    --print ("Checking AST "..table.tostring(ast, 'nohash'):sub(1, 130))
    f(cfg, ast)
    --print ("Checked AST: success")
end

M.check_ast = check_ast

function M.luafile_to_luastring(x, name)
    name = name or '@'..x
    local f, msg = io.open (x, 'rb')
    if not f then return f, msg end
    local r = f :read '*a'
    f :close()
    return r, name
end

function M.luastring_to_lexstream(src, name)
    local r = mlp.lexer:newstream (src, name)
    return r, name
end

function M.lexstream_to_ast(lx, name)
    if PRINT_PARSED_STAT then
        print("About to parse a lexstream, starting with "..tostring(lx:peek()))
    end
    local r = mlp.chunk(lx)    
    r.source = name
    return r, name
end

M.ast_to_proto = bytecode.ast_to_proto

function M.proto_to_luacstring(proto, name)
    return bytecode.dump_string(proto), name
end

function M.luacstring_to_function(bc, name)
    return loadstring(bc, name)
end

-- Create all sensible combinations
for i=1,#M.sequence do
    for j=i+2, #M.sequence do
        local dst_name = M.sequence[i].."_to_"..M.sequence[j]
        local functions = { }
        --local n = { }
        for k=i, j-1 do
            local name =  M.sequence[k].."_to_"..M.sequence[k+1]
            local f = assert(M[name])
            table.insert (functions, f)
            --table.insert(n, name)
        end
        M[dst_name] = function(a, b)
            for _, f in ipairs(functions) do
                a, b = f(a, b)
            end
            return a, b
        end
        --printf("Created M.%s out of %s", dst_name, table.concat(n, ', '))
    end
end


--------------------------------------------------------------------------------
-- This one goes in the "wrong" direction, cannot be composed.
--------------------------------------------------------------------------------
M.function_to_luacstring = string.dump

return M