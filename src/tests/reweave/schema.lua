local print, verb, dbg, errr, print_table, printt = make_module_loggers("schema", "SCM")

local CT, GMF,
      game_const
      = import 'game/const.lua'
      {
        'chipTypes',
        'gameModeFlags'
      }

local MTF,
      cast_type
      = import (game_const.abilities)
      {
        'manualTargetFlags',
        'castType'
      }

local AP, abiprob_mapping = import (game_const.abilities.property)
      {
        'mappingInv', -- Note order (inverted goes first)
        'mapping'
      }

local PO, CM, CST, SO,
      abie_const
      = import 'abie/const.lua'
      {
        'propObjects',
        'customMessages',
        'clientStat',
        'storeObjects'
      }

local non_empty_list,
      no_check,
      not_implemented,
      get_children,
      get_children_concat_newline,
      get_children_concat_str,
      get_children_concat_table,
      get_value,
      get_value_quoted,
      get_value_tonumber,
      check_mapping_tonumber,
      get_value_mapped_tonumber_quoted,
      node_children_placeholders_filler,
      check_tonumber
      = import 'jsle/schema/util.lua'
      {
        'non_empty_list',
        'no_check',
        'not_implemented',
        'get_children',
        'get_children_concat_newline',
        'get_children_concat_str',
        'get_children_concat_table',
        'get_value',
        'get_value_quoted',
        'get_value_tonumber',
        'check_mapping_tonumber',
        'get_value_mapped_tonumber_quoted',
        'node_children_placeholders_filler',
        'check_tonumber'
      }

local declare_common = import 'jsle/schema/common.lua' { 'declare_common' }

-- Optional TODOs:

-- TODO: Must be able to fetch back data from lang file to this schema.
-- TODO: Write effect validation with human readable answers. Make it available via jobman's job.
-- TODO: Write auto-conversion function for old abilities (v.1.01->current)
-- TODO: Embed limitations on number of simultanious identical active OT effects
-- TODO: Write checkers for numeric fields
-- TODO: Adapt game/ctrl.lua to abie

local define_schema = function(jsle)
  assert_is_table(jsle)

-- WARNING: Return nil on error from handlers, do not return false -- it is a legitimate value.
-- WARNING: Reordering of schema elements would result in INCOMPATIBLE format change!

  local propwrite_values =
  {
    { ["health"] = [[жизнь]] };
    { ["health_max"] = [[здоровье]] };
    { ["mana1"] = [[красную ману]] };
    { ["mana2"] = [[зелёную ману]] };
    { ["mana3"] = [[синюю ману]] };
    -- Note mana4 is reserved for health
    { ["mana5"] = [[ману 5]] };
    { ["mana6"] = [[ману 6]] };
    { ["mana7"] = [[ману 7]] };
    { ["mana8"] = [[ману 8]] };
    { ["armor"] = [[броню]] };
    { ["fury"] = [[ярость]] };
    { ["block"] = [[блок]] };
    { ["fortune"] = [[удачу]] };
    { ["stun"] = [[оглушение]] };
    { ["armour_piercing"] = [[бронебойность]] };
    { ["agility"] = [[ловкость]] };
    { ["counterattack"] = [[контрудар]] };
    { ["damage"] = [[базовый урон]] };
    { ["damage_min"] = [[минимальный урон]] };
    { ["damage_max"] = [[максимальный урон]] };
    { ["damage_mult"] = [[множитель урона]] };
    { ["vampiric"] = [[вампиризм]] };
    { ["stun_count"] = [[оглушённость]] };
  }

  local propread_values = tiappend(
      tclone(propwrite_values),
      {
        { ["race_id"] = [[расу]] },
        { ["level"] = [[уровень]] },
        { ["grade"] = [[степень]] }, -- TODO: clan_rank?!
        { ["rank"] = [[ранг]] },
        { ["glory"] = [[доблесть]] },
        { ["scalps"] = [[скальпы]] },
        { ["kills"] = [[убийства]] },
      }
    )

  -- TODO: Be more specific. Should be at least "abie-1.03".
  jsle:version("1.03") -- WARNING: Do an ordering cleanup when this changes

  jsle:record "ROOT"
  {
    children =
    {
      [1] = "TARGET_LIST";
      [2] = "IMMEDIATE_EFFECT_LIST";
      [3] = "OVERTIME_EFFECT";
      [4] = { "BOOLEAN", default = 0 }; -- Warning! Do not use BOOLOP_VARIANT, nothing of it would work at this point.
      [5] = { "CUSTOM_OVERTIME_EFFECTS", default = empty_table };
    };
    html = [[<h2>Цели</h2>%C(1)%<h2>Мгновенные эффекты</h2><b>Игнорировать активацию в статистике:</b>%C(4)%<br><br><b>Действия:</b>%C(2)%<h2>Овертайм-эффекты</h2>%C(3)%<hr>%C(5)%]];
    checker = no_check;
    handler = function(self, node)
      return self:effect_from_string(
        node.value[1], -- Target list
        node.value[4], -- Ignore usage stats flag
        self:fill_placeholders(
            node.value,
[[
function(self)
  self:set_custom_ot_effects($(5))

  do
    $(2)
  end

  do
    $(3)
  end
end
]]
          )
       )
    end;
  }

  jsle:list "TARGET_LIST"
  {
    type = "TARGET_VALUE";
    html = [[%LIST(", ")%]];
    checker = non_empty_list;
    handler = function(self, node)
      local result = 0
      for i, v in ipairs(node.value) do
        result = result + v
      end
      return result
    end;
  }

  jsle:enum "TARGET_VALUE"
  {
    values =
    {
      { [MTF.AUTO_ONLY]       = [[неинтерактивно]] };
      { [MTF.SELF_HUMAN]      = [[на себя]] };
      { [MTF.SELF_TEAM_HUMAN] = [[на человека в своей команде]] };
      { [MTF.OPP_HUMAN]       = [[на противника]] };
      { [MTF.OPP_TEAM_HUMAN]  = [[на человека в команде противника]] };
      { [MTF.FIELD_CHIP]      = [[на фишку]] };
    };
    html = [[%VALUE()%]];
    checker = no_check;
    handler = get_value_tonumber;
    numeric_keys = true;
  }

  jsle:list "IMMEDIATE_EFFECT_LIST"
  {
    type = "ACTION_VARIANT";
    html = [[%LE("<i>Нет</i>")%%LNE("<ol><li>")%%LIST("<li>")%%LNE("</ol>")%]];
    checker = no_check;
    handler = get_children_concat_newline;
  }

  jsle:record "OVERTIME_EFFECT"
  {
    children =
    {
      [1] = "OT_EFFECT_TARGET";
      [2] = "NUMOP_VARIANT";
      [3] = "NUMOP_VARIANT";
      [4] = "BOOLOP_VARIANT";
      [5] = "OVERTIME_EFFECT_LIST";
      [6] = "OVERTIME_EFFECT_LIST";
      [7] = "OVERTIME_EFFECT_LIST";
      [8] = "OT_MODIFIER_LIST";
      [9] = "NUMOP_VARIANT"; -- TODO: Must be higher in the list. Straighten numbers on next version change (do not forget to fix texts)
      [10] = "NUMOP_VARIANT"; -- TODO: Must be higher in the list. Straighten numbers on next version change (do not forget to fix texts)
      [11] = { "GAME_MODES", default = GMF.ALL }; -- TODO: Must be higher in the list. Straighten numbers on next version change (do not forget to fix texts)
      [12] = { "BOOLEAN", default = 0 };
    };
    html = [[<br><b>Цель:</b> %C(1)%<br><b>Время жизни:</b> %C(2)% <i>(&ge;255 &mdash; бессрочно)</i><br><b>Период:</b> %C(3)%<br><b>Изначальный кулдаун:</b> %C(10)%<br><b>Сброс в конце боя:</b> %C(4)%<br><b>Остается при снятии всех эффектов вручную:</b> %C(12)%<br><b>Максимальное число одновременно активных эффектов:</b> %C(9)% <i>(0 &mdash; не ограничено)</i><br><b>Игровые режимы:</b> %C(11)%<h3>При изменении набора характеристик</h3>%C(5)%<h3>В конце хода цели</h3>%C(7)%<h3>Временные модификаторы <i>(кроме жизни)</i></h3>%C(8)%]];
    checker = no_check;
    handler = function(self, node)
      if
        node.value[5] ~= "" or
        node.value[6] ~= "" or
        node.value[7] ~= "" or
        node.value[8] ~= "{}"
      then
        -- Spawning OT effect only if have any actions in it.
        return node_children_placeholders_filler
          [[
            self:spawn_overtime_effect(
                $(1),
                $(2),
                $(3),
                $(10),
                $(4),
                $(9),
                function(self)
                  $(5)
                end,
                function(self)
                  $(6)
                end,
                function(self)
                  $(7)
                end,
                $(8),
                $(11),
                $(12)
              )
          ]] (self, node)
      else
        return [[-- No OT effects]]
      end
   end;
  }

  jsle:list "OT_MODIFIER_LIST"
  {
    type = "OT_MODIFIER_VARIANT";
    html = [[%LE("<i>Нет</i>")%%LNE("<ol><li>")%%LIST("<li>")%%LNE("</ol>")%]];
    checker = no_check;
    handler = get_children_concat_table;
  }

  jsle:variant "OT_MODIFIER_VARIANT"
  {
    values =
    {
      { ["MOD_SET"]  = [[Установить]] };
      { ["MOD_INC"]  = [[Увеличить]] };
      { ["MOD_DEC"]  = [[Уменьшить]] };
      { ["MOD_MULT"] = [[Умножить]] };
    };
    label = [["<i title=\"Модификатор\">M</i>"]];
    html = [[%VALUE()%]];
    checker = no_check;
    handler = get_value;
  }

  jsle:record "MOD_SET"
  {
    children =
    {
      [1] = "PROPWRITE";
      [2] = "NUMOP_VARIANT";
    };
    html = [[Установить %C(1)% цели в %C(2)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[{ name = $(1), fn = function(self, value) return ($(2)) end; }]];
  }

  jsle:record "MOD_INC"
  {
    children =
    {
      [1] = "PROPWRITE";
      [2] = "NUMOP_VARIANT";
    };
    html = [[Увеличить %C(1)% цели на %C(2)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[{ name = $(1), fn = function(self, value) return value + ($(2)) end; }]];
  }

  jsle:record "MOD_DEC"
  {
    children =
    {
      [1] = "PROPWRITE";
      [2] = "NUMOP_VARIANT";
    };
    html = [[Уменьшить %C(1)% цели на %C(2)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[{ name = $(1), fn = function(self, value) return value - ($(2)) end; }]];
  }

  jsle:record "MOD_MULT"
  {
    children =
    {
      [1] = "PROPWRITE";
      [2] = "NUMOP_VARIANT";
    };
    html = [[Умножить %C(1)% цели на %C(2)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[{ name = $(1), fn = function(self, value) return value * ($(2)) end; }]];
  }

  jsle:list "OVERTIME_EFFECT_LIST"
  {
    type = "ACTION_VARIANT";
    html = [[%LE("<i>Нет</i>")%%LNE("<ol><li>")%%LIST("<li>")%%LNE("</ol>")%]];
    checker = no_check;
    handler = get_children_concat_newline;
  }

  jsle:list "ACTION_LIST"
  {
    type = "ACTION_VARIANT";
    html = [[<ol><li>%LIST("<li>")%</ol>]];
    checker = non_empty_list;
    handler = get_children_concat_newline;
  }

  jsle:variant "ACTION_VARIANT"
  {
    values =
    {
      { ["ACT_SET"]               = [[Установить]] };
      { ["ACT_INC"]               = [[Увеличить]] };
      { ["ACT_DEC"]               = [[Уменьшить]] };
      { ["ACT_MULT"]              = [[Умножить]] };
      { ["ACT_DIRECTSET"]         = [[Установить напрямую]] };
      { ["ACT_DIRECTINC"]         = [[Увеличить напрямую]] };
      { ["ACT_DIRECTDEC"]         = [[Уменьшить напрямую]] };
      { ["ACT_DIRECTMULT"]        = [[Умножить напрямую]] };
      { ["ACT_FLDEXPLODE"]        = [[Взорвать фишки]] };
      { ["ACT_FLDLEVELDELTA"]     = [[Поднять уровень фишек]] };
      { ["ACT_FLDCOLLECT_COORDS"] = [[Собрать фишки по координатам]] };
      { ["ACT_FLDREPLACE_COORDS"] = [[Заменить фишки по координатам]] };
      { ["ACT_ONEMOREACTION"]     = [[Дать ещё одно действие]] };
      { ["ACT_KEEPTIMEOUT"]       = [[Не сбрасывать таймер]] };
      { ["ACT_SETVAR"]            = [[Запомнить]] };
      { ["ACT_SETOBJVAR_LOCAL"]   = [[Запомнить в объекте локально]] };
      { ["ACT_SETOBJVAR_GLOBAL"]  = [[Запомнить в объекте глобально]] };
      { ["ACT_SETOBJVAR_OT"]      = [[Запомнить в текущем овертайме]] };
      { ["ACT_DOIF"]              = [[Если]] };
      { ["ACT_DOIFELSE"]          = [[Если ... иначе]] };
      { ["ACT_PLAYABIANIM"]       = [[Играть эффект абилки]] };
      { ["ACT_SENDCUSTOMMSG"]     = [[Отправить данные клиентам]] };
      { ["ACT_INCSTAT"]           = [[Увеличить статистику клиента]] };
      { ["ACT_ACTIVATEOT"]        = [[Активировать ОТ-эффект]] };
      { ["ACT_REMOVE_OVERTIMES"]  = [[Снять ОТ-эффекты]] };
      -- Keep these below --
      { ["ACT_FLDREPLACE"]        = [[Заменить фишки <b><i>(устарело)</i></b>]] };
      { ["ACT_CRASH_GAME"]        = [[УРОНИТЬ игру <b><i>(только для тестов)</i></b>]] };
      -- { ["PLAINLUA"]           = [[Lua]] };
    };
    label = [["<i title=\"Действие\">A</i>"]];
    html = [[%VALUE()%]];
    checker = no_check;
    handler = get_value;
  }

  declare_common(jsle, "ACT_DOIF", "ACT_DOIFELSE")

  jsle:record "ACT_SET"
  {
    children =
    {
      [1] = "PROPPATH_WRITE";
      [2] = "NUMOP_VARIANT";
    };
    html = [[Установить %C(1)% в %C(2)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:propset($(1), $(2))]];
  }

  jsle:record "ACT_INC"
  {
    children =
    {
      [1] = "PROPPATH_WRITE";
      [2] = "NUMOP_VARIANT";
    };
    html = [[Увеличить %C(1)% на %C(2)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:propinc($(1), $(2))]];
  }

  jsle:record "ACT_DEC"
  {
    children =
    {
      [1] = "PROPPATH_WRITE";
      [2] = "NUMOP_VARIANT";
    };
    html = [[Уменьшить %C(1)% на %C(2)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:propdec($(1), $(2))]];
  }

  jsle:record "ACT_MULT"
  {
    children =
    {
      [1] = "PROPPATH_WRITE";
      [2] = "NUMOP_VARIANT";
    };
    html = [[Умножить %C(1)% на %C(2)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:propmult($(1), $(2))]];
  }

  jsle:record "ACT_DIRECTSET"
  {
    children =
    {
      [1] = "PROPPATH_WRITE";
      [2] = "NUMOP_VARIANT";
    };
    html = [[Установить напрямую %C(1)% в %C(2)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:propset_direct($(1), $(2))]];
  }

  jsle:record "ACT_DIRECTINC"
  {
    children =
    {
      [1] = "PROPPATH_WRITE";
      [2] = "NUMOP_VARIANT";
    };
    html = [[Увеличить напрямую %C(1)% на %C(2)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:propinc_direct($(1), $(2))]];
  }

  jsle:record "ACT_DIRECTDEC"
  {
    children =
    {
      [1] = "PROPPATH_WRITE";
      [2] = "NUMOP_VARIANT";
    };
    html = [[Уменьшить напрямую %C(1)% на %C(2)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:propdec_direct($(1), $(2))]];
  }

  jsle:record "ACT_DIRECTMULT"
  {
    children =
    {
      [1] = "PROPPATH_WRITE";
      [2] = "NUMOP_VARIANT";
    };
    html = [[Умножить напрямую %C(1)% на %C(2)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:propmult_direct($(1), $(2))]];
  }

  jsle:record "ACT_FLDEXPLODE"
  {
    children =
    {
      [1] = "NUMOP_VARIANT";
      [2] = "CHIPCOORD";
    };
    html = [[Взорвать бомбу радиусом %C(1)% в координатах %C(2)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:fld_explode($(1), $(2))]];
  }

  jsle:record "ACT_FLDREPLACE"
  {
    children =
    {
      [1] = "CHIPTYPE";
      [2] = "NUMOP_VARIANT";
      [3] = "CHIPTYPE";
      [4] = "NUMOP_VARIANT";
    };
    html = [[Заменить %C(1)% уровня %C(2)% на %C(3)% уровня %C(4)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:fld_replace($(1), $(2), $(3), $(4))]];
    doc = [[Deprecated, use other replace actions]];
  }

  jsle:record "ACT_FLDLEVELDELTA"
  {
    children =
    {
      [1] = "NUMOP_VARIANT";
      [2] = "CHIPTYPE";
      [3] = "NUMOP_VARIANT";
      [4] = "NUMOP_VARIANT";
    };
    html = [[Поднять уровень %C(2)% на %C(1)% в диапазоне от %C(3)% до %C(4)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:fld_level_delta($(1), $(2), $(3), $(4))]];
  }

  jsle:record "ACT_FLDCOLLECT_COORDS"
  {
    children =
    {
      [1] = "COORDLISTOP_VARIANT";
    };
    html = [[Собрать %C(1)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:fld_collect_coords($(1))]];
  }

  jsle:record "ACT_FLDREPLACE_COORDS"
  {
    children =
    {
      [1] = "COORDLISTOP_VARIANT";
      [2] = "CHIPTYPE_LIST";
      [3] = "NUMOP_VARIANT";
    };
    html = [[Заменить %C(1)% на %C(2)% уровня %C(3)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:fld_replace_coords($(1),$(2),$(3))]];
  }

  jsle:literal "ACT_ONEMOREACTION"
  {
    html = [[Дать ещё одно действие <i>(только мгновенный эффект)</i>]];
    checker = no_check;
    handler = invariant [[self:one_more_action()]];
  }

  jsle:literal "ACT_KEEPTIMEOUT"
  {
    html = [[Не сбрасывать таймер <i>(только мгновенный эффект)</i>]];
    checker = no_check;
    handler = invariant [[self:keep_timeout()]];
  }

  jsle:record "ACT_SETVAR"
  {
    children =
    {
      [1] = "NUMOP_VARIANT";
      [2] = "NUMOP_VARIANT";
    };
    html = [[Запомнить в №%C(1)% значение %C(2)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:setvar($(1), $(2))]];
  }

  jsle:enum "OT_EFFECT_TARGET"
  {
    values =
    {
      { [PO.SELF] = [[на себя]] };
      { [PO.OPP] = [[на противника]] };
      { [PO.TARGET] = [[на цель]] };
    };
    html = [[%VALUE()%]];
    checker = no_check;
    handler = get_value_quoted;
  }

  jsle:variant "BOOLOP_VARIANT"
  {
    values =
    {
      { ["BOOLEAN"] = [[Логическое значение]] };
      { ["BOOLOP_LT"] = [[&lt;]] };
      { ["BOOLOP_LTE"] = [[&le;]] };
      { ["BOOLOP_GT"] = [[&gt;]] };
      { ["BOOLOP_GTE"] = [[&ge;]] };
      { ["BOOLOP_EQ"] = [[==]] };
      { ["BOOLOP_NEQ"] = [[!=]] };
      { ["BOOLOP_AND_MANY"] = [[И (Список)]] };
      { ["BOOLOP_OR_MANY"] = [[ИЛИ (Список)]] };
      { ["BOOLOP_NOT"] = [[НЕ]] };
      { ["BOOLOP_HAVEMEDAL"] = [[МЕДАЛЬ]] };
      { ["BOOLOP_ISACTIVE"] = [[Изменения инициированы целью овертайм-эффекта]] };
      { ["BOOLOP_IS_GAME_IN_MODE"] = [[Текущий игровой режим]] };
      -- Deprecated, keep below --
      { ["BOOLOP_AND"] = [[И]] };
      { ["BOOLOP_OR"] = [[ИЛИ]] };
      --{ ["PLAINLUA"] = [[Lua]] };
    };
    label = [["<i title=\"Логическая операция\">B</i>"]];
    html = [[%VALUE()%]];
    checker = no_check;
    handler = get_value;
  }

  jsle:record "BOOLOP_HAVEMEDAL"
  {
    children =
    {
      [1] = "PROPOBJECT";
      [2] = "NUMOP_VARIANT";
    };
    html = [[есть медаль №%C(2)% %C(1)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:have_medal($(1), $(2))]];
  }

  jsle:literal "BOOLOP_ISACTIVE"
  {
    html = [[изменения инициированы целью овертайм-эффекта]];
    checker = no_check; -- Only for on_changeset event.
    handler = invariant [[self:is_overtime_target_active()]];
  }

  declare_common(
      jsle,
      "BOOLOP_LT",
      "BOOLOP_LTE",
      "BOOLOP_GT",
      "BOOLOP_GTE",
      "BOOLOP_EQ",
      "BOOLOP_NEQ",
      "BOOLOP_AND",
      "BOOLOP_OR",
      "BOOLOP_NOT"
    )

  jsle:variant "NUMOP_VARIANT"
  {
    values =
    {
      { ["NUMBER"] = [[Число]] };
      { ["NUMOP_ADD_MANY"] = [[+ (Список)]] };
      { ["NUMOP_DEC_MANY"] = [[- (Список)]] };
      { ["NUMOP_MUL_MANY"] = [[* (Список)]] };
      { ["NUMOP_DIV_MANY"] = [[/ (Список)]] };
      { ["NUMOP_POV"] = [[POW]] }; -- TODO: POW, not POV! Fix by search and replace
      { ["NUMOP_MOD"] = [[MOD]] };
      { ["NUMOP_MIN"] = [[MIN]] };
      { ["NUMOP_MAX"] = [[MAX]] };
      { ["NUMOP_UNM"] = [[Знак]] };
      { ["NUMOP_GET"] = [[Характеристика]] };
      { ["NUMOP_GET_RAW"] = [[Базовое значение характеристики]] };
      { ["NUMOP_GET_ABIPROP"] = [[Характеристика абилки]] };
      { ["NUMOP_PERCENT_ROLL"] = [[Cлучайный процент]] };
      { ["NUMOP_TEAMSIZE"] = [[Размер команды]] };
      { ["NUMOP_GETVAR"] = [[Вспомнить]] };
      { ["NUMOP_GETOBJVAR_LOCAL"]  = [[Вспомнить из объекта локально]] };
      { ["NUMOP_GETOBJVAR_GLOBAL"] = [[Вспомнить из объекта глобально]] };
      { ["NUMOP_GETOBJVAR_OT"]     = [[Вспомнить из текущего овертайма]] };
      { ["NUMOP_OTLIFETIMELEFT"] = [[Оставшееся время жизни]] };
      { ["NUMOP_OTLIFETIMETOTAL"] = [[Общее время жизни]] };
      { ["NUMOP_FLDGETQUANTITYOFCHIPS"] = [[Число фишек по цвету и уровню]] };
      { ["NUMOP_TARGETX"] = [[Координата X выбранной фишки]] };
      { ["NUMOP_TARGETY"] = [[Координата Y выбранной фишки]] };
      { ["NUMOP_OTEFFECTCOUNT"] = [[Число активных овертайм-эффектов]] };
      { ["NUMOP_IFF"] = [[Если]] };
      { ["NUMOP_GETUID"] = [[Идентификатор игрока]] };
      -- Keep these below --
      { ["NUMOP_FLDCOUNTCHIPS"] = [[Число фишек на поле <b><i>(устарело)</i></b>]] };
      { ["NUMOP_ADD"] = [[+]] };
      { ["NUMOP_DEC"] = [[-]] };
      { ["NUMOP_MUL"] = [[*]] };
      { ["NUMOP_DIV"] = [[/]] };
      { ["NUMOP_CRASH_GAME"] = [[УРОНИТЬ игру <b><i>(только для тестов)</i></b>]] };
      --{ ["PLAINLUA"] = [[Lua]] };
    };
    label = [["<i title=\"Численная операция\">I</i>"]];
    html = [[%VALUE()%]];
    checker = no_check;
    handler = get_value;
  }

  declare_common(
      jsle,
      "NUMOP_ADD",
      "NUMOP_DEC",
      "NUMOP_MUL",
      "NUMOP_DIV",
      "NUMOP_POV",
      "NUMOP_MOD",
      "NUMOP_MIN",
      "NUMOP_MAX",
      "NUMOP_UNM"
    )

  jsle:record "NUMOP_GET"
  {
    children =
    {
      [1] = "PROPPATH_READ";
    };
    html = [[%C(1)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:propget($(1), false)]];
  }

  declare_common(jsle, "NUMOP_PERCENT_ROLL")

  jsle:record "NUMOP_FLDCOUNTCHIPS"
  {
    children =
    {
      [1] = "CHIPTYPE";
      [2] = "BOOLOP_VARIANT";
    };
    html = [[число %C(1)% на поле (учитывая уровни: %C(2)%)]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:fld_count_chips($(1), $(2))]];
    doc = [[Deprecated, use other chip count operations]];
  }

  jsle:record "NUMOP_TEAMSIZE"
  {
    children =
    {
      [1] = "PROPOBJECT";
    };
    html = [[размер команды %C(1)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:team_size($(1))]];
  }

  jsle:record "NUMOP_GETVAR"
  {
    children =
    {
      [1] = "NUMOP_VARIANT";
    };
    html = [[вспомнить из №%C(1)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:getvar($(1))]];
  }

  jsle:literal "NUMOP_OTLIFETIMELEFT"
  {
    html = [[оставшееся время жизни]];
    checker = no_check;
    handler = invariant [[self:ot_lifetime_left()]];
  }

  jsle:literal "NUMOP_OTLIFETIMETOTAL"
  {
    html = [[общее время жизни]];
    checker = no_check;
    handler = invariant [[self:ot_lifetime_total()]];
  }

  jsle:literal "NUMOP_TARGETX"
  {
    html = [[X выбранной фишки]];
    checker = no_check;
    handler = invariant [[self:target_x()]];
  }

  jsle:literal "NUMOP_TARGETY"
  {
    html = [[Y выбранной фишки]];
    checker = no_check;
    handler = invariant [[self:target_y()]];
  }

  jsle:record "PROPPATH_WRITE"
  {
    children =
    {
      [1] = "PROPOBJECT";
      [2] = "PROPWRITE";
    };
    html = [[%C(2)% %C(1)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:make_proppath($(1), $(2))]];
  }

  jsle:record "PROPPATH_READ"
  {
    children =
    {
      [1] = "PROPOBJECT";
      [2] = "PROPREAD";
    };
    html = [[%C(2)% %C(1)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:make_proppath($(1), $(2))]];
  }

  jsle:enum "PROPOBJECT"
  {
    values =
    {
      { [PO.SELF] = [[у себя]] };
      { [PO.OPP] = [[у противника]] };
      { [PO.TARGET] = [[у цели]] };
      { [PO.OWN_CHANGESET] = [[в своём наборе изменений]] };
      { [PO.OPP_CHANGESET] = [[в наборе изменений противника]] };
    };
    html = [[%VALUE()%]];
    checker = no_check; -- Check value is valid for current action list subtype
    handler = get_value_quoted;
  }

  jsle:enum "PROPWRITE"
  {
    values = propwrite_values;
    html = [[%VALUE()%]];
    checker = no_check;
    handler = get_value_quoted;
  }

  jsle:enum "PROPREAD"
  {
    values = propread_values;
    html = [[%VALUE()%]];
    checker = no_check;
    handler = get_value_quoted;
  }

  jsle:enum "CHIPTYPE"
  {
    values =
    {
      { [CT.EMERALD] = [[зелёных фишек]] };
      { [CT.RUBY] = [[красных фишек]] };
      { [CT.AQUA] = [[синих фишек]] };
      { [CT.DMG] = [[черепов]] };
      { [CT.CHIP5] = [[фишек-5]] };
      { [CT.CHIP6] = [[фишек-6]] };
      { [CT.CHIP7] = [[фишек-7]] };
      { [CT.CHIP8] = [[фишек-8]] };
      { [CT.EMPTY] = [[пустых фишек]] };
    };
    html = [[%VALUE()%]];
    checker = no_check;
    handler = get_value_tonumber;
    numeric_keys = true;
  }

  jsle:edit "NUMBER"
  {
    size = 4;
    numeric = true;
    checker = check_tonumber;
    handler = get_value_tonumber;
  }

  declare_common(
      jsle,
      "BOOLEAN",
      "PLAINLUA"
    )

  jsle:list "COORDLISTOP_STD"
  {
    type = "CHIPCOORD";
    html = [[фишки с координатами %LIST(", ")%]];
    checker = non_empty_list;
    handler = get_children_concat_table;
  }

  jsle:record "CHIPCOORD"
  {
    children =
    {
      [1] = "NUMOP_VARIANT";
      [2] = "NUMOP_VARIANT";
    };
    html = [[(x: %C(1)%, y: %C(2)%)]];
    checker = no_check;
    handler = node_children_placeholders_filler [[{x=$(1), y=$(2)}]];
  }

  -- TODO: UNUSED. Remove or use.
  jsle:record "BOOLOP_SELECTEDTARGET"
  {
    children =
    {
      [1] = "TARGET_VALUE";
    };
    html = [[выбрана цель %C(1)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:is_target_selected($(1))]];
    doc = [[Currently not used]];
  }

  jsle:record "NUMOP_OTEFFECTCOUNT"
  {
    children =
    {
      [1] = "PROPOBJECT";
      [2] = "NUMOP_VARIANT";
      [3] = "NUMOP_VARIANT";
    };
    html = [[число овертайм-эффектов абилки ID %C(2)% <i>(0 &mdash; этот эффект)</i> № эффекта %C(3)% <i>(0 &mdash; по умолчанию)</i>, активных %C(1)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:active_ot_effect_count($(1), $(2), $(3))]];
  }

  declare_common(jsle, "NUMOP_IFF")

  jsle:record "NUMOP_GET_RAW"
  {
    children =
    {
      [1] = "PROPPATH_READ";
    };
    html = [[базовое значение %C(1)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:propget($(1), true)]];
  }

  -- TODO: Get rid of non-list versions!

  declare_common(
      jsle,
      "NUMOP_ADD_MANY",
      "NUMOP_DEC_MANY",
      "NUMOP_MUL_MANY",
      "NUMOP_DIV_MANY"
    )

  declare_common(
      jsle,
      "BOOLOP_AND_MANY",
      "BOOLOP_OR_MANY"
    )

  jsle:list "CHIPTYPE_LIST"
  {
    type = "CHIPTYPE";
    html = [[%LIST(", ")%]];
    checker = non_empty_list;
    handler = get_children_concat_table;
  }

  jsle:record "NUMOP_GET_ABIPROP"
  {
    children =
    {
      [1] = "ABIPROP_NAME";
    };
    html = [[%C(1)% абилки]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:abipropget($(1))]];
  }

  jsle:enum "ABIPROP_NAME"
  {
    values =
    {
      { [AP.prob] = [[вероятность активации]] };
    };
    html = [[%VALUE()%]];
    checker = check_mapping_tonumber;
    handler = get_value_mapped_tonumber_quoted(abiprob_mapping);
  }

  jsle:record "ACT_SENDCUSTOMMSG"
  {
    children =
    {
      [1] = "NUMOP_LIST";
    };
    html = [[Отправить участникам боя данные: %C(1)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:send_custom_msg($(1))]];
  }

  declare_common(jsle, "NUMOP_LIST")

  jsle:record "ACT_PLAYABIANIM"
  {
    children =
    {
      [1] = "NUMOP_VARIANT";
    };
    html = [[Играть эффект абилки ID: %C(1)%]];
    checker = no_check;
    -- Hack. Should format be hardcoded here or below?
    handler = node_children_placeholders_filler(
        [[self:send_custom_msg({]]..assert_is_number(CM.PLAYABIANIM)
        ..[[, $(1), self:get_uid("]]..PO.SELF..[[")})]]
      );
  }

  jsle:variant "COORDLISTOP_VARIANT"
  {
    values =
    {
      { ["COORDLISTOP_STD"] = [[Обычный список коордтнат]] };
      { ["COORDLISTOP_GETLEVEL"] = [[Фишки цвета <i>цв1</i> с уровнями от <i>ур1</i> до <i>ур2</i>]] };
    };
    label = [["<i title=\"Список координат\">C</i>"]];
    html = [[%VALUE()%]];
    checker = no_check;
    handler = get_value;
  }

  jsle:record "COORDLISTOP_GETLEVEL"
  {
    children =
    {
      [1] = "CHIPTYPE";
      [2] = "NUMOP_VARIANT";
      [3] = "NUMOP_VARIANT";
    };
    html = [[%C(1)% с уровнями от %C(2)% до %C(3)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:fld_get_coordlist_from_levels_and_type($(1), $(2), $(3))]];
  }

  jsle:record "NUMOP_FLDGETQUANTITYOFCHIPS"
  {
    children =
    {
      [1] = "CHIPTYPE";
      [2] = "NUMOP_VARIANT";
      [3] = "NUMOP_VARIANT";
      [4] = "BOOLOP_VARIANT";
    };
    html = [[число %C(1)% на поле уровней с %C(2)% до %C(3)% (учитывая уровень в счетчике: %C(4)%)]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:fld_get_quantity_of_chips($(1), $(2), $(3), $(4))]];
  }

  jsle:enum "CLIENTSTAT"
  {
    values =
    {
      -- TODO: Support commented out variants?
      { [CST.SPELL_USE]        = [[исп. спеллов]] };
      --{ [CST.SPELL_FRAG]       = [[фраги от спеллов]] };
      { [CST.CONSUMABLE_USE]   = [[исп. расходников]] };
      --{ [CST.CONSUMABLE_FRAG]  = [[фраги от расходников]] };
      { [CST.AUTOABILITY_USE]  = [[исп. автоабилок]] };
      --{ [CST.AUTOABILITY_FRAG] = [[фраги от автоабилок]] };
      --{ [CST.RATING]           = [[рейтинг]] };
      --{ [CST.CUSTOM]           = [[пользовательская]] };
    };
    html = [[%VALUE()%]];
    checker = check_mapping_tonumber;
    handler = get_value_tonumber;
  }

  jsle:record "ACT_INCSTAT"
  {
    children =
    {
      [1] = "PROPOBJECT";
      [2] = "CLIENTSTAT";
      [3] = "NUMOP_VARIANT";
      [4] = "NUMOP_VARIANT";
    };
    html = [[Увеличить %C(1)% статистику &laquo;%C(2)%&raquo; эффекта №%C(3)% <i>(0 &mdash; текущий)</i> на %C(4)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:inc_client_stat($(1), $(2), $(3), $(4))]];
  }

  jsle:record "ACT_ACTIVATEOT"
  {
    children =
    {
      [1] = "NUMOP_VARIANT";
      [2] = { "KEYVALUE_LIST", default = empty_table };
    };
    html = [[Активировать ОТ-эффект №%C(1)%, передав %C(2)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:activate_custom_ot_effect($(1),$(2))]];
  }

  jsle:list "CUSTOM_OVERTIME_EFFECTS"
  {
    type = "OVERTIME_EFFECT";
    html = [[%LE("<i>(Нет дополнительных ОТ-эффектов)</i>")%%LNE("<ol><li><h2>Дополнительный OT-эффект</h2>")%%LIST("<hr><li><h2>Дополнительный OT-эффект</h2>")%%LNE("</ol>")%]];
    checker = no_check;
    handler = function(self, node)
      local buf = {[[{]]}
      local _ = function(v) buf[#buf + 1] = tostring(v) end
      for i, child in ipairs(node.value) do
        _ [[
[]] _(i) _[[] = function(self)
]] _(child) _ [[
end;
]]
      end
      _ [[}]]
      return table.concat(buf)
    end;
  }

  jsle:record "NUMOP_GETUID"
  {
    children =
    {
      [1] = "PROPOBJECT";
    };
    html = [[идентификатор игрока %C(1)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:get_uid($(1))]];
  }

  jsle:enum "STORE_OBJ"
  {
    values =
    {
      { [SO.CLIENT_SELF]   = [[на себе]] };
      { [SO.CLIENT_OPP]    = [[на противнике]] };
      { [SO.CLIENT_TARGET] = [[на цели]] };
      { [SO.FIGHT]         = [[на бою]] };
      { [SO.GAME]          = [[на игре]] };
    };
    html = [[%VALUE()%]];
    checker = no_check;
    handler = get_value_tonumber;
  }

  jsle:record "ACT_SETOBJVAR_LOCAL"
  {
    children =
    {
      [1] = "STORE_OBJ";
      [2] = "NUMOP_VARIANT";
      [3] = "NUMOP_VARIANT";
    };
    html = [[Запомнить в объекте &laquo;%C(1)%&raquo; в слот №%C(2)% <b>приватное</b> значение %C(3)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:setobjvar_local($(1), $(2), $(3))]];
  }

  jsle:record "NUMOP_GETOBJVAR_LOCAL"
  {
    children =
    {
      [1] = "STORE_OBJ";
      [2] = "NUMOP_VARIANT";
    };
    html = [[вспомнить из объекта &laquo;%C(1)%&raquo; из слота №%C(2)% <b>приватное</b> значение]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:getobjvar_local($(1), $(2))]];
  }

  jsle:record "ACT_SETOBJVAR_GLOBAL"
  {
    children =
    {
      [1] = "STORE_OBJ";
      [2] = "NUMOP_VARIANT";
      [3] = "NUMOP_VARIANT";
    };
    html = [[Запомнить в объекте %C(1)% в слот №%C(2)% <b>публичное</b> значение %C(3)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:setobjvar_global($(1), $(2), $(3))]];
  }

  jsle:record "NUMOP_GETOBJVAR_GLOBAL"
  {
    children =
    {
      [1] = "STORE_OBJ";
      [2] = "NUMOP_VARIANT";
    };
    html = [[вспомнить из объекта %C(1)% из слота №%C(2)% <b>публичное</b> значение]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:getobjvar_global($(1), $(2))]];
  }

  jsle:record "ACT_REMOVE_OVERTIMES"
  {
    children =
    {
      [1] = "OT_EFFECT_TARGET";
    };
    html = [[Снять все эффекты, наложенные %C(1)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:remove_overtime_effects($(1))]];
  }

  jsle:enum "GAME_MODES"
  {
    values =
    {
      { [GMF.ALL] = [[любой]] };
      { [GMF.DUEL] = [[дуэль]] };
      { [GMF.SINGLE] = [[одиночная игра]] };
    };
    html = [[%VALUE()%]];
    checker = no_check;
    handler = get_value_tonumber;
  }

  jsle:record "BOOLOP_IS_GAME_IN_MODE"
  {
    children =
    {
      [1] = "GAME_MODES";
    };
    html = [[игровой режим &laquo;%C(1)%&raquo; включён]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:is_game_in_mode($(1))]];
  }

  jsle:record "ACT_SETOBJVAR_OT"
  {
    children =
    {
      [1] = "NUMOP_VARIANT";
      [2] = "NUMOP_VARIANT";
    };
    html = [[Запомнить в текущем овертайме в слот №%C(1)% значение %C(2)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:setobjvar_ot($(1), $(2))]];
  }

  jsle:record "NUMOP_GETOBJVAR_OT"
  {
    children =
    {
      [1] = "NUMOP_VARIANT";
    };
    html = [[Вспомнить из текущего овертайма из слота №%C(1)%]];
    checker = no_check;
    handler = node_children_placeholders_filler [[self:getobjvar_ot($(1))]];
  }

  declare_common(
      jsle,
      "KEYVALUE_LIST",
      "KEYVALUE"
    )

  jsle:literal "ACT_CRASH_GAME"
  {
    html = [[<span style="color:red"><b>УРОНИТЬ</b> игру (только для теста)<span>]];
    checker = function(self, node)
      if common_get_config().crashers_enabled == true then
        errr("WARNING: ACT_CRASH_GAME CRASHER IS ON")
        return true
      end

      errr("DETECTED ATTEMPT TO UPLOAD CRASHERS (SCHEMA)")
      return false, "crashers are disabled in config"
    end;
    handler = invariant [[self:crash_game()]];
  }

  jsle:literal "NUMOP_CRASH_GAME"
  {
    html = [[<span style="color:red"><b>УРОНИТЬ</b> игру (только для теста)<span>]];
    checker = function(self, node)
      if common_get_config().crashers_enabled == true then
        errr("WARNING: NUMOP_CRASH_GAME CRASHER IS ON")
        return true
      end

      errr("DETECTED ATTEMPT TO UPLOAD CRASHERS (SCHEMA)")
      return false, "crashers are disabled in config"
    end;
    handler = invariant [[(self:crash_game() or 0)]];
  }

  return jsle
end

return
{
  define_schema = define_schema;
}
