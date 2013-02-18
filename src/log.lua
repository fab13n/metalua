-------------------------------------------------------------------------------
-- Copyright (c) 2012 Sierra Wireless and others.
-- All rights reserved. This program and the accompanying materials
-- are made available under the terms of the Eclipse Public License v1.0
-- which accompanies this distribution, and is available at
-- http://www.eclipse.org/legal/epl-v10.html
--
-- Contributors:
--     Laurent Barthelemy for Sierra Wireless - initial API and implementation
--     Cuero Bugot        for Sierra Wireless - initial API and implementation
--     Fabien Fleutot     for Sierra Wireless - initial API and implementation
-------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Log library provides logging facilities.
-- The module exposes extension points. It is possible to provide both the
-- custom printing function and the custom log saving function.
-- <br />
-- The module is callable. Thus:
--
--    local log = require 'log'
--    log("MODULE", "INFO", "message")
--
-- calls the @{#log.trace} function.
-- @module log
--

local checks = require 'checks'

local M = { }
log = M

-------------------------------------------------------------------------------
-- Log levels are strings used to filter logs.
-- Levels are to be used both in log filtering configuration (see @{#log.setlevel}) and each time
-- @{#log.trace} function is used to issue a new log.
--
-- Levels are ordered by verbosity/severity level.
--
-- While configuring log filtering, if you set a module log level to 'INFO' level for exemple, you
-- enable all logs *up to* 'INFO', that is to say that logs with 'WARNING' and 'ERROR' severities will
-- be displayed too.
--
-- Built-in values (in order from the least verbose to the most):
--    - 'NONE':    filtering only: when no log is wanted
--    - 'ERROR':   filtering or tracing level
--    - 'WARNING': filtering or tracing level
--    - 'INFO':    filtering or tracing level
--    - 'DETAIL':  filtering or tracing level
--    - 'DEBUG':   filtering or tracing level
--    - 'ALL':     filtering only: when all logs are to be displayed
-- @type levels
--
M.levels = { }

-- Severity name <-> Severity numeric value translation table (internal purpose only)
for k,v in pairs{ 'NONE', 'ERROR', 'WARNING', 'INFO', 'DETAIL', 'DEBUG', 'ALL' } do
    M.levels[k], M.levels[v] = v, k
end

-- -----------------------------------------------------------------------------
-- Default verbosity level.
-- Default value is `"INFO"`.
-- @field [parent=#log] #levels defaultlevel
-- See @{#log} for a list of existing levels.

local defaultlevel = M.levels.INFO

-- -----------------------------------------------------------------------------
-- Per module verbosity levels.
-- @field [parent=#log] modules
-- See @{#levels} to see existing levels.

local modules = { }


-- -----------------------------------------------------------------------------
-- The string format of the timestamp is the same as what os.date takes.
-- Example: "%F %T"
-- #field [parent=#log] #string timestampformat
M.timestampformat = '%T'

-- -----------------------------------------------------------------------------
-- logger functions, will be called if non nil
-- the loggers are called with following params (module, severity, logvalue)
-- -----------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Default logger for instant display.
-- This logger can be replaced by a custom function.
-- It is called only if the log needs to be traced.
--
-- @function [parent=#log] displaylogger
-- @param #string module string identifying the module that issues the log
-- @param severity string representing the log level, see @{log#levels}.
-- @param msg string containing the message to log.
--
M.displaylogger = M.displaylogger or function(_, _, ...)
    if print then print(...) end
end

-------------------------------------------------------------------------------
-- Logger function for log storage.
-- This logger can be replaced by a custom function.
-- There is no default store logger.
-- It is called only if the log needs to be traced (see @{#log.musttrace}) and after the log has been displayed using {displaylogger}.
--
-- @function [parent=#log] storelogger
-- @param module string identifying the module thats issues the log
-- @param severity string representing the log level, see @{log#levels}.
-- @param msg string containing the message to log.
--
M.storelogger = nil

-------------------------------------------------------------------------------
-- Format is a string used to apply specific formating before the log is outputted.
-- Within a format, the following tokens are available (in addition to standard text)
--
--- %l => the actual log (given in 3rd argument when calling log() function)
--- %t => the current date
--- %m => module name
--- %s => log level (severity), see @{log#levels}
--@field [parent=#log] #string format
M.format = nil

local function loggers(...)
    if M.displaylogger then M.displaylogger(...) end
    if M.storelogger then M.storelogger(...) end
end

-------------------------------------------------------------------------------
-- Determines whether a log must be traced depending on its severity and the
-- module issuing the log. This function is mostly useful to protect `log()`
-- calls which involve costly computations
--
-- @usage
--
--    if log.musttrace('SAMPLE', 'DEBUG') then
--        log('SAMPLE', 'DEBUG', "Here are some hard-to-compute info: %s",
--            computeAndReturnExpensiveDebugString())
--    end
--
-- @function [parent=#log] musttrace
-- @param modulename string identifying the module that issues the log.
-- @param severity string representing the log level, see @{log#levels}.
-- @return `nil' if the message of the given severity by the given module should
-- not be printed.
-- @return `true` if the message should be printed.
--
function M.musttrace(module, severity)
    -- get the log level for this module, or default log level
    local lev, sev = modules[module] or defaultlevel, M.levels[severity]
    return not sev or lev >= sev
end


-------------------------------------------------------------------------------
-- Prints out a log entry according to the module and the severity of the log entry.
--
-- This function uses @{#log.format} and @{#log.timestampformat} to create the
-- final message string. It calls @{#log.displaylogger} and @{#log.storelogger}.
--
-- @function [parent=#log] trace
-- @param modulename string identifying the module that issues the log.
-- @param severity string representing the level in @{log#levels}.
-- @param fmt string format that holds the log text the same way as string.format does.
-- @param varargs additional arguments can be provided (as with string.format).
-- @usage trace("MODULE", "INFO", "message=%s", "sometext").
--
function M.trace(module, severity, fmt, ...)
    checks('string', 'string', 'string')
    if not M.musttrace(module, severity) then return end

    local c, s = pcall(string.format, fmt, ...)
    if c then
        local t
        local function sub(p)
            if     p=="l" then return s
            elseif p=="t" then t = t or tostring(os.date(M.timestampformat)) return t
            elseif p=="m" then return module
            elseif p=="s" then return severity
            else return p end
        end
        local out = (M.format or "%t %m-%s: %l"):gsub("%%(%a)", sub)
        loggers(module, severity, out)
    else -- fallback printing when the formating failed. The fallback printing allow to safely print what was given to the log function, without crashing the thread !
        local args = {}
        local t = {...}
        for k = 1, #t do table.insert(args, tostring(k)..":["..tostring(t[k]).."]") end
        --trace(module, severity, "\targs=("..table.concat(args, " ")..")" )
        loggers(module, severity, "Error in the log formating! ("..tostring(s)..") - Fallback to raw printing:" )
        loggers(module, severity, string.format("\tmodule=(%s), severity=(%s), format=(%q), args=(%s)", module, severity, fmt, table.concat(args, " ") ) )
    end
end


-------------------------------------------------------------------------------
-- Sets the log level for a list of module names.
-- If no module name is given, the default log level is affected
-- @function [parent=#log] setlevel
-- @param slevel level as in @{log#levels}
-- @param varargs Optional list of modules names (string) to apply the level to.
-- @return nothing.
--
function M.setlevel(slevel, ...)
    local mods = {...}
    local nlevel = M.levels[slevel] or M.levels['ALL']
    if not M.levels[slevel] then
        M.trace("LOG", "ERROR", "Unknown severity %q, reverting to 'ALL'", tostring(slevel))
    end
    if next(mods) then for _, m in pairs(mods) do M.modules[m] = nlevel end
    else defaultlevel = nlevel end
end

-- -----------------------------------------------------------------------------
-- Make the module callable, so the user can call log(x) instead of log.trace(x)
-- -----------------------------------------------------------------------------
setmetatable(M, {__call = function(_, ...) return M.trace(...) end })

return M
