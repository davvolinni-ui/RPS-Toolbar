-- @noindex
local M={}
function M.load(apps,saved)
  local by_name,seen,out={},{},{}
  for _,app in ipairs(apps) do by_name[app.name]=app end
  for name in (saved or ''):gmatch('[^,]+') do
    if by_name[name] and not seen[name] then out[#out+1]=by_name[name];seen[name]=true end
  end
  for _,app in ipairs(apps) do if not seen[app.name] then out[#out+1]=app end end
  return out
end
function M.encode(apps)
  local names={}
  for _,app in ipairs(apps) do names[#names+1]=app.name end
  return table.concat(names,',')
end
function M.move(apps,index,direction)
  local target=index+direction
  if not apps[index] or target<1 or target>#apps then return false end
  apps[index],apps[target]=apps[target],apps[index]
  return true
end
return M
