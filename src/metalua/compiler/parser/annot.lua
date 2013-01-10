local gg    = require 'metalua.grammar.generator'
local misc  = require 'metalua.compiler.parser.misc'
local mlp   = require 'metalua.compiler.parser.common'
local lexer = require 'metalua.compiler.parser.lexer'
local M     = { }

lexer.lexer :add '->'

function M.tid(lx)
    local w = lx :next()
    local t = w.tag
    if t=='Keyword' and w[1] :match '^[%a_][%w_]*$' or w.tag=='Id' then
        return {tag='TId'; lineinfo=w.lineinfo; w[1]}
    else error 'tid expected' end
end

local function expr(...) return mlp.expr(...) end

local function te(...) return M.te(...) end

local field_types = { var='TVar'; const='TConst';
                      currently='TCurrently'; field='TField' }

function M.tf(lx)
    local w = M.tid(lx)[1]
    local tag = field_types[w]
    if not tag then error ('Invalid field type '..w)
    elseif tag=='TField' then return {tag='TField'} else
        local te = M.te(lx)
        return {tag=tag; te}
    end
end

local tebar_content = gg.list{
    name        = 'tebar content',
    primary     = te,
    separators  = { ",", ";" },
    terminators = ")" }

M.tebar = gg.multisequence{ 
    name = 'annot.tebar',
    --{ '*', builder = 'TDynbar' }, -- maybe not user-available
    { '(', tebar_content, ')', 
      builder = function(x) return x[1] end },
    { te }
}

M.te = gg.multisequence{
    name = 'annot.te',
    { M.tid, builder=function(x) return x[1] end },
    { '*', builder = 'TDyn' },
    { "[",
      M.tf,
      gg.onkeyword{ keywords = {";", ","},
                    primary  = gg.list{
                        primary = gg.sequence{
                            expr, "=", M.tf,
                            builder = 'TPair'
                        },
                        separators = { ",", ";" },
                        terminators = "]" } },
      "]",
      -- TODO: get the 0
      builder = function(x)
                    local other, fields = unpack(x)
                    fields = fields or { }
                    return { tag='TTable', other, fields, false }
                end
    }, -- "[ ... ]"
    { '(', tebar_content, ')', '->', '(', tebar_content, ')',
      builder = function(x)
                    local p, r = unpack(x)
                    return {tag='TFunction', p, r }
                end } }


M.ts = gg.multisequence{
    name = 'annot.ts',
    { 'return', tebar_content, builder='TReturn' },
    { M.tid, builder = function(x)
                           if x[1][1]=='pass' then return {tag='TPass'}
                           else error "Bad statement type" end
                       end } }


-- TODO: add parsers for statements:
-- #return tebar
-- #alias = te
-- #ell = tf

M.stat_annot = gg.sequence{
    gg.list{ primary=M.tid, separators='.' },
    '=',
    M.annot,
    builder = 'Annot' }

M.annot_id = gg.sequence{
    misc.id,
    gg.onkeyword{ "#", M.tf },
    builder = function(x)
                  local id, annot = unpack(x)
                  if annot then return { tag='Annot', id, annot }
                  else return id end
              end }

-- split a list of "foo" and "`Annot{foo, annot}" into a list of "foo"
-- and a list of "annot".
-- No annot list is returned if none of the elements were annotated.
function M.split(lst)
    local x, a, some = { }, { }, false
    for i, p in ipairs(lst) do
        if p.tag=='Annot' then
            some, x[i], a[i] = true, unpack(p)
        else x[i] = p end
    end
    if some then return x, a else return lst end
end

return M