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

local mlp      = require 'metalua.compiler.parser'
local M        = { }

require 'checks'

M.metabugs = false

--------------------------------------------------------------------------------
-- Order of the transformations. if 'a' is on the left of 'b', then a 'a' can
-- be transformed into a 'b' (but not the other way around).
-- M.sequence goes for numbers to format names, M.order goes from format
-- names to numbers.
--------------------------------------------------------------------------------
M.sequence = {
   'srcfile',  'src', 'lexstream', 'ast', 'proto', 
   'bytecode', 'function' }

local arg_types = {
    srcfile    = { 'string', '?string' },
    src        = { 'string', '?string' },
    lexstream  = { 'lexer.stream', '?string' },
    ast        = { 'table', '?string' },
    proto      = { 'table', '?string' },
    bytecode   = { 'string', '?string' },
}

M.order = table.transpose(M.sequence)

-- Check whether a structure of nested tables is a valid AST.
-- Currently thorws an error if it isn't.
-- TODO: return boolean + msg instead of throwing an error when AST is invalid.
-- TODO: build a detailed error location, with the lineinfo of every nested node.
local function check_ast(kind, ast)
    if not ast then return check_ast('block', kind) end
    checks('string', 'table')
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

local function find_error(ast, nested)
    checks('table', '?table')
    nested = nested or { }
    if nested[ast] then return "Cyclic AST" end
    nested[ast]=true
    if ast.tag=='Error' then 
        local pos = tostring(ast.lineinfo.first)
        return pos..": "..ast[1]
    end
    for _, item in ipairs(ast) do
        if type(item)=='table' then
            local err=find_error(item)
            if err then return err end
        end
    end
    nested[ast]=nil
    return nil
end

function M.srcfile_to_src(x, name)
    checks('string', '?string')
    name = name or '@'..x
    local f, msg = io.open (x, 'rb')
    if not f then error(msg) end
    local r, msg = f :read '*a'
    if not r then error("Cannot read file '"..x.."': "..msg) end
    f :close()
    return r, name
end

function M.src_to_lexstream(src, name)
    checks('string', '?string')
    local r = mlp.lexer :newstream (src, name)
    return r, name
end

function M.lexstream_to_ast(lx, name)
    checks('lexer.stream', '?string')
    local r = mlp.chunk(lx)
    r.source = name
    return r, name
end

function M.ast_to_proto(ast, name)
    checks('table', '?string')
    --table.print(ast, 'nohash', 1)
    local err = find_error(ast)
    if err then error(err) end
    local f = require 'metalua.compiler.bytecode.compile'.ast_to_proto
    return f(ast, name), name
end

function M.proto_to_bytecode(proto, name)
    local bc = require 'metalua.compiler.bytecode'
    return bc.dump_string(proto), name
end

function M.bytecode_to_function(bc, name)
    checks('string', '?string')
    return loadstring(bc, name)
end

-- Create all sensible combinations
for i=1,#M.sequence do
    local src = M.sequence[i]
    for j=i+2, #M.sequence do
        local dst = M.sequence[j]
        local dst_name = src.."_to_"..dst
        local my_arg_types = arg_types[src]
        local functions = { }
        for k=i, j-1 do
            local name =  M.sequence[k].."_to_"..M.sequence[k+1]
            local f = assert(M[name], name)
            table.insert (functions, f)
        end
        M[dst_name] = function(a, b)
            checks(unpack(my_arg_types))
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
M.function_to_bytecode = string.dump

function M.ast_to_src(...)
    require 'metalua.package' -- ast_to_string isn't written in plain lua
    return require 'metalua.compiler.ast_to_src' (...)
end

return M