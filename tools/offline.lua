package.path=ROOT..'/?.lua;'..package.path
for _,file in ipairs({'RPS Toolbar.lua','src/app.lua','src/theme.lua','src/launcher.lua','src/icons.lua','src/order.lua'}) do assert(loadfile(ROOT..'/'..file)) end
print('PASS: Lua syntax')
local L=require('src.launcher')
local found=L.discover({GetResourcePath=function()return RESOURCE end})
for _,app in ipairs(L.apps) do assert(found[app.name],app.name) end
print('PASS: all four installed actions detected')
local now,scans,invoked,closed,focused,theme_reads=0,0,0,0,0,0
local live=true
local ext={}
local r={
  GetResourcePath=function()return RESOURCE end,
  GetExtState=function(s,k)return ext[s..k] or ''end,
  SetExtState=function(s,k,v)ext[s..k]=v end,
  NamedCommandLookup=function()return 123 end,
  GetToggleCommandStateEx=function()return 0 end,
  Main_OnCommand=function()invoked=invoked+1 end,
  JS_Window_Find=function(name)return live and name=='ReaBrowse' and 1 or nil end,
  JS_Window_ListAllTop=function()error('Native enumeration is forbidden')end,
  JS_Window_ListAllChild=function()error('Native enumeration is forbidden')end,
  JS_Window_HandleFromAddress=function()return 1 end,
  JS_Window_GetTitle=function()return live and 'ReaBrowse' or 'Other'end,
  GetMainHwnd=function()return 99 end,
  JS_Window_Show=function()error('Native show is forbidden')end,
  JS_Window_SetFocus=function()focused=focused+1 end,
  JS_WindowMessage_Post=function(hwnd,msg)assert(hwnd==1 and msg=='WM_CLOSE');closed=closed+1;return true end,
  time_precise=function()return now end,
  get_action_context=function()return false,'',0,0 end,
  GetLastColorThemeFile=function()return 'test'end,
  GetThemeColor=function()theme_reads=theme_reads+1;return 0x303030 end,
  ColorFromNative=function()return 48,48,48 end,
  defer=function()end,
}
local width,height=266,56
local button_size,dots={},{}
local click=false
local right_click=false
local modifiers=0
local I={
  MouseButton_Right=1,
  IsItemClicked=function(_,button)assert(button==1);local hit=right_click;right_click=false;return hit end,
  Mod_Shift=1,
  GetKeyMods=function()return modifiers end,
  CreateContext=function()return 1 end,
  Begin=function(_,_,open)return true,open end,
  GetContentRegionAvail=function()return width,height end,
  GetFrameHeight=function()return 20 end,
  GetCursorScreenPos=function()return 0,0 end,
  Button=function(_,id,w,h)
    if id=='##launch' then button_size[#button_size+1]={w,h};local hit=click;click=false;return hit end
    return false
  end,
  IsItemHovered=function()return false end,
  BeginPopupContextItem=function()error('App context menu must not open')end,
  GetWindowDrawList=function()return 1 end,
  DrawList_AddCircleFilled=function(_,x,y,radius)if radius==1.7 then dots[#dots+1]={x,y}end end,
}
local constant=0
setmetatable(I,{__index=function(t,k)
  local value
  if k:match('^Col_') or k:match('^StyleVar_') or k:match('^Cond_') or k:match('^WindowFlags_') then constant=constant+1;value=constant
  else value=function()end end
  rawset(t,k,value);return value
end})
local App=require('src.app')
local app=App.new(r,I)
right_click=true;app:frame()
assert(closed==1 and invoked==0,'Closing must not rerun or launch an action')
assert(button_size[1][1]==56,'Default size changed')
assert(#dots==3 and dots[1][1]==dots[2][1] and dots[1][2]<dots[2][2],'Settings dots must be vertical')
now=.01;app:frame()
local initial_scans,initial_reads=scans,theme_reads
now=.02;app:frame()
assert(scans==initial_scans and theme_reads==initial_reads,'Idle frame repeated scans/theme reads')
width,height=490,112;now=.03;app:frame()
assert(button_size[#button_size][1]==112,'Icons did not grow with window')
app.vertical=true;width,height=112,490;now=.04;app:frame()
assert(button_size[#button_size][1]==112,'Vertical sizing failed')
live=false;now=.6;click=true;app:frame()
assert(invoked==1,'Click should launch closed app')
now=.61;click=true;app:frame()
assert(invoked==1,'Repeated click relaunched app')
live=true;now=.65;app:frame()
assert(focused==0,'Deferred loop must never force focus')
print('PASS: direct close without action rerun, launch, duplicate-click guard; no forced focus')
print('PASS: horizontal/vertical responsive sizing and vertical settings dots')
print('PASS: idle frames avoid repeated scans and theme reads')


-- A missing/failed close must never fall back to the app action.
live=false
assert(not L.activate(r,L.apps[1],found,true))
assert(invoked==1)
r.JS_Window_Find=function()return nil end
r.JS_Window_ListFind=function(title,exact)assert(title=='ReaBrowse' and not exact);return 1,'1'end
r.JS_Window_HandleFromAddress=function()return 1 end
r.JS_Window_GetTitle=function()return 'ReaBrowse'end
assert(L.activate(r,L.apps[1],found,true))
assert(closed==2 and invoked==1)
r.JS_WindowMessage_Post=function()return false end
assert(not L.activate(r,L.apps[1],found,true))
assert(invoked==1)
print('PASS: docked exact-title close; missing/failed close never launches or reruns')

-- Explicit focus must reveal the dock tab before setting keyboard focus.
local order={}
r.DockIsChildOfDock=function(hwnd)assert(hwnd==1);return 0 end
r.DockWindowActivate=function(hwnd)assert(hwnd==1);order[#order+1]='dock'end
r.JS_Window_SetFocus=function(hwnd)assert(hwnd==1);order[#order+1]='focus'end
now=1.3;modifiers=1;click=true;app:frame()
assert(table.concat(order,',')=='dock,focus','Left-click must activate dock zero before focusing')
assert(invoked==1 and closed==2,'Focus must neither relaunch nor close')
order={};r.DockIsChildOfDock=function()return -1 end
L.focus(r,1)
assert(table.concat(order,',')=='focus','Floating focus must not activate a dock')
print('PASS: left-click selects dock tab then focuses; floating focus unchanged')

-- Long startup and a fresh toolbar must never rerun a pending action.
r.JS_Window_Find=function()return nil end
r.JS_Window_ListFind=function()return 0,''end
r.SetExtState('RPS_Toolbar.Session','launch_ReaBrowse','',false)
assert(L.activate(r,L.apps[1],found,false))
local launches=invoked
now=60
assert(not L.activate(r,L.apps[1],found,false))
local restarted=App.new(r,I)
assert(not L.activate(r,L.apps[1],restarted.discovered,false))
assert(invoked==launches,'Slow/restarted pending launch reran the action')
-- A startup EULA is an existing app too, not a reason to launch again.
r.JS_Window_Find=function(title)return title=='ReaBrowse EULA' and 1 or nil end
assert(L.activate(r,L.apps[1],found,false))
assert(invoked==launches)
-- Reject matching diagnostic/helper windows before deciding to focus.
r.JS_Window_Find=function()return nil end
r.JS_Window_ListFind=function()return 1,'1'end
r.JS_Window_GetTitle=function()return 'ReaBrowse Diagnostic'end
assert(L.window(r,L.apps[1])==nil)
r.JS_Window_GetTitle=function()return 'ReaBrowse###ctx'end
assert(L.window(r,L.apps[1])==1)
print('PASS: long startup/restart guard, EULA detection and validated ImGui suffixes')

-- Deferred presentation time includes the time after Main_OnCommand returns.
r.SetExtState('RPS_Toolbar.Session','launch_ReaBrowse','pending',false)
r.SetExtState('RPS_Toolbar.Session','clicked_ReaBrowse','100',false)
now=100.05
r.JS_Window_Find=function()return nil end
L.observe_startup(r,L.apps[1])
assert(r.GetExtState('RPS_Toolbar.Session','launch_ReaBrowse')=='pending')
now=101.4
r.JS_Window_Find=function(title)return title=='ReaBrowse' and 1 or nil end
r.JS_Window_IsVisible=function()return false end
L.observe_startup(r,L.apps[1])
assert(r.GetExtState('RPS_Toolbar.Session','launch_ReaBrowse')=='pending')
r.JS_Window_IsVisible=function()return true end
L.observe_startup(r,L.apps[1])
assert(math.abs(tonumber(r.GetExtState('RPS_Toolbar.Session','window_time_ReaBrowse'))-1.4)<.001)
r.JS_Window_Find=function()error('Polling must stop after presentation')end
L.observe_startup(r,L.apps[1])
r.SetExtState('RPS_Toolbar.Session','launch_ReaBrowse','pending',false)
now=140
L.observe_startup(r,L.apps[1])
assert(r.GetExtState('RPS_Toolbar.Session','launch_ReaBrowse')=='pending','Timeout cleared launch guard')
assert(r.GetExtState('RPS_Toolbar.Session','window_result_ReaBrowse'):match('30 seconds'))
print('PASS: click-to-visible-window timing, hidden-window rejection, bounded startup-only checks')

local Order=require('src.order')
local original=Order.encode(L.apps)
local ordered=App.new(r,I)
ordered:move_button(4,-1)
ordered:move_button(3,-1)
ordered:move_button(2,-1)
assert(ordered.apps[1].name=='ReaSpect')
local restored=App.new(r,I)
assert(Order.encode(restored.apps)==Order.encode(ordered.apps),'Order did not survive restart')
assert(Order.encode(L.apps)==original,'Ordering mutated shared application definitions')
assert(not Order.move(restored.apps,1,-1) and not Order.move(restored.apps,4,1))
r.SetExtState('RPS_Toolbar','order','ReaRoll,ReaRoll,Unknown,ReaSpect',true)
local repaired=App.new(r,I)
assert(Order.encode(repaired.apps)=='ReaRoll,ReaSpect,ReaBrowse,ReaDrumXT','Invalid saved order lost/duplicated apps')
print('PASS: reordered buttons persist; invalid saved orders retain every app exactly once')

local Theme=require('src.theme')
for _,background in ipairs({0xFFFFFFFF,0xE3E5E8FF,0xBBBBBBFF,0x333333FF,0x101215FF}) do
  for _,foreground in ipairs({background,0xFFFFFFFF,0x000000FF,0x2F78CFFF,0xFFFF00FF}) do
    local state=Theme.new(r)
    state.colors.window_bg=background;state.colors.panel_bg=background
    state.colors.header_icon=foreground;state.colors.selected_text=foreground
    state.colors.text=foreground;state.colors.accent=foreground
    local C={};Theme.apply(state,C)
    assert(Theme.contrast_ratio(C.icon,C.button)>=3)
    assert(Theme.contrast_ratio(C.icon_hover,C.hover)>=3)
    assert(Theme.contrast_ratio(C.icon_active,C.active)>=3)
    assert(Theme.contrast_ratio(C.text,C.window)>=4.5)
    assert(Theme.contrast_ratio(C.marker,C.button)>=3)
    assert(state.colors.header_icon==foreground,'Display safeguards changed saved custom colors')
  end
end
print('PASS: light/dark and low-contrast custom palettes remain readable in all button states')

local visibility=App.new(r,I)
visibility:set_visible('ReaBrowse',false)
visibility:set_visible('ReaDrumXT',false)
local visible=visibility:visible_apps()
assert(#visible==2 and visible[1].name=='ReaRoll' and visible[2].name=='ReaSpect')
local restored_visibility=App.new(r,I)
assert(#restored_visibility:visible_apps()==2,'Hidden buttons did not persist')
assert(#restored_visibility.apps==4,'Hiding removed apps from the saved order')
for _,app in ipairs(restored_visibility.apps) do restored_visibility:set_visible(app.name,false) end
local before=#button_size
restored_visibility:frame()
assert(#button_size==before,'All-hidden toolbar still drew app buttons')
restored_visibility:set_visible('ReaSpect',true)
restored_visibility:frame()
assert(#button_size==before+1,'Restoring visibility did not restore a button')
print('PASS: visibility persists, retains order, and supports zero/one visible apps')
