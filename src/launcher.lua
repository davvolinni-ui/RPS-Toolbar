-- @noindex
local M = {}
M.apps = {
  {name='ReaBrowse', file='ReaBrowse.lua', icon='browse'},
  {name='ReaDrumXT', file='ReaDrum.lua', icon='drum'},
  {name='ReaRoll', file='ReaRoll.lua', icon='roll'},
  {name='ReaSpect', file='ReaSpect.lua', icon='spect'},
}
local function normalized(path) return path:gsub('\\','/'):lower() end
local SECTION='RPS_Toolbar.Session'
local function matches(app,title)
  return title==app.name or title==app.name..' EULA' or title==app.name..'###' or
    (title and title:sub(1,#app.name+3)==app.name..'###')
end
function M.discover(r)
  local found = {}
  local f = io.open(r.GetResourcePath() .. '/reaper-kb.ini', 'r')
  if not f then return found end
  for line in f:lines() do
    local section, id, description, path = line:match('^SCR%s+%d+%s+(%d+)%s+(%S+)%s+"([^"]+)"%s+(.+)$')
    if section == '0' then
      path = path:gsub('^"',''):gsub('"%s*$',''):gsub('%s+$','')
      for _, app in ipairs(M.apps) do
        local base = normalized(path):match('([^/]+)$')
        if base == app.file:lower() then
          -- Prefer the installed copy to development/release duplicates.
          local score = normalized(path):match('^%a:/') and 1 or 2
          if not found[app.name] or score > found[app.name].score then
            found[app.name] = {id='_'..id, path=path, score=score, description=description}
          end
        end
      end
    end
  end
  f:close()
  return found
end
function M.command(r, app, discovered)
  local override = r.GetExtState('RPS_Toolbar', 'action_'..app.name)
  local id = override ~= '' and override or discovered[app.name] and discovered[app.name].id
  if not id then return 0 end
  if id:match('^%d+$') then return tonumber(id) end
  return r.NamedCommandLookup(id)
end
function M.window(r, app)
  if not r.JS_Window_Find then return nil end
  local cached=r.GetExtState(SECTION,'window_'..app.name)
  if cached~='' and r.JS_Window_HandleFromAddress and r.JS_Window_IsWindow then
    local handle=r.JS_Window_HandleFromAddress(cached)
    if handle and r.JS_Window_IsWindow(handle) and r.JS_Window_GetTitle and matches(app,r.JS_Window_GetTitle(handle)) then return handle end
  end
  local hwnd = r.JS_Window_Find(app.name, true)
  if hwnd then return hwnd end
  hwnd=r.JS_Window_Find(app.name..' EULA',true)
  if hwnd then return hwnd end
  -- A targeted search on clicks also finds inactive dock tabs and ImGui
  -- title suffixes. Validate the title before treating it as an app window.
  if r.JS_Window_ListFind and r.JS_Window_HandleFromAddress then
    local _,addresses=r.JS_Window_ListFind(app.name,false)
    for address in (addresses or ''):gmatch('[^,]+') do
      local child=r.JS_Window_HandleFromAddress(address)
      if child and (not r.JS_Window_GetTitle or matches(app,r.JS_Window_GetTitle(child))) then return child end
    end
  end
end
function M.focus(r, hwnd)
  -- Focus is explicitly requested, never forced during startup or drawing.
  if r.DockIsChildOfDock and r.DockWindowActivate then
    local dock=r.DockIsChildOfDock(hwnd)
    if dock and dock>=0 then r.DockWindowActivate(hwnd) end
  end
  if r.JS_Window_SetFocus then r.JS_Window_SetFocus(hwnd) end
end
function M.running(r,app,discovered,hwnd)
  if hwnd then return true end
  local command=M.command(r,app,discovered)
  return command~=0 and r.GetToggleCommandStateEx(0,command)==1
end
function M.activate(r, app, discovered, close, hwnd, checked, clicked_at)
  if not checked then hwnd = M.window(r, app) end
  local key='launch_'..app.name
  if hwnd then
    r.SetExtState(SECTION,key,'open',false)
    if r.JS_Window_AddressFromHandle then
      local address=r.JS_Window_AddressFromHandle(hwnd)
      r.SetExtState(SECTION,'window_'..app.name,string.format('0x%X',math.floor(address)),false)
    end
  end
  local command = M.command(r, app, discovered)
  if close then
    if not hwnd then return false, 'Cannot find '..app.name..'\'s window to close it. No action was rerun.' end
    if not r.JS_WindowMessage_Post then return false, 'Install JS_ReaScriptAPI for direct window closing.' end
    -- Called only after every toolbar/settings ImGui window has ended.
    -- The target receives the same request as its normal close button.
    if r.JS_WindowMessage_Post(hwnd,'WM_CLOSE',0,0,0,0) then return true end
    return false, 'Could not send a close request to '..app.name..'.'
  end
  if hwnd then M.focus(r, hwnd); return true end
  if command == 0 then return false, 'Load '..app.file..' into REAPER\'s main Action List, then use Rescan in Settings.' end
  if r.GetToggleCommandStateEx(0, command) == 1 then
    return false, 'The script is running, but its window could not be found. Check its dock tab.'
  end
  if r.GetExtState(SECTION,key)=='pending' then
    return false, app.name..' is still opening. Its action will not be run again. If startup failed, clear its launch guard in Settings > Applications.'
  end
  if not r.JS_Window_Find then return false,'Install JS_ReaScriptAPI so existing windows can be detected before launching.' end
  -- No short timeout: slow startup must never cause a second invocation.
  -- Nonpersistent ExtState survives a toolbar restart in the same host.
  r.SetExtState(SECTION,key,'pending',false)
  local started=r.time_precise and r.time_precise()
  if started then r.SetExtState(SECTION,'clicked_'..app.name,tostring(clicked_at or started),false) end
  r.SetExtState(SECTION,'window_time_'..app.name,'',false)
  r.SetExtState(SECTION,'window_result_'..app.name,'',false)
  r.Main_OnCommand(command, 0)
  if started then r.SetExtState(SECTION,'startup_'..app.name,tostring(r.time_precise()-started),false) end
  return true
end
function M.observe_startup(r,app)
  if r.GetExtState(SECTION,'launch_'..app.name)~='pending' then return end
  local started=tonumber(r.GetExtState(SECTION,'clicked_'..app.name))
  if not started then return end
  local elapsed=r.time_precise()-started
  if elapsed>30 then
    r.SetExtState(SECTION,'window_result_'..app.name,'No window detected within 30 seconds',false)
    return -- Keep the launch guard; a timeout is never permission to relaunch.
  end
  -- Two exact-title checks only, during startup, outside ImGui drawing.
  -- No hierarchy enumeration, focus changes or window messages.
  if not r.JS_Window_Find then return end
  local hwnd=r.JS_Window_Find(app.name,true)
  local result='App window'
  if not hwnd then hwnd=r.JS_Window_Find(app.name..' EULA',true);result='EULA window' end
  if not hwnd or r.JS_Window_IsVisible and not r.JS_Window_IsVisible(hwnd) then return end
  r.SetExtState(SECTION,'window_time_'..app.name,tostring(elapsed),false)
  r.SetExtState(SECTION,'window_result_'..app.name,result,false)
  r.SetExtState(SECTION,'launch_'..app.name,'open',false)
end
return M
