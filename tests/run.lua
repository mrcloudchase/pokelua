-- Run from the project root with Lua 5.1, LuaJIT, or newer Lua.
package.path='./?.lua;./?/init.lua;'..package.path
local total=0
for _,name in ipairs({'combat','world','save','game','gameplay_qa','campaign'}) do
  local count=0
  local function check(ok,message) count=count+1;assert(ok,message) end
  local ok,result=pcall(function() return require('tests.'..name)(check) end)
  if not ok then io.stderr:write('FAIL '..name..': '..tostring(result)..'\n');os.exit(1) end
  if count==0 then count=type(result)=='number' and result or 1 end
  total=total+count;print('PASS '..name..' ('..count..' checks)')
end
print('All '..total..' checks passed.')
