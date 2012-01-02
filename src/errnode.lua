require 'metalua.compiler'
--
-- Ecapsulates funcion mlc.luastring_to_ast in order to protect call and parse
-- error string when an error occurs.
--
-- @param src string containg Lua code to evaluate
-- @return AST of table type, as returned by mlc.luastring_to_ast. Contains an
--	error when AST generation fails
--
function getast(src)
   local status, result = pcall(mlc.luastring_to_ast, src)
   if status then return result else
      local line, column, offset = result:match '%(l.(%d+), c.(%d+), k.(%d+)%)'
      local filename = result :match '^([^:]+)'
      local msg = result :match 'line %d+, char %d+: (.-)\n'
      local li = {line, column, offset, filename}
      return {tag='Error', lineinfo={first=li, last=li}, msg}
   end
end
