-- @description RPS Toolbar - compatibility entry for existing action registrations
-- @noindex
local root=debug.getinfo(1,'S').source:sub(2):match('^(.*[\\/])')
dofile(root..'RPS Toolbar.lua')
