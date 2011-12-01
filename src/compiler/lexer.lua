----------------------------------------------------------------------
-- Metalua:  $Id: mll.lua,v 1.3 2006/11/15 09:07:50 fab13n Exp $
--
-- Summary: generic Lua-style lexer definition. You need this plus
-- some keyword additions to create the complete Lua lexer,
-- as is done in mlp_lexer.lua.
--
-- TODO: 
--
-- * Make it easy to define new flavors of strings. Replacing the
--   lexer.patterns.long_string regexp by an extensible list, with
--   customizable token tag, would probably be enough. Maybe add:
--   + an index of capture for the regexp, that would specify 
--     which capture holds the content of the string-like token
--   + a token tag
--   + or a string->string transformer function.
--
-- * There are some _G.table to prevent a namespace clash which has
--   now disappered. remove them.
----------------------------------------------------------------------
--
-- Copyright (c) 2006-2011, Fabien Fleutot <metalua@gmail.com>.
--
-- This software is released under the MIT Licence, see licence.txt
-- for details.
--
----------------------------------------------------------------------

module ("lexer", package.seeall)


lexer = { alpha={ }, sym={ } }
lexer.__index=lexer

local debugf = function() end
--local debugf=printf


----------------------------------------------------------------------
-- Some locale settings produce bad results, e.g. French locale
-- expects float numbers to use commas instead of periods.
----------------------------------------------------------------------
os.setlocale('C')

----------------------------------------------------------------------
-- Create a new metatable, for a new class of objects.
----------------------------------------------------------------------
local function new_metatable(name) 
    local mt = { __type = 'metalua::lexer::'..name }; 
    mt.__index = mt; return mt
end



----------------------------------------------------------------------
-- Position: represent a point in a source file.
----------------------------------------------------------------------
position_metatable = new_metatable 'position'

local position_idx=1

function new_position(line, column, offset, source)
    -- assert(type(line)=='number')
    -- assert(type(column)=='number')
    -- assert(type(offset)=='number')
    -- assert(type(source)=='string')
    local id = position_idx; position_idx = position_idx+1
    return setmetatable({line=line, column=column, offset=offset, source=source, id=id}, position_metatable)
end

function position_metatable :__tostring()
    return string.format("<%s%s|L%d|C%d|K%d>", 
        self.comments and "C|" or "",
        self.source, self.line, self.column, self.offset)
end



----------------------------------------------------------------------
-- Position factory: convert offsets into line/column/offset positions.
----------------------------------------------------------------------
position_factory_metatable = new_metatable 'position_factory'

function new_position_factory(src, src_name)
    -- assert(type(src)=='string')
    -- assert(type(src_name)=='string')
    local lines = { 1 }
    for offset in src :gmatch '\n()' do table.insert(lines, offset) end
    local max = #src+1
    table.insert(lines, max+1) -- +1 includes Eof
    return setmetatable({ src_name=src_name, line2offset=lines, max=max }, 
        position_factory_metatable)
end

function position_factory_metatable :get_position (offset)
    -- assert(type(offset)=='number')
    assert(offset<=self.max)
    local line2offset = self.line2offset
    local left  = self.last_left or 1
    if offset<line2offset[left] then left=1 end
    local right = left+1
    if line2offset[right]<=offset then right = right+1 end
    if line2offset[right]<=offset then right = #line2offset end
    while true do
        -- print ("  trying lines "..left.."/"..right..", offsets "..line2offset[left]..
        --        "/"..line2offset[right].." for offset "..offset)
        -- assert(line2offset[left]<=offset)
        -- assert(offset<line2offset[right])
        -- assert(left<right)
        if left+1==right then break end
        local middle = math.floor((left+right)/2)
        if line2offset[middle]<=offset then left=middle else right=middle end
    end
    -- assert(left+1==right)
    -- printf("found that offset %d is between %d and %d, hence on line %d",
    --    offset, line2offset[left], line2offset[right], left)
    local line = left
    local column = offset - line2offset[line] + 1
    self.last_left = left
    return new_position(line, column, offset, self.src_name)
end



----------------------------------------------------------------------
-- Lineinfo: represent a node's range in a source file;
-- embed information about prefix and suffix comments.
----------------------------------------------------------------------
lineinfo_metatable = new_metatable 'lineinfo'

function new_lineinfo(first, last)
    assert(first.__type=='metalua::lexer::position')
    assert(last.__type=='metalua::lexer::position')
    return setmetatable({first=first, last=last}, lineinfo_metatable)
end

function lineinfo_metatable :__tostring()
    local fli, lli = self.first, self.last
    local line   = fli.line;   if line~=lli.line     then line  =line  ..'-'..lli.line   end
    local column = fli.column; if column~=lli.column then column=column..'-'..lli.column end
    local offset = fli.offset; if offset~=lli.offset then offset=offset..'-'..lli.offset end
    return string.format("<%s%s|L%s|C%s|K%s%s>", 
                         fli.comments and "C|" or "",
                         fli.source, line, column, offset,
                         lli.comments and "|C" or "")
end



----------------------------------------------------------------------
-- Token: atomic Lua language element, with a category, a content,
-- and some lineinfo relating it to its original source.
----------------------------------------------------------------------
token_metatable = new_metatable 'token'

function new_token(tag, content, lineinfo)
    --printf("TOKEN `%s{ %q, lineinfo = %s} boundaries %d, %d", 
    --       tag, content, tostring(lineinfo), lineinfo.first.id, lineinfo.last.id) 
    return setmetatable({tag=tag, lineinfo=lineinfo, content}, token_metatable)
end


----------------------------------------------------------------------
-- Comment: series of comment blocks with associated lineinfo.
-- To be attached to the tokens just before and just after them.
----------------------------------------------------------------------
comment_metatable = new_metatable 'comment'

function new_comment(lines)
    local first = lines[1].lineinfo.first
    local last  = lines[#lines].lineinfo.last
    local lineinfo = new_lineinfo(first, last)
    return setmetatable({lineinfo=lineinfo, unpack(lines)}, comment_metatable)
end

function comment_metatable :text()
    local last_line = self[1].lineinfo.last.line
    local acc = { }
    for i, line in ipairs(self) do
        local nreturns = line.lineinfo.first.line - last_line
        table.insert(acc, ("\n"):rep(nreturns))
        table.insert(acc, line[1])
    end
    return table.concat(acc)
end

function new_comment_line(text, lineinfo, nequals)
    assert(type(text)=='string')
    assert(lineinfo.__type=='metalua::lexer::lineinfo')
    assert(nequals==nil or type(nequals)=='number')
    return { lineinfo = lineinfo, text, nequals }
end



----------------------------------------------------------------------
-- Patterns used by [lexer :extract] to decompose the raw string into
-- correctly tagged tokens.
----------------------------------------------------------------------
lexer.patterns = {
   spaces              = "^[ \r\n\t]*()",
   short_comment       = "^%-%-([^\n]*)\n?()",
   --final_short_comment = "^%-%-([^\n]*)()$",
   long_comment        = "^%-%-%[(=*)%[\n?(.-)%]%1%]()",
   long_string         = "^%[(=*)%[\n?(.-)%]%1%]()",
   number_mantissa     = { "^%d+%.?%d*()", "^%d*%.%d+()" },
   number_mantissa_hex = { "^%x+%.?%x*()", "^%x*%.%x+()" }, --Lua5.1 and Lua5.2
   number_exponant     = "^[eE][%+%-]?%d+()",
   number_exponant_hex = "^[pP][%+%-]?%d+()", --Lua5.2
   number_hex          = "^0[xX]()",
   word                = "^([%a_][%w_]*)()"
}

----------------------------------------------------------------------
-- unescape a whole string, applying [unesc_digits] and
-- [unesc_letter] as many times as required.
----------------------------------------------------------------------
local function unescape_string (s)

   -- Turn the digits of an escape sequence into the corresponding
   -- character, e.g. [unesc_digits("123") == string.char(123)].
   local function unesc_digits (backslashes, digits)
      if #backslashes%2==0 then
         -- Even number of backslashes, they escape each other, not the digits.
         -- Return them so that unesc_letter() can treat them
         return backslashes..digits
      else
         -- Remove the odd backslash, which escapes the number sequence.
         -- The rest will be returned and parsed by unesc_letter()
         backslashes = backslashes :sub (1,-2)
      end
      local k, j, i = digits :reverse() :byte(1, 3)
      local z = _G.string.byte "0"
      local code = (k or z) + 10*(j or z) + 100*(i or z) - 111*z
      if code > 255 then 
         error ("Illegal escape sequence '\\"..digits..
                "' in string: ASCII codes must be in [0..255]") 
      end
      local c = string.char (code)
      if c == '\\' then c = '\\\\' end -- parsed by unesc_letter (test: "\092b" --> "\\b")
      return backslashes..c
   end

   -- Turn hex digits of escape sequence into char.
   local function unesc_hex(backslashes, digits)
     if #backslashes%2==0 then
       return backslashes..'x'..digits
     else
       backslashes = backslashes :sub (1,-2)
     end
     local c = string.char(tonumber(digits,16))
     if c == '\\' then c = '\\\\' end -- parsed by unesc_letter (test: "\x5cb" --> "\\b")
     return backslashes..c
   end
   
   -- Handle Lua 5.2 \z sequences
   local function unesc_z(backslashes, more)
     if #backslashes%2==0 then
       return backslashes..more
     else
       return backslashes :sub (1,-2)
     end
   end

   -- Take a letter [x], and returns the character represented by the 
   -- sequence ['\\'..x], e.g. [unesc_letter "n" == "\n"].
   local function unesc_letter(x)
      local t = { 
         a = "\a", b = "\b", f = "\f",
         n = "\n", r = "\r", t = "\t", v = "\v",
         ["\\"] = "\\", ["'"] = "'", ['"'] = '"', ["\n"] = "\n" }
      return t[x] or error([[Unknown escape sequence '\]]..x..[[']])
   end

   s = s: gsub ("(\\+)(z%s*)", unesc_z)  -- Lua 5.2
   s = s: gsub ("(\\+)([0-9][0-9]?[0-9]?)", unesc_digits)
   s = s: gsub ("(\\+)x([0-9a-fA-F][0-9a-fA-F])", unesc_hex) -- Lua 5.2
   s = s: gsub ("\\(%D)",unesc_letter)
   return s
end

lexer.extractors = {
   "extract_long_comment", "extract_short_comment",
   "extract_short_string", "extract_word", "extract_number", 
   "extract_long_string", "extract_symbol" }



----------------------------------------------------------------------
-- Really extract next token from the raw string 
-- (and update the index).
-- loc: offset of the position just after spaces and comments
-- previous_i: offset in src before extraction began
----------------------------------------------------------------------
function lexer :extract ()
   local attached_comments = { }
   local function gen_token(...)
      local token = new_token(...)
      if #attached_comments>0 then -- attach previous comments to token
         local comments = new_comment(attached_comments)
         token.lineinfo.first.comments = comments
         if self.lineinfo_last then
            self.lineinfo_last.comments = comments 
         end
         attached_comments = { }
      end
      return token
   end
   while true do -- loop until a non-comment token is found

       -- skip whitespaces
       self.i = self.src:match (self.patterns.spaces, self.i)
       if self.i>#self.src then
         local fli = self.posfact :get_position (#self.src+1)
         local lli = self.posfact :get_position (#self.src+1) -- ok?
         return gen_token("Eof", "eof", new_lineinfo(fli, lli))
       end
       local i_first = self.i -- loc = position after whitespaces
       
       -- try every extractor until a token is found
       for _, extractor in ipairs(self.extractors) do
           local tag, content, xtra = self [extractor] (self)
           if tag then
               local fli = self.posfact :get_position (i_first)
               local lli = self.posfact :get_position (self.i-1)
               local lineinfo = new_lineinfo(fli, lli)
               if tag=='Comment' then
                   local prev_comment = attached_comments[#attached_comments]
                   if not xtra -- new comment is short
                   and prev_comment and not prev_comment[2] -- prev comment is short
                   and prev_comment.lineinfo.last.line+1==fli.line then -- adjascent lines
                       -- concat with previous comment
                       prev_comment[1] = prev_comment[1].."\n"..content -- TODO quadratic, BAD!
                       prev_comment.lineinfo.last = lli
                   else -- accumulate comment
                       local comment = new_comment_line(content, lineinfo, xtra)
                       table.insert(attached_comments, comment)
                   end
                   break -- back to skipping spaces
               else -- not a comment: real token, then
                   return gen_token(tag, content, lineinfo)
               end -- if token is a comment
           end -- if token found
       end -- for each extractor
   end -- while token is a comment
end -- :extract()




----------------------------------------------------------------------
-- Extract a short comment.
----------------------------------------------------------------------
function lexer :extract_short_comment()
    -- TODO: handle final_short_comment
    local content, j = self.src :match (self.patterns.short_comment, self.i)
    if content then self.i=j; return 'Comment', content, nil end
end

----------------------------------------------------------------------
-- Extract a long comment.
----------------------------------------------------------------------
function lexer :extract_long_comment()
    local equals, content, j = self.src:match (self.patterns.long_comment, self.i)
    if j then self.i = j; return "Comment", content, #equals end
end

----------------------------------------------------------------------
-- Extract a '...' or "..." short string.
----------------------------------------------------------------------
function lexer :extract_short_string()
   local k = self.src :sub (self.i,self.i)   -- first char
   if k~=[[']] and k~=[["]] then return end  -- no match
   local i = self.i + 1
   local j = i
   while true do
      local x,y; x, j, y = self.src :match ("([\\\r\n"..k.."])()(.?)", j)  -- next interesting char
      if x == '\\' then
        if y == 'z' then -- Lua 5.2 \z
          j = self.src :match ("^%s*()", j+1)
        else
          j=j+1  -- escaped char
        end
      elseif x == k then break -- end of string
      else
         assert (not x or x=='\r' or x=='\n')
         error "Unterminated string"
      end
   end
   self.i = j

   return 'String', unescape_string (self.src :sub (i,j-2))
end

----------------------------------------------------------------------
-- Extract Id or Keyword.
----------------------------------------------------------------------
function lexer :extract_word()
   local word, j = self.src:match (self.patterns.word, self.i)
   if word then
      self.i = j
      return (self.alpha [word] and 'Keyword' or 'Id'), word
   end
end

----------------------------------------------------------------------
-- Extract Number.
----------------------------------------------------------------------
function lexer :extract_number()
   local j = self.src:match(self.patterns.number_hex, self.i)
   if j then
      j = self.src:match (self.patterns.number_mantissa_hex[1], j) or
          self.src:match (self.patterns.number_mantissa_hex[2], j)
      if j then
         j = self.src:match (self.patterns.number_exponant_hex, j) or j
      end
   else
      j = self.src:match (self.patterns.number_mantissa[1], self.i) or
          self.src:match (self.patterns.number_mantissa[2], self.i)
      if j then
         j = self.src:match (self.patterns.number_exponant, j) or j
      end
   end
   if not j then return end
   local n = tonumber (self.src :sub (self.i, j-1))
      -- :TODO: tonumber on Lua5.2 floating hex may or may not work on Lua5.1
   self.i = j
   return 'Number', n
end

----------------------------------------------------------------------
-- Extract long string.
----------------------------------------------------------------------
function lexer :extract_long_string()
   local _, content, j = self.src :match (self.patterns.long_string, self.i)
   if j then self.i = j; return 'String', content end
end

----------------------------------------------------------------------
-- Extract symbol.
----------------------------------------------------------------------
function lexer :extract_symbol()
   local k = self.src:sub (self.i,self.i)
   local symk = self.sym [k]  -- symbols starting with `k`
   if not symk then 
      self.i = self.i + 1
      return 'Keyword', k
   end
   for _, sym in pairs (symk) do
      if sym == self.src:sub (self.i, self.i + #sym - 1) then 
         self.i = self.i + #sym
         return 'Keyword', sym
      end
   end
   self.i = self.i+1
   return 'Keyword', k
end

----------------------------------------------------------------------
-- Add a keyword to the list of keywords recognized by the lexer.
----------------------------------------------------------------------
function lexer :add (w, ...)
   assert(not ..., "lexer :add() takes only one arg, although possibly a table")
   if type (w) == "table" then
      for _, x in ipairs (w) do self :add (x) end
   else
      if w:match (self.patterns.word .. "$") then self.alpha [w] = true
      elseif w:match "^%p%p+$" then 
         local k = w:sub(1,1)
         local list = self.sym [k]
         if not list then list = { }; self.sym [k] = list end
         _G.table.insert (list, w)
      elseif w:match "^%p$" then return
      else error "Invalid keyword" end
   end
end

----------------------------------------------------------------------
-- Return the [n]th next token, without consumming it.
-- [n] defaults to 1. If it goes pass the end of the stream, an EOF
-- token is returned.
----------------------------------------------------------------------
function lexer :peek (n)
    if not n then n=1 end
    if n > #self.peeked then
        for i = #self.peeked+1, n do
            self.peeked [i] = self :extract()
        end
    end
    return self.peeked [n]
end

----------------------------------------------------------------------
-- Return the [n]th next token, removing it as well as the 0..n-1
-- previous tokens. [n] defaults to 1. If it goes pass the end of the
-- stream, an EOF token is returned.
----------------------------------------------------------------------
function lexer :next (n)
   n = n or 1
   self :peek (n)
   local a
   for i=1,n do
      a = _G.table.remove (self.peeked, 1) 
      -- TODO: is this used anywhere? I think not.  a.lineinfo.last may be nil.
      --self.lastline = a.lineinfo.last.line
   end
   self.lineinfo_last = a.lineinfo.last
   return a
end

----------------------------------------------------------------------
-- Returns an object which saves the stream's current state.
----------------------------------------------------------------------
-- FIXME there are more fields than that to save
function lexer :save () return { self.i; _G.table.cat(self.peeked) } end

----------------------------------------------------------------------
-- Restore the stream's state, as saved by method [save].
----------------------------------------------------------------------
-- FIXME there are more fields than that to restore
function lexer :restore (s) self.i=s[1]; self.peeked=s[2] end

----------------------------------------------------------------------
-- Resynchronize: cancel any token in self.peeked, by emptying the
-- list and resetting the indexes
----------------------------------------------------------------------
function lexer :sync()
   local p1 = self.peeked[1]
   if p1 then 
      local li_first = p1.lineinfo.first
      if li_first.comments then li_first=li_first.comments.lineinfo.first end
      self.i = li_first.offset
      self.column_offset = self.i - li_first.column
      self.peeked = { }
      self.attached_comments = p1.lineinfo.first.comments or { }
   end
end

----------------------------------------------------------------------
-- Take the source and offset of an old lexer.
----------------------------------------------------------------------
function lexer :takeover(old)
   self :sync(); old :sync()
   for _, field in ipairs{ 'i', 'src', 'attached_comments', 'posfact' } do
       self[field] = old[field]
   end
   return self
end

----------------------------------------------------------------------
-- Return the current position in the sources. This position is between
-- two tokens, and can be within a space / comment area, and therefore
-- have a non-null width. :lineinfo_left() returns the beginning of the
-- separation area, :lineinfo_right() returns the end of that area.
--
--    ____ last consummed token    ____ first unconsummed token
--   /                            /
-- XXXXX  <spaces and comments> YYYYY
--      \____                    \____
--           :lineinfo_left()         :lineinfo_right()
----------------------------------------------------------------------
function lexer :lineinfo_right()
   return self :peek(1).lineinfo.first
end

function lexer :lineinfo_left()
   return self.lineinfo_last
end

----------------------------------------------------------------------
-- Create a new lexstream.
----------------------------------------------------------------------
function lexer :newstream (src_or_stream, name)
   name = name or "?"
   if type(src_or_stream)=='table' then -- it's a stream
      return setmetatable ({ }, self) :takeover (src_or_stream)
   elseif type(src_or_stream)=='string' then -- it's a source string
      local src = src_or_stream
      local stream = { 
         src_name      = name;   -- Name of the file
         src           = src;    -- The source, as a single string
         peeked        = { };    -- Already peeked, but not discarded yet, tokens
         i             = 1;      -- Character offset in src
         attached_comments = { },-- comments accumulator
         lineinfo_last = new_position(1, 1, 1, name),
         posfact       = new_position_factory (src_or_stream, name)
      }
      setmetatable (stream, self)

      -- skip initial sharp-bang for unix scripts
      -- FIXME: redundant with mlp.chunk()
      if src and src :match "^#" then stream.i = src :find "\n" + 1 end
      return stream
   else
      assert(false, ":newstream() takes a source string or a stream, not a "..
          type(src_or_stream))
   end
end

----------------------------------------------------------------------
-- if there's no ... args, return the token a (whose truth value is
-- true) if it's a `Keyword{ }, or nil.  If there are ... args, they
-- have to be strings. if the token a is a keyword, and it's content
-- is one of the ... args, then returns it (it's truth value is
-- true). If no a keyword or not in ..., return nil.
----------------------------------------------------------------------
function lexer :is_keyword (a, ...)
   if not a or a.tag ~= "Keyword" then return false end
   local words = {...}
   if #words == 0 then return a[1] end
   for _, w in ipairs (words) do
      if w == a[1] then return w end
   end
   return false
end

----------------------------------------------------------------------
-- Cause an error if the next token isn't a keyword whose content
-- is listed among ... args (which have to be strings).
----------------------------------------------------------------------
function lexer :check (...)
   local words = {...}
   local a = self :next()
   local function err ()
      error ("Got " .. tostring (a) .. 
             ", expected one of these keywords : '" ..
             _G.table.concat (words,"', '") .. "'") end
          
   if not a or a.tag ~= "Keyword" then err () end
   if #words == 0 then return a[1] end
   for _, w in ipairs (words) do
       if w == a[1] then return w end
   end
   err ()
end

----------------------------------------------------------------------
-- 
----------------------------------------------------------------------
function lexer :clone()
   require 'metalua.runtime'
   local clone = {
      alpha = table.deep_copy(self.alpha),
      sym   = table.deep_copy(self.sym) }
   setmetatable(clone, self)
   clone.__index = clone
   return clone
end
