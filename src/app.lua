-- @noindex
local Theme = require('src.theme')
local Launcher = require('src.launcher')
local Icons = require('src.icons')
local Order = require('src.order')
local M = {}; M.__index = M
local SECTION = 'RPS_Toolbar'
local rows = {'window_bg','panel_bg','text','selected_text','accent','header_icon','folder_text','border'}
local function widget(c) return ((c&255)<<24)|((c>>8)&0xFFFFFF) end
local function rgba(c) return ((c&0xFFFFFF)<<8)|((c>>24)&255) end
function M.new(r,I)
  local self = setmetatable({r=r,I=I,ctx=I.CreateContext('RPS Toolbar'),open=true,settings_open=false}, M)
  self.theme = Theme.new(r)
  self.follow = r.GetExtState(SECTION,'follow') ~= 'false'
  self.vertical = r.GetExtState(SECTION,'vertical') == 'true'
  self.discovered = Launcher.discover(r)
  self.apps=Order.load(Launcher.apps,r.GetExtState(SECTION,'order'))
  self.hidden={}
  for _,app in ipairs(self.apps) do self.hidden[app.name]=r.GetExtState(SECTION,'hidden_'..app.name)=='true' end
  self.running = {}
  self.click_after = {}
  self.next_theme = 0
  self.next_startup_check = 0
  local _,_,section,command = r.get_action_context()
  self.section,self.command=section,command
  if command and command>0 then r.SetToggleCommandState(section,command,1);r.RefreshToolbar2(section,command) end
  self:refresh_theme()
  return self
end
function M:save()
  for _,key in ipairs({'follow','vertical'}) do self.r.SetExtState(SECTION,key,tostring(self[key]),true) end
  self.r.SetExtState(SECTION,'order',Order.encode(self.apps),true)
  for _,app in ipairs(self.apps) do self.r.SetExtState(SECTION,'hidden_'..app.name,tostring(self.hidden[app.name] or false),true) end
end
function M:visible_apps()
  local visible={}
  for _,app in ipairs(self.apps) do if not self.hidden[app.name] then visible[#visible+1]=app end end
  return visible
end
function M:set_visible(name,visible)
  self.hidden[name]=not visible
  self.resize_window=true
  self:save()
end
function M:move_button(index,direction)
  if Order.move(self.apps,index,direction) then self:save() end
end
function M:refresh_theme()
  local r=self.r
  local now=r.time_precise()
  if self.signature and now<self.next_theme then return end
  self.next_theme=now+.5
  local signature=(r.GetLastColorThemeFile() or '')..':'..r.GetThemeColor('col_main_bg2',0)..':'..r.GetThemeColor('genlist_selbg',0)..':'..r.GetThemeColor('col_toolbar_text_on',0)
  if self.follow and signature~=self.signature then Theme.import(r,self.theme,'auto') end
  self.signature=signature
end
function M:activate(app,close)
  local now=self.r.time_precise()
  if now<(self.click_after[app.name] or 0) then return end
  self.click_after[app.name]=now+.5
  self.request={app=app,close=close,clicked_at=now}
end
function M:dispatch()
  local request=self.request
  if not request then return end
  self.request=nil
  local hwnd=Launcher.window(self.r,request.app)
  local close=request.close
  if close==nil then
    close=Launcher.running(self.r,request.app,self.discovered,hwnd)
  end
  local _,message=Launcher.activate(self.r,request.app,self.discovered,close,hwnd,true,request.clicked_at)
  self.message=message
end
function M:check_startup()
  local now=self.r.time_precise()
  if now<self.next_startup_check then return end
  self.next_startup_check=now+.1
  for _,app in ipairs(self.apps) do Launcher.observe_startup(self.r,app) end
end
function M:refresh_running()
  -- Read REAPER action state only. Never enumerate or manipulate native
  -- windows from the deferred drawing loop.
  for _,app in ipairs(self.apps) do
    local command=Launcher.command(self.r,app,self.discovered)
    self.running[app.name]=command~=0 and self.r.GetToggleCommandStateEx(0,command)==1
  end
end
function M:settings()
  if not self.settings_open then return end
  local I,c,r=self.I,self.ctx,self.r
  I.SetNextWindowSize(c,570,620,I.Cond_FirstUseEver)
  local visible;visible,self.settings_open=I.Begin(c,'RPS Toolbar / Settings',self.settings_open)
  if visible then
    if I.BeginTabBar(c,'settings') then
      if I.BeginTabItem(c,'Appearance') then
        local changed; changed,self.follow=I.Checkbox(c,'Follow REAPER theme automatically',self.follow)
        if changed then self.signature=nil;self:save();self:refresh_theme() end
        for index,entry in ipairs({{'Auto Detect','auto'},{'Import Dark','dark'},{'Import Light','light'}}) do
          if index>1 then I.SameLine(c) end
          if I.Button(c,entry[1]) then self.follow=false;Theme.import(r,self.theme,entry[2]);self:save() end
        end
        for index,entry in ipairs({{'Dark','dark'},{'Light','light'},{'FL Studio','fl'}}) do
          if index>1 then I.SameLine(c) end
          if I.Button(c,entry[1]) then self.follow=false;Theme.reset(r,self.theme,entry[2]);self:save() end
        end
        I.Separator(c)
        I.TextDisabled(c,'Custom colors turn off automatic theme following.')
        for _,key in ipairs(rows) do
          I.PushID(c,key)
          I.SetNextItemWidth(c,225)
          local edited,color=I.ColorEdit4(c,Theme.LABELS[key],widget(self.theme.colors[key]),I.ColorEditFlags_NoAlpha|I.ColorEditFlags_NoInputs)
          if edited then self.follow=false;Theme.set_color(r,self.theme,key,rgba(color));self:save() end
          for n,choice in ipairs(self.theme.suggestions[key] or {}) do
            I.SameLine(c)
            if I.ColorButton(c,'alternate'..n,widget(choice.color),I.ColorEditFlags_NoAlpha,20,20) then
              self.follow=false;Theme.set_color(r,self.theme,key,choice.color);self:save()
            end
            if I.IsItemHovered(c) then I.SetTooltip(c,choice.label) end
          end
          I.PopID(c)
        end
        I.Separator(c)
        changed,self.vertical=I.Checkbox(c,'Vertical toolbar',self.vertical);if changed then self.resize_window=true;self:save() end
        I.TextWrapped(c,'Drag the toolbar edge to resize its icons automatically.')
        I.EndTabItem(c)
      end
      if I.BeginTabItem(c,'Buttons') then
        I.TextWrapped(c,'Check the apps you want to show. Move them up or down to change the order. Hidden apps keep their place in the list.')
        local move_index,move_direction
        for index,app in ipairs(self.apps) do
          I.PushID(c,'order_'..app.name)
          local changed,show=I.Checkbox(c,index..'. '..app.name,not self.hidden[app.name])
          if changed then self:set_visible(app.name,show) end
          I.SameLine(c,230)
          I.BeginDisabled(c,index==1)
          if I.Button(c,'Up') then move_index,move_direction=index,-1 end
          I.EndDisabled(c)
          I.SameLine(c)
          I.BeginDisabled(c,index==#self.apps)
          if I.Button(c,'Down') then move_index,move_direction=index,1 end
          I.EndDisabled(c)
          I.PopID(c)
        end
        if move_index then self:move_button(move_index,move_direction) end
        I.Separator(c)
        if I.Button(c,'Restore default order') then self.apps=Order.load(Launcher.apps,'');self:save() end
        I.SameLine(c)
        if I.Button(c,'Show all buttons') then self.hidden={};self.resize_window=true;self:save() end
        I.EndTabItem(c)
      end
      if I.BeginTabItem(c,'Applications') then
        I.TextWrapped(c,'Actions are detected from the main Action List. If you have several copies, paste the command ID for the copy you use.')
        if I.Button(c,'Rescan installed actions') then self.discovered=Launcher.discover(r) end
        for _,app in ipairs(self.apps) do
          I.Separator(c);I.Text(c,app.name)
          local detected=self.discovered[app.name]
          I.TextWrapped(c,detected and detected.path or 'No action found')
          local key='action_'..app.name
          local changed,value=I.InputText(c,'Command ID##'..app.name,r.GetExtState(SECTION,key))
          if changed then r.SetExtState(SECTION,key,value,true) end
          local duration=tonumber(r.GetExtState('RPS_Toolbar.Session','startup_'..app.name))
          if duration then I.TextDisabled(c,string.format('Action call only: %.2f seconds',duration)) end
          local window_time=tonumber(r.GetExtState('RPS_Toolbar.Session','window_time_'..app.name))
          local result=r.GetExtState('RPS_Toolbar.Session','window_result_'..app.name)
          if window_time then I.TextDisabled(c,string.format('%s appeared after %.2f seconds',result,window_time))
          elseif result~='' then I.TextWrapped(c,result) end
          I.TextDisabled(c,'Window appearance does not confirm the app is fully ready.')
          if r.GetExtState('RPS_Toolbar.Session','launch_'..app.name)=='pending' then
            I.TextWrapped(c,'Waiting for this app to create its window. Clear only if it failed to start.')
            if I.Button(c,'Clear failed launch guard##'..app.name) then r.SetExtState('RPS_Toolbar.Session','launch_'..app.name,'',false) end
          end
        end
        I.EndTabItem(c)
      end
      if I.BeginTabItem(c,'Help') then
        I.TextWrapped(c,'Left-click to open or focus an app, including selecting its dock tab. Right-click to close it. A small accent dot means REAPER reports the action as running. Drag the toolbar edge to resize the icons.')
        I.Separator(c)
        I.TextWrapped(c,'Close sends the existing window its normal close request. It never reruns the app action or opens a termination dialog. JS_ReaScriptAPI is required. Keep each action mapped to the copy you use.')
        I.Separator(c)
        I.TextWrapped(c,'ReaImGui 0.10 is required. Install JS_ReaScriptAPI through ReaPack for focus of floating or docked windows. Use REAPER docking controls to dock this toolbar.')
        I.EndTabItem(c)
      end
      I.EndTabBar(c)
    end
    I.End(c)
  end
end
function M:frame()
  local I,c,r=self.I,self.ctx,self.r
  self:check_startup()
  self:refresh_theme()
  self:refresh_running()
  local colors=self.theme.colors
  local T={};Theme.apply(self.theme,T)
  for _,entry in ipairs({{I.Col_WindowBg,T.window},{I.Col_Text,T.text},{I.Col_Button,T.button},{I.Col_ButtonHovered,T.hover},{I.Col_ButtonActive,T.active},{I.Col_Border,T.border}}) do I.PushStyleColor(c,entry[1],entry[2]) end
  I.PushStyleVar(c,I.StyleVar_WindowPadding,4,4)
  I.PushStyleVar(c,I.StyleVar_ItemSpacing,6,6)
  I.PushStyleVar(c,I.StyleVar_FrameRounding,7)
  I.PushStyleVar(c,I.StyleVar_FrameBorderSize,1)
  local initial_size=self.last_icon_size or 56
  local visible_apps=self:visible_apps()
  local count=#visible_apps
  local gaps=count*6
  local long=initial_size*count+18+gaps+8
  local short=initial_size+8
  local title=I.GetFrameHeight(c)
  I.SetNextWindowSize(c,self.vertical and short or long,(self.vertical and long or short)+title,self.resize_window and I.Cond_Always or I.Cond_FirstUseEver)
  self.resize_window=false
  local minimum_long=math.max(32,count*24+18+gaps+8)
  I.SetNextWindowSizeConstraints(c,self.vertical and 32 or minimum_long,self.vertical and minimum_long+title or 32+title,10000,10000)
  local visible;visible,self.open=I.Begin(c,'RPS Toolbar',self.open,I.WindowFlags_NoCollapse|I.WindowFlags_NoScrollbar|I.WindowFlags_NoScrollWithMouse)
  if visible then
    local width,height=I.GetContentRegionAvail(c)
    local menu=18
    local bw=self.vertical and width or (count>0 and math.max(24,(width-menu-gaps)/count) or width)
    local bh=self.vertical and (count>0 and math.max(24,(height-menu-gaps)/count) or height) or height
    local size=math.min(bw,bh)
    self.last_icon_size=size
    for index,app in ipairs(visible_apps) do
      if index>1 and not self.vertical then I.SameLine(c) end
      I.PushID(c,app.name)
      local running=self.running[app.name]
      local x,y=I.GetCursorScreenPos(c)
      if I.Button(c,'##launch',bw,bh) then self:activate(app,false) end
      if I.IsItemClicked(c,I.MouseButton_Right) then self:activate(app,true) end
      local hovered=I.IsItemHovered(c)
      local pressed=I.IsItemActive(c) and I.IsMouseDown(c,I.MouseButton_Left)
      local opening=r.GetExtState('RPS_Toolbar.Session','launch_'..app.name)=='pending'
      if hovered then I.SetTooltip(c,app.name..(opening and '\nOpening...' or '')..'\nLeft-click: open / focus (select dock tab)\nRight-click: close') end
      local draw=I.GetWindowDrawList(c)
      local glyph_size=size*.94
      Icons.draw(I,draw,app.icon,x+(bw-glyph_size)/2,y+(bh-glyph_size)/2,glyph_size,pressed and T.icon_active or hovered and T.icon_hover or T.icon)
      if opening then
        local pulse=2+math.sin(r.time_precise()*5)*.8
        I.DrawList_AddCircleFilled(draw,x+bw-8,y+8,pulse,T.marker)
      end
      if running then I.DrawList_AddCircleFilled(draw,x+bw-8,y+8,3,T.marker) end
      I.PopID(c)
    end
    if count>0 and not self.vertical then I.SameLine(c) end
    local mx,my=I.GetCursorScreenPos(c)
    local mw,mh=self.vertical and bw or (count>0 and menu or width),self.vertical and (count>0 and menu or height) or bh
    if I.Button(c,'##settings',mw,mh) then self.settings_open=not self.settings_open end
    local pressed=I.IsItemActive(c) and I.IsMouseDown(c,I.MouseButton_Left)
    local dot_color=pressed and T.icon_active or I.IsItemHovered(c) and T.icon_hover or T.icon
    local draw=I.GetWindowDrawList(c)
    for n=-1,1 do I.DrawList_AddCircleFilled(draw,mx+mw/2,my+mh/2+n*6,1.7,dot_color) end
    if I.IsItemHovered(c) then I.SetTooltip(c,'Settings') end
    if not r.JS_Window_Find then I.TextWrapped(c,'Install JS_ReaScriptAPI to enable focus and window detection.') end
    if self.message then I.TextWrapped(c,self.message);if I.SmallButton(c,'Dismiss') then self.message=nil end end
    I.End(c)
  end
  I.PopStyleVar(c,4)
  I.PopStyleColor(c,6)
  self:settings()
  -- Finish all ImGui windows before invoking an action that can open a
  -- modal dialog or start another ImGui script.
  self:dispatch()
  if self.open then r.defer(function() self:frame() end) end
end
function M:shutdown()
  if self.command and self.command>0 then self.r.SetToggleCommandState(self.section,self.command,0);self.r.RefreshToolbar2(self.section,self.command) end
end
return M
