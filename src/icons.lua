-- @noindex
local M = {}
function M.draw(I, draw, kind, x, y, size, color)
  local function line(a,b,c,d) I.DrawList_AddLine(draw,x+a*size,y+b*size,x+c*size,y+d*size,color,2) end
  local function box(a,b,c,d) I.DrawList_AddRect(draw,x+a*size,y+b*size,x+c*size,y+d*size,color,2,0,2) end
  if kind == 'browse' then
    line(.08,.3,.08,.82); line(.08,.82,.92,.82); line(.92,.82,.92,.3)
    line(.08,.3,.38,.3); line(.38,.3,.48,.43); line(.48,.43,.92,.43)
    line(.2,.6,.34,.6); line(.4,.54,.4,.72); line(.53,.5,.53,.76); line(.66,.56,.66,.7); line(.79,.61,.86,.61)
  elseif kind == 'drum' then
    for row=0,1 do for col=0,1 do box(.12+col*.43,.12+row*.43,.45+col*.43,.45+row*.43) end end
    line(.2,.3,.36,.3); line(.63,.24,.79,.24); line(.63,.31,.79,.31)
  elseif kind == 'roll' then
    box(.08,.12,.92,.88); line(.3,.12,.3,.88)
    for n=1,3 do line(.08,.12+n*.19,.3,.12+n*.19) end
    box(.38,.25,.62,.36); box(.58,.48,.83,.59); box(.36,.69,.55,.8)
  else
    for n=0,2 do local a=.22+n*.28; line(a,.12,a,.88) end
    box(.12,.28,.32,.4); box(.4,.6,.6,.72); box(.68,.4,.88,.52)
  end
end
return M
