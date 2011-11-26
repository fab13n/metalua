-- tests of lexer (preliminary)
--
-- D.Manura.  Copyright (c) 2011, Fabien Fleutot <metalua@gmail.com>.
--
-- This software is released under the MIT Licence, see Metalua licence.txt
-- for details.


package.path = 'src/compiler/?.lua;src/lib/?.lua'

require 'mlp_lexer'
local LX = mlp.lexer

-- equality check.
local function checkeq(a, b)
  if a ~= b then
    error('not equal:\n' .. tostring(a) .. '\n' .. tostring(b), 2)
  end
end

-- reads file to string (with limited error handling)
local function readfile(filename)
  local fh = assert(io.open(filename, 'rb'))
  local text = fh:read'*a'
  fh:close()
  return text
end

-- formats token succinctly.
local function tokfmt(tok)
  local function fmt(o)
    return (type(o) == 'string') and ("%q"):format(o):sub(2,-2) or tostring(o)
  end
  return [[`]] .. tok.tag .. tostring(tok.lineinfo):gsub('%|L[^%|]*%|C[^%|]*', '') .. '{' .. fmt(tok[1]) .. '}'
end

-- utility function to lex code
local function lex(code)
  local sm = LX:newstream(code)
  local toks = {}
  while 1 do
    local tok = sm:next()
    toks[#toks+1] = tokfmt(tok)
    if tok.tag == 'Eof' then
      break
    end
  end
  return table.concat(toks)
end
local function tlex(code)
  local sm = LX:newstream(code)
  local toks = {}
  while 1 do
    local tok = sm:next()
    toks[#toks+1] = tok
    if tok.tag == 'Eof' then break end
  end
return toks
end
local function plex(code)
  return pcall(lex, code)
end

--FIX checkeq(nil, plex '====')

-- trivial tests
checkeq(lex[[]], [[`Eof<?|K1>{eof}]])
checkeq(lex'\t', [[`Eof<?|K2>{eof}]])
checkeq(lex'\n', [[`Eof<?|K2>{eof}]])
checkeq(lex'--', [[`Eof<C|?|K3>{eof}]])
checkeq(lex'\n -- \n--\n ', [[`Eof<C|?|K11>{eof}]])
checkeq(lex[[return]], [[`Keyword<?|K1-6>{return}`Eof<?|K7>{eof}]])

-- string tests
checkeq(lex[["\092b"]],  [[`String<?|K1-7>{\\b}`Eof<?|K8>{eof}]]) -- was bug
checkeq(lex[["\x5Cb"]],  [[`String<?|K1-7>{\\b}`Eof<?|K8>{eof}]]) -- [5.2]
checkeq(lex[["\0\t\090\100\\\1004"]],  [[`String<?|K1-21>{\000	Zd\\d4}`Eof<?|K22>{eof}]]) -- decimal/escape

-- number tests, hex (including Lua 5.2)
local t = tlex[[0xa 0xB 0xfF -0xFf 0x1.8 0x1.8P1 0x1.8p+01 0x.8p-1]]
checkeq(t[1][1], 0xa)
checkeq(t[2][1], 0xB)
checkeq(t[3][1], 0xfF)
checkeq(t[4][1], '-')
checkeq(t[5][1], 0xFf)
-- 5.2 hex floats
checkeq(t[6][1], 1.5) -- 0x1.8
checkeq(t[7][1], 3) -- 0x1.8P1
checkeq(t[8][1], 3) -- 0x1.8p+01
checkeq(t[9][1], 0.25) -- 0x0.8p-1
checkeq(t[10][1], 'eof')


-- Lua 5.2
checkeq(lex'"a\\z \n ."', [[`String<?|K1-9>{a.}`Eof<?|K10>{eof}]])  -- \z
checkeq(lex'"\\z"', [[`String<?|K1-4>{}`Eof<?|K5>{eof}]])  -- \z
checkeq(lex[["\x00\\\xfF\\xAB"]], [[`String<?|K1-17>{\000\\]]..'\255'..[[\\xAB}`Eof<?|K18>{eof}]])

-- Lua 5.2 goto and ::
checkeq(lex'goto a1 ::a1 ::', [[`Keyword<?|K1-4>{goto}`Id<?|K6-7>{a1}]]..
   [[`Keyword<?|K9-10>{::}`Id<?|K11-12>{a1}`Keyword<?|K14-15>{::}`Eof<?|K16>{eof}]])


assert(lex(readfile(arg[0]))) -- lex self

print 'DONE'
