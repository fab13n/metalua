----------------------------------------------------------------------
-- Metalua:  $Id: mll.lua,v 1.3 2006/11/15 09:07:50 fab13n Exp $
--
-- Summary: generic Lua-style lexer definition. You need this plus
-- some keyword additions to create the complete Lua lexer,
-- as is done in mlp_lexer.lua.
--
-- TODO: 
--
-- * Make it possible to change lexer on the fly. This implies the
--   ability to easily undo any pre-extracted tokens;
--
-- * Make it easy to define new flavors of strings. Replacing the
--   lexer.patterns.long_string regexp by an extensible list, with
--   customizable token tag, would probably be enough. Maybe add:
--   + an index of capture for the regexp, that would specify 
--     which capture holds the content of the string-like token
--   + a token tag
--   + or a string->string transformer function.
----------------------------------------------------------------------
--
-- Copyright (c) 2006, Fabien Fleutot <metalua@gmail.com>.
--
-- This software is released under the MIT Licence, see licence.txt
-- for details.
--
----------------------------------------------------------------------

module ("lexer", package.seeall)

require 'metalua.runtime'


lexer = { alpha={ }, sym={ } }
lexer.__index=lexer

local debugf = function() end
--local debugf=printf

----------------------------------------------------------------------
-- Patterns used by [lexer:extract] to decompose the raw string into
-- correctly tagged tokens.
----------------------------------------------------------------------
lexer.patterns = {
   spaces              = "^[ \r\n\t]*()",
   short_comment       = "^%-%-([^\n]*)()\n",
   final_short_comment = "^%-%-([^\n]*)()$",
   long_comment        = "^%-%-%[(=*)%[\n?(.-)%]%1%]()",
   long_string         = "^%[(=*)%[\n?(.-)%]%1%]()",
   number_mantissa     = {
      "^%d+%.?%d*()",
      "^%d*%d%.%d+()" },
   number_exponant = "^[eE][%+%-]?%d+()",
   word            = "^([%a_][%w_]*)()"
}

----------------------------------------------------------------------
-- Take a letter [x], and returns the character represented by the 
-- sequence ['\\'..x], e.g. [unesc_letter "n" == "\n"].
----------------------------------------------------------------------
local function unesc_letter(x)
   local t = { 
      a = "\a", b = "\b", f = "\f",
      n = "\n", r = "\r", t = "\t", v = "\v",
      ["\\"] = "\\", ["'"] = "'", ['"'] = '"' }
   return t[x] or error("Unknown escape sequence \\"..x)
end

----------------------------------------------------------------------
-- Turn the digits of an escape sequence into the corresponding
-- character, e.g. [unesc_digits("123") == string.char(123)].
----------------------------------------------------------------------
local function unesc_digits (x)
   local k, j, i = x:reverse():byte(1, 3)
   local z = _G.string.byte "0"
   return _G.string.char ((k or z) + 10*(j or z) + 100*(i or z) - 111*z)
end

----------------------------------------------------------------------
-- unescape a whole string, applying [unesc_digits] and [unesc_letter]
-- as many times as required.
----------------------------------------------------------------------
local function unescape_string (s)
   return s:gsub("\\([0-9]+)", unesc_digits):gsub("\\(.)",unesc_letter)
end

lexer.extractors = {
   "skip_whitespaces_and_comments",
   "extract_short_string", "extract_word", "extract_number", 
   "extract_long_string", "extract_symbol" }

lexer.token_metatable = { 
--         __tostring = function(a) 
--            return string.format ("`%s{'%s'}",a.tag, a[1]) 
--         end 
      } 

----------------------------------------------------------------------
-- Really extract next token fron the raw string 
-- (and update the index).
----------------------------------------------------------------------
function lexer:extract ()
   local previous_i = self.i
   local loc, eof, token = self.i

   local function tk (tag, content)
      assert (tag and content)
      local i, ln = previous_i, self.line
      -- update line numbers
      while true do
         i = self.src:find("\n", i+1, true)
         if not i then break end
         if loc and i <= loc then ln = ln+1 end
         if i <= self.i then self.line = self.line+1 else break end
      end
      local a = { tag      = tag, 
                  char     = loc,
                  lineinfo = { first = ln, last = self.line },
                  line     = self.line,
                  content } 
      -- FIXME [EVE] make lineinfo passing less memory consuming
      -- FIXME [Fabien] suppress line/lineinfo.line redundancy.
      if #self.attached_comments > 0 then 
         a.comments = self.attached_comments 
         self.attached_comments = nil
      end
      return setmetatable (a, self.token_metatable)
   end

   self.attached_comments = { }
   
   for ext_idx, extractor in ipairs(self.extractors) do
      -- printf("method = %s", method)
      local tag, content = self[extractor](self)
      -- [loc] is placed just after the leading whitespaces and comments,
      -- and the whitespace extractor is at index 1.
      if ext_idx==1 then loc = self.i end

      if tag then 
         --printf("`%s{ %q }\t%i", tag, content, loc);
         return tk (tag, content) 
      end
   end

   error "Cant extract anything!"
end   

----------------------------------------------------------------------
-- skip whites and comments
-- FIXME: doesn't take into account:
-- - unterminated long comments
-- - short comments without a final \n
----------------------------------------------------------------------
function lexer:skip_whitespaces_and_comments()
   local attached_comments = { }
   repeat
      local _, j
      local again = false
      local last_comment_content = nil
      -- skip spaces
      self.i = self.src:match (self.patterns.spaces, self.i)
      -- skip a long comment if any
      _, last_comment_content, j = self.src:match (self.patterns.long_comment, self.i)
      if j then 
         _G.table.insert(self.attached_comments, 
                         {last_comment_content, self.i, j, "long"})
         self.i=j; again=true 
      end
      -- skip a short comment if any
      last_comment_content, j = self.src:match (self.patterns.short_comment, self.i)
      if j then
         _G.table.insert(attached_comments, 
                         {last_comment_content, self.i, j, "short"})
         self.i=j; again=true 
      end
      if self.i>#self.src then return "Eof", "eof" end
   until not again

   if self.src:match (self.patterns.final_short_comment, self.i) then 
      return "Eof", "eof" end
   --assert (not self.src:match(self.patterns.short_comment, self.i))
   --assert (not self.src:match(self.patterns.long_comment, self.i))
   -- --assert (not self.src:match(self.patterns.spaces, self.i))
   return
end

----------------------------------------------------------------------
--
----------------------------------------------------------------------
function lexer:extract_short_string()
   -- [k] is the first unread char, [self.i] points to [k] in [self.src]
   local j, k = self.i, self.src:sub (self.i,self.i)
   if k=="'" or k=='"' then
      -- short string
      repeat
         self.i=self.i+1; 
         local kk = self.src:sub (self.i, self.i)
         if kk=="\\" then 
            self.i=self.i+1; 
            kk = self.src:sub (self.i, self.i)
         end
         if self.i > #self.src then error "Unterminated string" end
         if self.i == "\r" or self.i == "\n" then error "no \\n in short strings!" end
      until self.src:sub (self.i, self.i) == k 
         and ( self.src:sub (self.i-1, self.i-1) ~= '\\' 
         or self.src:sub (self.i-2, self.i-2) == '\\')
      self.i=self.i+1
      return "String", unescape_string (self.src:sub (j+1,self.i-2))
   end   
end

----------------------------------------------------------------------
--
----------------------------------------------------------------------
function lexer:extract_word()
   -- Id / keyword
   local word, j = self.src:match (self.patterns.word, self.i)
   if word then
      self.i = j
      if self.alpha [word] then return "Keyword", word
      else return "Id", word end
   end
end

----------------------------------------------------------------------
--
----------------------------------------------------------------------
function lexer:extract_number()
   -- Number
   local j = self.src:match (self.patterns.number_mantissa[1], self.i) or
             self.src:match (self.patterns.number_mantissa[2], self.i)
   if j then 
      j = self.src:match (self.patterns.number_exponant, j) or j;
      local n = tonumber (self.src:sub (self.i, j-1))
      self.i = j
      return "Number", n
   end
end

----------------------------------------------------------------------
--
----------------------------------------------------------------------
function lexer:extract_long_string()
   -- Long string
   local _, content, j = self.src:match (self.patterns.long_string, self.i)
   if j then self.i = j; return "String", content end
end

----------------------------------------------------------------------
--
----------------------------------------------------------------------
function lexer:extract_symbol()
   -- compound symbol
   local k = self.src:sub (self.i,self.i)
   local symk = self.sym [k]
   if not symk then 
      self.i = self.i + 1
      return "Keyword", k
   end
   for _, sym in pairs (symk) do
      if sym == self.src:sub (self.i, self.i + #sym - 1) then 
         self.i = self.i + #sym; 
         return "Keyword", sym
      end
   end
   -- single char symbol
   self.i = self.i+1
   return "Keyword", k
end

----------------------------------------------------------------------
-- Add a keyword to the list of keywords recognized by the lexer.
----------------------------------------------------------------------
function lexer:add (w, ...)
   assert(not ..., "lexer:add() takes only one arg, although possibly a table")
   if type (w) == "table" then
      for _, x in ipairs (w) do self:add (x) end
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
function lexer:peek (n)
   assert(self)
   if not n then n=1 end
   if n > #self.peeked then
      for i = #self.peeked+1, n do
         self.peeked [i] = self:extract()
      end
   end
  return self.peeked [n]
end

----------------------------------------------------------------------
-- Return the [n]th next token, removing it as well as the 0..n-1
-- previous tokens. [n] defaults to 1. If it goes pass the end of the
-- stream, an EOF token is returned.
----------------------------------------------------------------------
function lexer:next (n)
   if not n then n=1 end
   self:peek (n)
   local a
   for i=1,n do 
      a = _G.table.remove (self.peeked, 1) 
      if a then 
         debugf ("[L:%i K:%i T:%s %q]", a.line or -1, a.char or -1, 
                 a.tag or '<none>', a[1])
      end
      self.lastline = a.lineinfo.last
   end
   return a or eof_token
end

----------------------------------------------------------------------
-- Returns an object which saves the stream's current state.
----------------------------------------------------------------------
function lexer:save () return { self.i; _G.table.cat(self.peeked) } end

----------------------------------------------------------------------
-- Restore the stream's state, as saved by method [save].
----------------------------------------------------------------------
function lexer:restore (s) self.i=s[1]; self.peeked=s[2] end

----------------------------------------------------------------------
--
----------------------------------------------------------------------
function lexer:sync()
   local p1 = self.peeked[1]
   if p1 then 
      self.i, self.line, self.peeked = p1.char, p1.line, { }
   end
end

----------------------------------------------------------------------
-- Take over an old lexer.
----------------------------------------------------------------------
function lexer:takeover(old)
   self:sync()
   self.i, self.line, self.src = old.i, old.line, old.src
   return self
end

----------------------------------------------------------------------
-- Create a new lexstream.
----------------------------------------------------------------------
function lexer:newstream (src_or_stream)
   if type(src_or_stream)=='table' then -- it's a stream
      return setmetatable({ }, self):takeover(src_or_stream)
   elseif type(src_or_stream)=='string' then -- it's a source string
      local stream = { 
         src    = src_or_stream; -- The source, as a single string
         peeked = { };           -- Already peeked, but not discarded yet, tokens
         i      = 1;             -- Character offset in src
         line   = 1;             -- Current line number
      }
      setmetatable (stream, self)

      -- skip initial sharp-bang for unix scripts
      if src and src:match "^#!" then stream.i = src:find "\n" + 1 end
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
function lexer:is_keyword (a, ...)
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
function lexer:check (...)
   local words = {...}
   local a = self:next()
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
function lexer:clone()
   local clone = {
      alpha = table.deep_copy(self.alpha),
      sym   = table.deep_copy(self.sym) }
   setmetatable(clone, self)
   clone.__index = clone
   return clone
end
