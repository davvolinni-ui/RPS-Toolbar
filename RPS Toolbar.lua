-- @description RPS Toolbar - ReaBrowse, ReaDrumXT, ReaRoll and ReaSpect launcher
-- @version 0.3.0
-- @author Davvo
-- @link Repository https://github.com/davvolinni-ui/RPS-Toolbar
-- @link Contact and support https://forum.cockos.com/showthread.php?t=311768
-- @about
--   Icon toolbar for ReaBrowse, ReaDrumXT, ReaRoll and ReaSpect.
--   Requires ReaImGui 0.10 and JS_ReaScriptAPI. Install target apps separately.
--   See EULA.md before installing or using. Copyright 2026 Davvo.
-- @changelog Initial public ReaPack release.
-- @provides
--   [nomain] src/*.lua
--   [nomain] EULA.md
local r = reaper
if not r.ImGui_GetBuiltinPath then
  r.MB('Install ReaImGui through ReaPack first.', 'RPS Toolbar', 0)
  return
end
local root = debug.getinfo(1, 'S').source:sub(2):match('^(.*[\\/])')
package.path = root .. '?.lua;' .. r.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local I = require('imgui')('0.10')
local App = require('src.app')
local app = App.new(r, I)
r.atexit(function() app:shutdown() end)
r.defer(function() app:frame() end)
