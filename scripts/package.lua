-- Run from the repository root. Only the desktop game and license are shipped.
local function success(status)
  return status==0 or status==true
end
local probe=io.open('main.lua','r');assert(probe,'Run packaging from the PokéLua repository root.');probe:close()
assert(success(os.execute('mkdir -p dist')),'Could not create dist directory.')
os.remove('dist/PokeLua.love')
assert(success(os.execute('zip -q -r dist/PokeLua.love main.lua conf.lua src LICENSE')),'Packaging failed. Install the zip command and try again.')
print('Created dist/PokeLua.love. Open it with LÖVE 11.4 or later.')
