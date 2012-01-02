-- Shared common parser table. It will be filled by parser.init(),
-- and every other module will be able to call its elements at runtime.
--
-- If the table was directly created in parser.init, a circular
-- dependency would be created: parser.init depends on other modules to fill the table,
-- so other modules can't simultaneously depend on it.

return { }