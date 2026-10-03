local root=debug.getinfo(1,'S').source:sub(2):match('^(.*)[\\/]tools[\\/]')
assert(reaper.GetResourcePath():gsub('\\','/'):lower()==(root..'/tools/isolated'):gsub('\\','/'):lower(),
  'Run this check only in a separate REAPER instance with tools/isolated as its resource profile.')
package.path=root..'/?.lua;'..package.path
local log=assert(io.open(root..'/tools/check.log','w'))
local function report(s) log:write(s..'\n');log:flush() end
local ok,err=xpcall(function()
  for _,file in ipairs({'RPS Toolbar.lua','src/app.lua','src/theme.lua','src/launcher.lua','src/icons.lua'}) do assert(loadfile(root..'/'..file)) end
  report('PASS: all Lua files parse')
  local L=require('src.launcher')
  local found=L.discover(reaper)
  for _,app in ipairs(L.apps) do assert(found[app.name],'Missing action: '..app.name);report('Detected '..app.name..': '..found[app.name].id) end
  local invoked,focused,closed=0,0,0
  local mock={GetExtState=function()return ''end,NamedCommandLookup=function()return 123end,
    GetToggleCommandStateEx=function()return 0 end,Main_OnCommand=function()invoked=invoked+1 end,
    JS_Window_Find=function()return nil end,JS_Window_Show=function()end,
    JS_Window_SetFocus=function()focused=focused+1 end,
    JS_WindowMessage_Post=function()closed=closed+1;return true end}
  assert(L.activate(mock,L.apps[1],found,false));assert(invoked==1)
  mock.JS_Window_Find=function()return 'window'end
  assert(L.activate(mock,L.apps[1],found,false));assert(invoked==1 and focused==1)
  assert(L.activate(mock,L.apps[1],found,true));assert(invoked==1 and closed==1)
  mock.JS_Window_Find=function()return nil end
  assert(not L.activate(mock,L.apps[1],found,true));assert(invoked==1 and closed==1)
  report('PASS: launch, focus without relaunch, close dispatch, stopped close guard')
  local Theme=require('src.theme')
  local state=Theme.new(reaper)
  for _,preset in ipairs({'dark','light','fl'}) do Theme.reset(reaper,state,preset);assert(state.colors.accent) end
  Theme.import(reaper,state,'auto');assert(state.colors.window_bg and state.suggestions.accent)
  report('PASS: presets and REAPER theme import')
  package.path=reaper.ImGui_GetBuiltinPath()..'/?.lua;'..package.path
  local I=require('imgui')('0.10')
  local App=require('src.app')
  local app=App.new(reaper,I)
  app.open=false
  app.settings_open=true
  app:frame();app:shutdown()
  report('PASS: real ReaImGui toolbar and settings frame')
end,debug.traceback)
report(ok and 'COMPLETE PASS' or 'COMPLETE FAIL\n'..tostring(err))
log:close()
reaper.defer(function()reaper.Main_OnCommand(40004,0)end)
